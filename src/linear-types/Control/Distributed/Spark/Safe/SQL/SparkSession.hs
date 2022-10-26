{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LinearTypes #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE UndecidableInstances #-}

{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# OPTIONS_GHC -fplugin=Language.Java.Inline.Plugin #-}

module Control.Distributed.Spark.Safe.SQL.SparkSession where

import System.IO.Linear as LIO

import Control.Distributed.Spark.Safe.Context
import Language.Java.Safe
import Language.Java.Inline.Safe

newtype SparkSession =
    SparkSession (J ('Class "org.apache.spark.sql.SparkSession"))
  deriving Coercible

newtype Builder =
    Builder (J ('Class "org.apache.spark.sql.SparkSession$Builder"))
  deriving Coercible

builder :: IO Builder
builder = [java| org.apache.spark.sql.SparkSession.builder() |]

config :: Builder %1 -> SparkConf %1 -> IO Builder
config b sc = [java| $b.config($sc) |]

sparkContext :: SparkSession %1 -> IO SparkContext
sparkContext ss =
    [java| new org.apache.spark.api.java.JavaSparkContext($ss.sparkContext()) |]

getOrCreate :: Builder %1 -> IO SparkSession
getOrCreate b = [java| $b.getOrCreate() |]
