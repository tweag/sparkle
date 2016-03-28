-- | Foreign exports and instances to deal with 'Closure' in Spark.

{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StaticPointers #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-} -- For Closure instances

{-# OPTIONS_GHC -fno-warn-orphans #-}

module Control.Distributed.Spark.Closure (apply) where

import Control.Distributed.Closure
import Control.Distributed.Closure.TH
import Control.Applicative ((<|>))
import Data.Binary (encode, decode)
import Data.Maybe (fromJust)
import qualified Data.ByteString.Lazy as LBS
import Data.ByteString (ByteString)
import Data.Text (Text)
import Data.Typeable (Typeable, (:~:)(..), eqT, typeOf)
import Foreign.JNI
import Language.Java

-- | The main entry point for Java code to apply a Haskell 'Closure'. This
-- function is foreign exported.
apply
  :: JByteArray
  -> JObjectArray
  -> IO JObject
apply bytes args = do
    bs <- reify bytes
    let f = unclosure (bs2clos bs) :: JObjectArray -> IO JObject
    f args

foreign export ccall "sparkle_apply" apply
  :: JByteArray
  -> JObjectArray
  -> IO JObject

type instance Interp ('Fun '[a] b) =
  'Class "io.tweag.sparkle.function.HaskellFunction" <> [Interp a, Interp b]

-- Needs UndecidableInstances
instance ( ty1 ~ Interp (Uncurry a)
         , ty2 ~ Interp (Uncurry b)
         , ty ~ Interp (Uncurry (Closure (a -> b)))
         , ty ~ ('Class "io.tweag.sparkle.function.HaskellFunction" <> [ty1, ty2])
         , Reflect a ty1
         , Reify b ty2
         ) =>
         Reify (Closure (a -> b)) ty where
  reify jobj = do
      klass <- findClass "io/tweag/sparkle/function/HaskellFunction"
      field <- getFieldID klass "clos" "[B"
      jpayload <- getObjectField jobj field
      payload <- reify (unsafeCast jpayload)
      return (bs2clos payload)

-- Needs UndecidableInstances
instance ( ty1 ~ Interp (Uncurry a)
         , ty2 ~ Interp (Uncurry b)
         , ty ~ Interp (Uncurry (Closure (a -> b)))
         , ty ~ ('Class "io.tweag.sparkle.function.HaskellFunction" <> [ty1, ty2])
         , Reify a ty1
         , Reflect b ty2
         ) =>
         Reflect (Closure (a -> b)) ty where
  reflect f = do
      klass <- findClass "io/tweag/sparkle/function/HaskellFunction"
      jpayload <- reflect (clos2bs (fromJust wrap))
      fmap unsafeCast $ newObject klass "([B)V" [JObject jpayload]
    where
      -- TODO this type dispatch is a gross temporary hack! For until we get the
      -- instance commented out below to work.
      wrap :: Maybe (Closure (JObjectArray -> IO JObject))
      wrap =
        fmap (\Refl -> $(cstatic 'closFun1) `cap` $(cstatic 'dict1) `cap` f) (eqT :: Maybe ((a, b) :~: (Int, Int))) <|>
        fmap (\Refl -> $(cstatic 'closFun1) `cap` $(cstatic 'dict2) `cap` f) (eqT :: Maybe ((a, b) :~: (Bool, Bool))) <|>
        fmap (\Refl -> $(cstatic 'closFun1) `cap` $(cstatic 'dict3) `cap` f) (eqT :: Maybe ((a, b) :~: (ByteString, ByteString))) <|>
        fmap (\Refl -> $(cstatic 'closFun1) `cap` $(cstatic 'dict4) `cap` f) (eqT :: Maybe ((a, b) :~: (Text, Text))) <|>
        fmap (\Refl -> $(cstatic 'closFun1) `cap` $(cstatic 'dict5) `cap` f) (eqT :: Maybe ((a, b) :~: (Text, Bool))) <|>
        error ("Due to TEMPORARY HACK - No static function from " ++
               show (typeOf (undefined :: a)) ++
               " to " ++
               show (typeOf (undefined :: b)))

-- XXX Floating to top-level due to a limitation of -XStaticPointers.
--
-- See https://ghc.haskell.org/trac/ghc/ticket/11656.

dict1 :: Dict (Reify Int ('Class "java.lang.Integer"), Reflect Int ('Class "java.lang.Integer"))
dict2 :: Dict (Reify Bool ('Class  "java.lang.Boolean"), Reflect Bool ('Class  "java.lang.Boolean"))
dict3 :: Dict (Reify ByteString ('Array ('Prim "byte")), Reflect ByteString ('Array ('Prim "byte")))
dict4 :: Dict (Reify Text ('Class  "java.lang.String"), Reflect Text ('Class  "java.lang.String"))
dict5 :: Dict (Reify Text ('Class  "java.lang.String"), Reflect Bool ('Class  "java.lang.Boolean"))
dict1 = Dict
dict2 = Dict
dict3 = Dict
dict4 = Dict
dict5 = Dict

closFun1
  :: forall a b ty1 ty2.
     Dict (Reify a ty1, Reflect b ty2)
  -> (a -> b)
  -> JObjectArray
  -> IO JObject
closFun1 Dict f args =
    fmap upcast . refl =<< return . f =<< reif . unsafeCast =<< getObjectArrayElement args 0
  where
    reif = reify :: J ty1 -> IO a
    refl = reflect :: b -> IO (J ty2)

-- instance (Uncurry (Closure (a -> b)) ~ Fun '[a'] b', Reflect a a', Reify b b') =>
--          Reify (Closure (a -> b)) (Fun '[a'] b') where
--   reify jobj = do
--       klass <- findClass "io/tweag/sparkle/function/Function"
--       field <- getFieldID klass "clos" "[B"
--       jpayload <- getObjectField jobj field
--       payload <- reify jpayload
--       return (bs2clos payload)
--   reifyDict =
--       cmapDict `cap` reifyDictFun1 `cap` (cpairDict `cap` reflectDict `cap` reifyDict)
--
-- reifyDictFun1 :: (Reflect a a', Reify b b') :- Reify (Closure (a -> b)) (Fun '[a'] b')
-- reifyDictFun1 = Sub

clos2bs :: Typeable a => Closure a -> ByteString
clos2bs = LBS.toStrict . encode

bs2clos :: Typeable a => ByteString -> Closure a
bs2clos = decode . LBS.fromStrict
