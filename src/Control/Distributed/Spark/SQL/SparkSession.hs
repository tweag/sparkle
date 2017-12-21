{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE UndecidableInstances #-}

{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# OPTIONS_GHC -fplugin=Language.Java.Inline.Plugin #-}

module Control.Distributed.Spark.SQL.SparkSession where

import Control.Distributed.Spark.Context
import Language.Java
import Language.Java.Inline (java)

newtype SparkSession =
    SparkSession (J ('Class "org.apache.spark.sql.SparkSession"))
  deriving Coercible

newtype Builder =
    Builder (J ('Class "org.apache.spark.sql.SparkSession$Builder"))
  deriving Coercible

builder :: IO Builder
builder = [java| org.apache.spark.sql.SparkSession.builder() |]

config :: Builder -> SparkConf -> IO Builder
config b sc = [java| $b.config($sc) |]

sparkContext :: SparkSession -> IO SparkContext
sparkContext ss =
    [java| new org.apache.spark.api.java.JavaSparkContext($ss.sparkContext()) |]

getOrCreate :: Builder -> IO SparkSession
getOrCreate b = [java| $b.getOrCreate() |]
