{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StaticPointers #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}

{-# OPTIONS_GHC -fno-warn-orphans #-}

module Language.Scala.Tuple where

import Control.Distributed.Closure.TH
import Language.Java

data Tuple2 a b = Tuple2 a b
  deriving (Show, Eq)

withStatic [d|

  instance (Interpretation a, Interpretation b) =>
           Interpretation (Tuple2 a b) where
    type Interp (Tuple2 a b) =
      'Class "scala.Tuple2" <> '[Interp a, Interp b]

  instance (Reify a, Reify b) =>
           Reify (Tuple2 a b) where
    reify jobj = do
      ja <- call jobj "_1" []
      jb <- call jobj "_2" []
      Tuple2 <$> (reify $ unsafeCast (ja :: JObject))
             <*> (reify $ unsafeCast (jb :: JObject))

  instance (Reflect a, Reflect b) =>
           Reflect (Tuple2 a b) where
    reflect (Tuple2 a b) = do
      ja <- reflect a
      jb <- reflect b
      generic <$> new [coerce $ upcast ja, coerce $ upcast jb]
 |]
