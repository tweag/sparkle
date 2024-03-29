-- | Foreign exports and instances to deal with 'Closure' in Spark.

{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE LinearTypes #-}
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

module Control.Distributed.Spark.Safe.Closure
  ( MapPartitionsFunction(..)
  , ReduceFunction(..)
  , ReifyFun(..)
  , reifyFun_
  , ReflectFun(..)
  , JFun1
  , JFun2
  ) where

import qualified Prelude as P
import Prelude.Linear as PL
import Control.Functor.Linear as Linear
import Data.Unrestricted.Linear ()
import Control.Monad.IO.Class.Linear
import qualified System.IO.Linear as LIO

import Control.Distributed.Closure
import Control.Distributed.Closure.TH
import Data.Binary (encode, decode)
import Data.Kind (Type)
import qualified Data.ByteString.Lazy as LBS
import Data.ByteString (ByteString)
import Data.Typeable (Typeable)
import GHC.TypeLits (Nat)
import Streaming (Stream, Of)

import Foreign.JNI.Safe as S
import Foreign.JNI.Types.Safe as S
import Language.Java.Safe
import Language.Java.Inline.Safe
import qualified Language.Java.Unsafe as JUnsafe

pairDict :: Dict c1 -> Dict c2 -> Dict (c1, c2)
pairDict Dict Dict = Dict

closFun1
  :: forall a b.
    Dict (Reify a, Reflect b)
     -> (a -> b)
     -> JObjectArray
  %1 -> LIO.IO JObject
closFun1 Dict f args = Linear.do
  (args', a) <- S.getObjectArrayElement args 0
  Ur a' <- reify_ (unsafeCast a)
  S.deleteLocalRef args'
  upcast <$> reflect (f a')

tripleDict :: Dict c1 -> Dict c2 -> Dict c3 -> Dict (c1, c2, c3)
tripleDict Dict Dict Dict = Dict

closFun2
  :: forall a b c.
    Dict (Reify a, Reify b, Reflect c)
     -> (a -> b -> c)
     -> JObjectArray
  %1 -> LIO.IO JObject
closFun2 Dict f args = Linear.do
    (args', a) <- second unsafeCast <$> S.getObjectArrayElement args 0
    (args'', b) <- second unsafeCast <$> S.getObjectArrayElement args' 1
    Ur a' <- reify_ a
    Ur b' <- reify_ b
    S.deleteLocalRef args''
    upcast <$> reflect (f a' b')
  where
    second :: (n %1 -> o) -> (m, n) %1 -> (m, o)
    second g (a, b) = (a, g b)

clos2bs :: Typeable a => Closure a -> ByteString
clos2bs = LBS.toStrict P.. encode

bs2clos :: Typeable a => ByteString -> Closure a
bs2clos = decode P.. LBS.fromStrict


-- | Like 'Interp', but parameterized by the target arity of the 'Fun' instance.
type family InterpWithArity (n :: Nat) (a :: Type) :: JType

-- | A @ReifyFun n a@ constraint states that @a@ is a function type of arity
-- @n@. That is, a value of this function type can be made from a @JFun{n}@.
class ReifyFun n a where
  -- | Like 'reify', but specialized to reifying functions at a given arity.
  reifyFun :: MonadIO m => Sing n -> J (InterpWithArity n a) %1 -> m (J (InterpWithArity n a), Ur a)

reifyFun_ :: (MonadIO m, ReifyFun n a) => Sing n -> J (InterpWithArity n a) %1 -> m (Ur a)
reifyFun_ s ref =
  reifyFun s ref >>= \(ref', ura) ->
    S.deleteLocalRef ref' >> pure ura

-- TODO define instances for 'ReifyFun'.

-- | A @ReflectFun n a@ constraint states that @a@ is a function type of arity
-- @n@. That is, a @JFun{n}@ can be made from any value of this function type.
class ReflectFun n a where
  -- | Like 'reflect', but specialized to reflecting functions at a given arity.
  reflectFun :: MonadIO m => Sing n -> Closure a -> m (J (InterpWithArity n a))

-- TODO No Static (Fun (a -> b)) instances yet.

type instance InterpWithArity 1 (a -> b) = JFun1 (Interp a) (Interp b)
type JFun1 a b = 'Iface "org.apache.spark.api.java.function.Function" <> [a, b]

instance ( Static (Reify a)
         , Static (Reflect b)
         , Typeable a
         , Typeable b
         ) =>
         ReflectFun 1 (a -> b) where
  reflectFun _ f = Linear.do
      jpayload <- reflect (clos2bs wrap)
      obj :: J ('Class "io.tweag.sparkle.function.HaskellFunction") <- new jpayload End
      return (unsafeGeneric (unsafeCast obj))
    where
      wrap :: Closure (JObjectArray %1-> LIO.IO JObject)
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
  reflectFun _ f = Linear.do
      jpayload <- reflect (clos2bs wrap)
      obj :: J ('Class "io.tweag.sparkle.function.HaskellFunction2") <- new jpayload End
      return (unsafeGeneric (unsafeCast obj))
    where
      wrap :: Closure (JObjectArray %1-> LIO.IO JObject)
      wrap = $(cstatic 'closFun2) `cap`
             ($(cstatic 'tripleDict) `cap` closureDict `cap` closureDict `cap` closureDict) `cap`
             f

newtype ReduceFunction a = ReduceFunction (Closure (a -> a -> a))

instance Interpretation a => Interpretation (ReduceFunction a) where
  type Interp (ReduceFunction a) =
    'Iface "org.apache.spark.api.java.function.ReduceFunction" <> '[Interp a]

instance (Interpretation (ReduceFunction a), Typeable (a -> a -> a)) =>
         Reify (ReduceFunction a) where
  reify jobj0 = Linear.do
      (jobj1, jobj2) <- S.newLocalRef jobj0
      -- We need to do this bc right side of let binding is not linear
      jobj :: J ('Class "io.tweag.sparkle.function.HaskellReduceFunction") <- pure $ unsafeCast jobj1
      Ur bytes <- [java| $jobj.clos |] >>= reify_
      pure $ (jobj2, (Ur P.. ReduceFunction P.. bs2clos) bytes)

instance ( Static (Reify a)
         , Static (Reflect a)
         , Typeable a
         ) =>
         Reflect (ReduceFunction a) where
  reflect (ReduceFunction f) = Linear.do
      jpayload <- reflect (clos2bs wrap)
      unsafeGeneric <$>
        [java| new io.tweag.sparkle.function.HaskellReduceFunction($jpayload) |]
    where
      wrap :: Closure (JObjectArray %1 -> LIO.IO JObject)
      wrap = closure (static closFun2) `cap`
             (closure (static tripleDict)
               `cap` closureDict `cap` closureDict `cap` closureDict
             ) `cap` f

-- | NOTE: we use non-linear IO as the effect monad for the streaming partition
-- functions, because these functions don't have to deal with java references in
-- any way, they are more or less "pure" functions on streams of values from an
-- RDD (maybe this is not true, we'll see)
newtype MapPartitionsFunction a b =
    MapPartitionsFunction (Closure (Stream (Of a) PL.IO () -> Stream (Of b) PL.IO ()))
instance (Interpretation a, Interpretation b) =>
         Interpretation (MapPartitionsFunction a b) where
  type Interp (MapPartitionsFunction a b) =
         'Iface "org.apache.spark.api.java.function.MapPartitionsFunction"
           <> [Interp a, Interp b]

instance ( Interpretation (MapPartitionsFunction a b)
         , Typeable (Stream (Of a) PL.IO () -> Stream (Of b) PL.IO ())
         ) =>
         Reify (MapPartitionsFunction a b) where
  reify jobj0 = Linear.do
      (jobj1, jobj2) <- S.newLocalRef jobj0
      jobj :: J ('Class  "io.tweag.sparkle.function.HaskellMapPartitionsFunction") <- pure $ unsafeCast jobj2
      Ur bytes <- [java| $jobj.clos |] >>= reify_
      pure $ (jobj1, (Ur P.. MapPartitionsFunction P.. bs2clos) bytes)

instance ( Static (Reify (Stream (Of a) PL.IO ()))
         , Static (Reflect (Stream (Of b) PL.IO ()))
         , Interpretation (MapPartitionsFunction a b)
         , Typeable (Stream (Of a) PL.IO ())
         , Typeable (Stream (Of b) PL.IO ())
         ) =>
         Reflect (MapPartitionsFunction a b) where
  reflect (MapPartitionsFunction f) = Linear.do
      jpayload <- reflect (clos2bs wrap)
      unsafeGeneric <$>
        [java| new io.tweag.sparkle.function.HaskellMapPartitionsFunction($jpayload) |]
    where
      wrap :: Closure (JObjectArray %1-> LIO.IO JObject)
      wrap = $(cstatic 'closFun1) `cap`
             ($(cstatic 'pairDict) `cap` closureDict `cap` closureDict) `cap`
             f
