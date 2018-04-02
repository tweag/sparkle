{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE StaticPointers #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE TypeFamilies #-}

{-# OPTIONS_GHC -fplugin=Language.Java.Inline.Plugin #-}

module Control.Distributed.Spark.ML.Rating where

import Control.Distributed.Closure.TH
import Data.Int
import Language.Java
import Language.Java.Inline

type User = Int32

type Product = Int32

newtype Rating = Rating (User, Product, Double)
  deriving (Show, Eq)

withStatic [d|

  instance Interpretation Rating where
    type Interp Rating = 'Class "org.apache.spark.mllib.recommendation.Rating"

  instance Reify Rating where
    reify jobj = Rating <$> ((,,) <$> u <*> p <*> r)
      where
        u = [java| $jobj.user() |]
        p = [java| $jobj.product() |]
        r = [java| $jobj.rating() |]

  instance Reflect Rating where
    reflect (Rating (u, p, r)) = new [JInt u, JInt p, JDouble r]

 |]
