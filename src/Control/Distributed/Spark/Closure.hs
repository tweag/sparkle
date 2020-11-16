-- | Foreign exports and instances to deal with 'Closure' in Spark.

{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StaticPointers #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# OPTIONS_GHC -fplugin=Language.Java.Inline.Plugin #-}

module Control.Distributed.Spark.Closure
  ( MapPartitionsFunction(..)
  , ReduceFunction(..)
  , ReifyFun(..)
  , ReflectFun(..)
  , JFun1
  , JFun2
  , apply
  ) where

import Control.Exception (fromException, catch)
import Control.Distributed.Closure
import Control.Distributed.Closure.TH
import Data.Binary (encode, decode)
import Data.Kind (Type)
import qualified Data.Coerce as Coerce
import qualified Data.ByteString.Lazy as LBS
import Data.ByteString (ByteString)
import Data.Text as Text
import Data.Typeable (Typeable)
import Foreign.ForeignPtr (newForeignPtr_)
import Foreign.ForeignPtr.Unsafe (unsafeForeignPtrToPtr)
import Foreign.JNI
import Foreign.Ptr (Ptr)
import GHC.TypeLits (Nat)
import Language.Java
import Language.Java.Inline
import Streaming (Stream, Of)

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
              je <- new jt
              Foreign.JNI.throw (je :: J ('Class "java/lang/RuntimeException"))
              return jnull
      )

foreign export ccall "sparkle_apply" apply
  :: Ptr JByteArray
  -> Ptr JObjectArray
  -> IO (Ptr JObject)

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

-- | Like 'Interp', but parameterized by the target arity of the 'Fun' instance.
type family InterpWithArity (n :: Nat) (a :: Type) :: JType

-- | A @ReifyFun n a@ constraint states that @a@ is a function type of arity
-- @n@. That is, a value of this function type can be made from a @JFun{n}@.
class ReifyFun n a where
  -- | Like 'reify', but specialized to reifying functions at a given arity.
  reifyFun :: Sing n -> J (InterpWithArity n a) -> IO a

-- TODO define instances for 'ReifyFun'.

-- | A @ReflectFun n a@ constraint states that @a@ is a function type of arity
-- @n@. That is, a @JFun{n}@ can be made from any value of this function type.
class ReflectFun n a where
  -- | Like 'reflect', but specialized to reflecting functions at a given arity.
  reflectFun :: Sing n -> Closure a -> IO (J (InterpWithArity n a))

-- TODO No Static (Fun (a -> b)) instances yet.

type instance InterpWithArity 1 (a -> b) = JFun1 (Interp a) (Interp b)
type JFun1 a b = 'Iface "org.apache.spark.api.java.function.Function" <> [a, b]

instance ( Static (Reify a)
         , Static (Reflect b)
         , Typeable a
         , Typeable b
         ) =>
         ReflectFun 1 (a -> b) where
  reflectFun _ f = do
      jpayload <- reflect (clos2bs wrap)
      obj :: J ('Class "io.tweag.sparkle.function.HaskellFunction") <- new jpayload
      return (generic (unsafeCast obj))
    where
      wrap :: Closure (JObjectArray -> IO JObject)
      wrap = $(cstatic 'closFun1) `cap`
             ($(cstatic 'pairDict) `cap` closureDict `cap` closureDict) `cap`
             f

type instance InterpWithArity 2 (a -> b -> c) = JFun2 (Interp a) (Interp b) (Interp c)
type JFun2 a b c = 'Iface "org.apache.spark.api.java.function.Function2" <> [a, b, c]

instance ( Static (Reify a)
         , Static (Reify b)
         , Static (Reflect c)
         , Typeable a
         , Typeable b
         , Typeable c
         ) =>
         ReflectFun 2 (a -> b -> c) where
  reflectFun _ f = do
      jpayload <- reflect (clos2bs wrap)
      obj :: J ('Class "io.tweag.sparkle.function.HaskellFunction2") <- new jpayload
      return (generic (unsafeCast obj))
    where
      wrap :: Closure (JObjectArray -> IO JObject)
      wrap = $(cstatic 'closFun2) `cap`
             ($(cstatic 'tripleDict) `cap` closureDict `cap` closureDict `cap` closureDict) `cap`
             f

newtype ReduceFunction a = ReduceFunction (Closure (a -> a -> a))

instance Interpretation a => Interpretation (ReduceFunction a) where
  type Interp (ReduceFunction a) =
    'Iface "org.apache.spark.api.java.function.ReduceFunction" <> '[Interp a]

instance (Interpretation (ReduceFunction a), Typeable (a -> a -> a)) =>
         Reify (ReduceFunction a) where
  reify jobj0 = do
      let jobj = cast jobj0
      ReduceFunction . bs2clos <$> ([java| $jobj.clos |] >>= reify)
    where
      cast
        :: J (Interp (ReduceFunction a))
        -> J ('Class "io.tweag.sparkle.function.HaskellReduceFunction")
      cast = unsafeCast

instance ( Static (Reify a)
         , Static (Reflect a)
         , Typeable a
         ) =>
         Reflect (ReduceFunction a) where
  reflect (ReduceFunction f) = do
      jpayload <- reflect (clos2bs wrap)
      generic <$>
        [java| new io.tweag.sparkle.function.HaskellReduceFunction($jpayload) |]
    where
      wrap :: Closure (JObjectArray -> IO JObject)
      wrap = closure (static closFun2) `cap`
             (closure (static tripleDict)
               `cap` closureDict `cap` closureDict `cap` closureDict
             ) `cap` f

newtype MapPartitionsFunction a b =
    MapPartitionsFunction (Closure (Stream (Of a) IO () -> Stream (Of b) IO ()))
instance (Interpretation a, Interpretation b) =>
         Interpretation (MapPartitionsFunction a b) where
  type Interp (MapPartitionsFunction a b) =
         'Iface "org.apache.spark.api.java.function.MapPartitionsFunction"
           <> [Interp a, Interp b]

instance ( Interpretation (MapPartitionsFunction a b)
         , Typeable (Stream (Of a) IO () -> Stream (Of b) IO ())
         ) =>
         Reify (MapPartitionsFunction a b) where
  reify jobj0 = do
      let jobj = cast jobj0
      MapPartitionsFunction . bs2clos <$> ([java| $jobj.clos |] >>= reify)
    where
      cast
        :: J (Interp (MapPartitionsFunction a b))
        -> J ('Class "io.tweag.sparkle.function.HaskellMapPartitionsFunction")
      cast = unsafeCast

instance ( Static (Reify (Stream (Of a) IO ()))
         , Static (Reflect (Stream (Of b) IO ()))
         , Interpretation (MapPartitionsFunction a b)
         , Typeable (Stream (Of a) IO ())
         , Typeable (Stream (Of b) IO ())
         ) =>
         Reflect (MapPartitionsFunction a b) where
  reflect (MapPartitionsFunction f) = do
      jpayload <- reflect (clos2bs wrap)
      generic <$>
        [java| new io.tweag.sparkle.function.HaskellMapPartitionsFunction($jpayload) |]
    where
      wrap :: Closure (JObjectArray -> IO JObject)
      wrap = $(cstatic 'closFun1) `cap`
             ($(cstatic 'pairDict) `cap` closureDict `cap` closureDict) `cap`
             f
