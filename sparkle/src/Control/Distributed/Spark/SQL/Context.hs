{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}
module Control.Distributed.Spark.SQL.Context where

import Control.Distributed.Spark.Context
import Data.Coerce
import Foreign.JNI

newtype SQLContext = SQLContext (J ('Class "org.apache.spark.sql.SQLContext"))

newSQLContext :: SparkContext -> IO SQLContext
newSQLContext sc = do
  cls <- findClass "org/apache/spark/sql/SQLContext"
  coerce . unsafeCast <$>
    newObject cls "(Lorg/apache/spark/api/java/JavaSparkContext;)V" [JObject sc]

