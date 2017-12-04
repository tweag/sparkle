-- | Foreign exports and instances to deal with 'Closure' in Spark.

{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StaticPointers #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}

module Control.Distributed.Spark.Closure
  ( Function(..)
  , Function2(..)
  , JFun1
  , JFun2
  , apply
  ) where

import Control.Exception (fromException, catch)
import Control.Distributed.Closure
import Control.Distributed.Closure.TH
import Data.Binary (encode, decode)
import qualified Data.Coerce as Coerce
import qualified Data.ByteString.Lazy as LBS
import Data.ByteString (ByteString)
import Data.Text as Text
import Data.Typeable (Typeable)
import Foreign.ForeignPtr (newForeignPtr_)
import Foreign.ForeignPtr.Unsafe (unsafeForeignPtrToPtr)
import Foreign.JNI
import Foreign.Ptr (Ptr)
import Language.Java

-- | The main entry point for Java code to apply a Haskell 'Closure'. This
-- function is foreign exported.
--
-- The function in the closure pointed by the first argument must yield
-- a local reference to a Java object, or the reference might be released
-- prematurely.
apply
  :: Ptr JByteArray
  -> Ptr JObjectArray
  -> IO (Ptr JObject)
apply bytes args = do
    bs <- (J <$> newForeignPtr_ bytes) >>= reify
    let f = unclosure (bs2clos bs) :: JObjectArray -> IO JObject
    unsafeForeignPtrToPtr <$> Coerce.coerce <$>
      (do fptr <- newForeignPtr_ args
          f (J fptr) `catch` \e -> case fromException e of
            -- forward JVMExceptions
            Just (JVMException j) -> Foreign.JNI.throw j >> return jnull
            -- send other exceptions in string form
            Nothing -> do
              jt <- reflect (Text.pack $ show e)
              je <- new [coerce jt]
              Foreign.JNI.throw (je :: J ('Class "java/lang/RuntimeException"))
              return jnull
      )

foreign export ccall "sparkle_apply" apply
  :: Ptr JByteArray
  -> Ptr JObjectArray
  -> IO (Ptr JObject)

type JFun1 a b = 'Iface "org.apache.spark.api.java.function.Function" <> [a, b]

newtype Function a b = Function (Closure (a -> b))
type instance Interp (Function a b) = JFun1 (Interp a) (Interp b)

pairDict :: Dict c1 -> Dict c2 -> Dict (c1, c2)
pairDict Dict Dict = Dict

closFun1
  :: forall a b.
     Dict (Reify a, Reflect b)
  -> (a -> b)
  -> JObjectArray
  -> IO JObject
closFun1 Dict f args =
    fmap upcast . refl =<< return . f =<< reif . unsafeCast =<< getObjectArrayElement args 0
  where
    reif = reify :: J (Interp a) -> IO a
    refl = reflect :: b -> IO (J (Interp b))

type JFun2 a b c = 'Iface "org.apache.spark.api.java.function.Function2" <> [a, b, c]

newtype Function2 a b c = Function2 (Closure (a -> b -> c))
type instance Interp (Function2 a b c) = JFun2 (Interp a) (Interp b) (Interp c)

tripleDict :: Dict c1 -> Dict c2 -> Dict c3 -> Dict (c1, c2, c3)
tripleDict Dict Dict Dict = Dict

closFun2
  :: forall a b c.
     Dict (Reify a, Reify b, Reflect c)
  -> (a -> b -> c)
  -> JObjectArray
  -> IO JObject
closFun2 Dict f args = do
    a <- unsafeCast <$> getObjectArrayElement args 0
    b <- unsafeCast <$> getObjectArrayElement args 1
    a' <- reifA a
    b' <- reifB b
    upcast <$> reflC (f a' b')
  where
    reifA = reify :: J (Interp a) -> IO a
    reifB = reify :: J (Interp b) -> IO b
    reflC = reflect :: c -> IO (J (Interp c))

clos2bs :: Typeable a => Closure a -> ByteString
clos2bs = LBS.toStrict . encode

bs2clos :: Typeable a => ByteString -> Closure a
bs2clos = decode . LBS.fromStrict

-- TODO No Static (Reify/Reflect (Closure (a -> b)) ty) instances yet.

instance ( Reflect a
         , Reify b
         , Typeable a
         , Typeable b
         ) =>
         Reify (Function a b) where
  reify jobj = do
      klass <- findClass $
        referenceTypeName (SClass "io.tweag.sparkle.function.HaskellFunction")
      field <- getFieldID klass "clos" (signature $ SArray (SPrim "byte"))
      jpayload <- getObjectField jobj field
      payload <- reify (unsafeCast jpayload)
      return $ Function (bs2clos payload)

-- Needs UndecidableInstances
instance ( Static (Reify a)
         , Static (Reflect b)
         , Typeable a
         , Typeable b
         ) =>
         Reflect (Function a b) where
  reflect (Function f) = do
      jpayload <- reflect (clos2bs wrap)
      obj :: J ('Class "io.tweag.sparkle.function.HaskellFunction") <- new [coerce jpayload]
      return (generic (unsafeCast obj))
    where
      wrap :: Closure (JObjectArray -> IO JObject)
      wrap = $(cstatic 'closFun1) `cap`
             ($(cstatic 'pairDict) `cap` closureDict `cap` closureDict) `cap`
             f

instance ( Reflect a
         , Reflect b
         , Reify   c
         , Typeable a
         , Typeable b
         , Typeable c
         ) =>
         Reify (Function2 a b c) where
  reify jobj = do
      klass <- findClass $
        referenceTypeName (SClass "io.tweag.sparkle.function.HaskellFunction2")
      field <- getFieldID klass "clos" (signature $ SArray (SPrim "byte"))
      jpayload <- getObjectField jobj field
      payload <- reify (unsafeCast jpayload)
      return $ Function2 (bs2clos payload)

instance ( Static (Reify a)
         , Static (Reify b)
         , Static (Reflect c)
         , Typeable a
         , Typeable b
         , Typeable c
         ) =>
         Reflect (Function2 a b c) where
  reflect (Function2 f) = do
      jpayload <- reflect (clos2bs wrap)
      obj :: J ('Class "io.tweag.sparkle.function.HaskellFunction2") <- new [coerce jpayload]
      return (generic (unsafeCast obj))
    where
      wrap :: Closure (JObjectArray -> IO JObject)
      wrap = $(cstatic 'closFun2) `cap`
             ($(cstatic 'tripleDict) `cap` closureDict `cap` closureDict `cap` closureDict) `cap`
             f
