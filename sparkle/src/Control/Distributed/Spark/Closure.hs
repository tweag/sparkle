{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StaticPointers #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}

module Control.Distributed.Spark.Closure where

import Control.Distributed.Closure
import Control.Distributed.Closure.TH
import Control.Applicative ((<|>))
import Control.Monad ((<=<))
import Data.Binary (encode, decode)
import Data.Maybe (fromJust)
import Data.ByteString (ByteString)
import qualified Data.ByteString.Lazy as LBS
import qualified Data.ByteString as BS
import qualified Data.ByteString.Unsafe as BS
import Data.Typeable (Typeable, (:~:)(..), eqT, typeOf)
import Foreign.C.String
import Foreign.Java

data Type a
  = Fun [Type a] (Type a) -- ^ Pure function
  | Act [Type a] (Type a) -- ^ IO action
  | Proc [Type a]         -- ^ Procedure (i.e void returning action)
  | Base a                -- ^ Any first-order type.

type family Uncurry a where
  Uncurry (Closure (a -> b -> c -> d -> IO ())) = 'Proc '[Uncurry a, Uncurry b, Uncurry c, Uncurry d]
  Uncurry (Closure (a -> b -> c -> IO ())) = 'Proc '[Uncurry a, Uncurry b, Uncurry c]
  Uncurry (Closure (a -> b -> IO ())) = 'Proc '[Uncurry a, Uncurry b]
  Uncurry (Closure (a -> IO ())) = 'Proc '[Uncurry a]
  Uncurry (IO ()) = 'Proc '[]
  Uncurry (Closure (a -> b -> c -> d -> IO e)) = 'Act '[Uncurry a, Uncurry b, Uncurry c, Uncurry d] (Uncurry e)
  Uncurry (Closure (a -> b -> c -> IO d)) = 'Act '[Uncurry a, Uncurry b, Uncurry c] (Uncurry d)
  Uncurry (Closure (a -> b -> IO c)) = 'Act '[Uncurry a, Uncurry b] (Uncurry c)
  Uncurry (Closure (a -> IO b)) = 'Act '[Uncurry a] (Uncurry b)
  Uncurry (Closure (IO a)) = 'Act '[] (Uncurry a)
  Uncurry (Closure (a -> b -> c -> d -> e)) = 'Fun '[Uncurry a, Uncurry b, Uncurry c, Uncurry d] (Uncurry e)
  Uncurry (Closure (a -> b -> c -> d)) = 'Fun '[Uncurry a, Uncurry b, Uncurry c] (Uncurry d)
  Uncurry (Closure (a -> b -> c)) = 'Fun '[Uncurry a, Uncurry b] (Uncurry c)
  Uncurry (Closure (a -> b)) = 'Fun '[Uncurry a] (Uncurry b)
  Uncurry a = 'Base a

class (Uncurry a ~ b, Typeable a, Typeable b) => Reify a b where
  reify :: JNIEnv -> JObject -> IO a

class (Uncurry a ~ b, Typeable a, Typeable b) => Reflect a b where
  reflect :: JNIEnv -> a -> IO JObject

-- XXX GHC wouldn't be able to use the more natural
--
-- (Uncurry a ~ a', Uncurry b ~ b')
--
-- constraint, because it doesn't know that Uncurry is injective.
instance (Uncurry (Closure (a -> b)) ~ 'Fun '[a'] b', Reflect a a', Reify b b') =>
         Reify (Closure (a -> b)) ('Fun '[a'] b') where
  reify env jobj = do
      klass <- findClass env "sparkle/function/Function"
      field <- getFieldID env klass "clos" "[B"
      jpayload <- getObjectField env jobj field
      payload <- reify env jpayload
      return (bs2clos payload)

instance (Uncurry (Closure (a -> b)) ~ 'Fun '[a'] b', Reify a a', Reflect b b') =>
         Reflect (Closure (a -> b)) ('Fun '[a'] b') where
  reflect env f = do
      klass <- findClass env "sparkle/function/Function"
      jpayload <- reflect env (clos2bs (fromJust wrap))
      newObject env klass "([B)V" [JObject jpayload]
    where
      -- TODO this type dispatch is a gross temporary hack! For until we get the
      -- instance commented out below to work.
      wrap :: Maybe (Closure (JNIEnv -> JObject -> IO JObject))
      wrap =
        fmap (\Refl -> $(cstatic 'closFun1) `cap` $(cstatic 'dict1) `cap` f) (eqT :: Maybe ((a, b) :~: (Int, Int))) <|>
        fmap (\Refl -> $(cstatic 'closFun1) `cap` $(cstatic 'dict2) `cap` f) (eqT :: Maybe ((a, b) :~: (Bool, Bool))) <|>
        fmap (\Refl -> $(cstatic 'closFun1) `cap` $(cstatic 'dict3) `cap` f) (eqT :: Maybe ((a, b) :~: (ByteString, ByteString))) <|>
        fmap (\Refl -> $(cstatic 'closFun1) `cap` $(cstatic 'dict4) `cap` f) (eqT :: Maybe ((a, b) :~: (String, String))) <|>
        fmap (\Refl -> $(cstatic 'closFun1) `cap` $(cstatic 'dict5) `cap` f) (eqT :: Maybe ((a, b) :~: (String, Bool))) <|>
        error ("No static function from " ++
               show (typeOf (undefined :: a)) ++
               " to " ++
               show (typeOf (undefined :: b)))

-- Floating to top-level due to a limitation of -XStaticPointers.
--
-- TODO file bug report.

dict1 :: Dict (Reify Int ('Base Int), Reflect Int ('Base Int))
dict2 :: Dict (Reify Bool ('Base Bool), Reflect Bool ('Base Bool))
dict3 :: Dict (Reify ByteString ('Base ByteString), Reflect ByteString ('Base ByteString))
dict4 :: Dict (Reify String ('Base String), Reflect String ('Base String))
dict5 :: Dict (Reify String ('Base String), Reflect Bool ('Base Bool))
dict1 = Dict
dict2 = Dict
dict3 = Dict
dict4 = Dict
dict5 = Dict

closFun1 :: Dict (Reify a a', Reflect b b') -> (a -> b) -> JNIEnv -> JObject -> IO JObject
closFun1 Dict f env =
    reflect env <=< return . f <=< reify env

-- instance (Uncurry (Closure (a -> b)) ~ Fun '[a'] b', Reflect a a', Reify b b') =>
--          Reify (Closure (a -> b)) (Fun '[a'] b') where
--   reify env jobj = do
--       klass <- findClass env "sparkle/function/Function"
--       field <- getFieldID env klass "clos" "[B"
--       jpayload <- getObjectField env jobj field
--       payload <- reify env jpayload
--       return (bs2clos payload)
--   reifyDict =
--       cmapDict `cap` reifyDictFun1 `cap` (cpairDict `cap` reflectDict `cap` reifyDict)
--
-- reifyDictFun1 :: (Reflect a a', Reify b b') :- Reify (Closure (a -> b)) (Fun '[a'] b')
-- reifyDictFun1 = Sub

instance Reify ByteString ('Base ByteString) where
  reify env jobj = do
      n <- getArrayLength env jobj
      bytes <- getByteArrayElements env jobj
      -- TODO could use unsafePackCStringLen instead and avoid a copy if we knew
      -- that been handed an (immutable) copy via JNI isCopy ref.
      bs <- BS.packCStringLen (bytes, fromIntegral n)
      releaseByteArrayElements env jobj bytes
      return bs

instance Reflect ByteString ('Base ByteString) where
  reflect env bs = BS.unsafeUseAsCStringLen bs $ \(content, n) -> do
      arr <- newByteArray env (fromIntegral n)
      setByteArrayRegion env arr 0 (fromIntegral n) content
      return arr

instance Reify Bool ('Base Bool) where
  reify env jobj = do
      klass <- findClass env "java/lang/Boolean"
      method <- getMethodID env klass "booleanValue" "()Z"
      toEnum . fromIntegral <$> callBooleanMethod env jobj method []

instance Reflect Bool ('Base Bool) where
  reflect env x = do
      klass <- findClass env "java/lang/Boolean"
      newObject env klass "(Z)V" [JBoolean (fromIntegral (fromEnum x))]

instance Reify Int ('Base Int) where
  reify env jobj = do
      klass <- findClass env "java/lang/Integer"
      method <- getMethodID env klass "longValue" "()L"
      fromIntegral <$> callLongMethod env jobj method []

instance Reflect Int ('Base Int) where
  reflect env x = do
      klass <- findClass env "java/lang/Integer"
      newObject env klass "(L)V" [JInt (fromIntegral x)]

instance Reify Double ('Base Double) where
  reify env jobj = do
      klass <- findClass env "java/lang/Double"
      method <- getMethodID env klass "doubleValue" "()D"
      callDoubleMethod env jobj method []

instance Reflect Double ('Base Double) where
  reflect env x = do
      klass <- findClass env "java/lang/Double"
      newObject env klass "(D)V" [JDouble x]

instance Reify Text ('Base Text) where
  reify env jobj = do
      -- TODO go via getString instead of getStringUTF, since text also uses
      -- UTF-16 internally.
      sz <- getStringUTFLength env jobj
      cs <- getStringUTFChars env jobj
      txt <- Text.decodeUtf8 <$> BS.unsafePackCStringLen (cs, fromIntegral sz)
      releaseStringUTFChars env jobj cs
      return txt

instance Reflect Text ('Base Text) where
  reflect env x =
      Text.useAsPtr x $ \ptr len ->
        newString env ptr (fromIntegral len)


instance Reflect String ('Base String) where
  reflect env x = newStringUTF env x

clos2bs :: Typeable a => Closure a -> ByteString
clos2bs = LBS.toStrict . encode

bs2clos :: Typeable a => ByteString -> Closure a
bs2clos = decode . LBS.fromStrict
