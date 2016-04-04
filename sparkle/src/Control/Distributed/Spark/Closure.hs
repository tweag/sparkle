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

module Control.Distributed.Spark.Closure (JFun1, apply) where

import Control.Distributed.Closure
import Control.Distributed.Closure.TH
import Data.Binary (encode, decode)
import qualified Data.ByteString.Lazy as LBS
import Data.ByteString (ByteString)
import Data.Typeable (Typeable)
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

type JFun1 a b = 'Class "io.tweag.sparkle.function.HaskellFunction" <> [Interp a, Interp b]
type instance Interp ('Fun '[a] b) = JFun1 a b

pairDict :: Dict c1 -> Dict c2 -> Dict (c1, c2)
pairDict Dict Dict = Dict

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

clos2bs :: Typeable a => Closure a -> ByteString
clos2bs = LBS.toStrict . encode

bs2clos :: Typeable a => ByteString -> Closure a
bs2clos = decode . LBS.fromStrict

-- TODO No Static (Reify/Reflect (Closure (a -> b)) ty) instances yet.

-- Needs UndecidableInstances
instance ( ty ~ Interp (Uncurry (Closure (a -> b)))
         , ty ~ ('Class "io.tweag.sparkle.function.HaskellFunction" <> [ty1, ty2])
         , Reflect a ty1
         , Reify b ty2
         , Typeable a
         , Typeable b
         , Typeable ty1
         , Typeable ty2
         ) =>
         Reify (Closure (a -> b)) ty where
  reify jobj = do
      klass <- findClass "io/tweag/sparkle/function/HaskellFunction"
      field <- getFieldID klass "clos" "[B"
      jpayload <- getObjectField jobj field
      payload <- reify (unsafeCast jpayload)
      return (bs2clos payload)

-- Needs UndecidableInstances
instance ( ty ~ Interp (Uncurry (Closure (a -> b)))
         , ty ~ ('Class "io.tweag.sparkle.function.HaskellFunction" <> [ty1, ty2])
         , Static (Reify a ty1)
         , Static (Reflect b ty2)
         , Typeable a
         , Typeable b
         , Typeable ty1
         , Typeable ty2
         ) =>
         Reflect (Closure (a -> b)) ty where
  reflect f = do
      klass <- findClass "io/tweag/sparkle/function/HaskellFunction"
      jpayload <- reflect (clos2bs wrap)
      fmap unsafeCast $ newObject klass "([B)V" [JObject jpayload]
    where
      wrap :: Closure (JObjectArray -> IO JObject)
      wrap = $(cstatic 'closFun1) `cap`
             ($(cstatic 'pairDict) `cap` closureDict `cap` closureDict) `cap`
             f
