{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Distributed.Spark as Spark
import Control.Distributed.Spark.SQL.Dataset as Dataset

main :: IO()
main = forwardUnhandledExceptionsToSpark $ do
  conf <- newSparkConf "Hello Deltalake in Sparkle!"
  confSet conf "spark.sql.extensions" "io.delta.sql.DeltaSparkSessionExtension"
  confSet conf "spark.sql.catalog.spark_catalog" "org.apache.spark.sql.delta.catalog.DeltaCatalog"
  session <- builder >>= (`config` conf) >>= getOrCreate
  -- Create a table
  df1 <- Dataset.range 0 5 1 1 session
  Dataset.write df1 >>= Dataset.formatWriter "delta" >>= Dataset.save "delta-table"
  -- Read a table
  Dataset.read session >>= Dataset.formatReader "delta" >>= Dataset.load "delta-table" >>= Dataset.show
  -- Update a table (overwrite)
  df2 <- Dataset.range 5 10 1 1 session
  Dataset.write df2 >>= Dataset.formatWriter "delta" >>= Dataset.modeWriter "overwrite" >>= Dataset.save "delta-table"
  Dataset.read session >>= Dataset.formatReader "delta" >>= Dataset.load "delta-table" >>= Dataset.show
  -- Read older versions of data using time travel
  Dataset.read session >>= Dataset.formatReader "delta" >>= Dataset.optionReader "versionAsOf" "0" >>= Dataset.load "delta-table" >>= Dataset.show
