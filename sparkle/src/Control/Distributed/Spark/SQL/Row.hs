{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}
module Control.Distributed.Spark.SQL.Row where

import Control.Distributed.Spark.PairRDD
import Control.Distributed.Spark.RDD
import Data.Coerce
import Foreign.JNI

newtype Row = Row (J ('Class "org.apache.spark.sql.Row"))

toRows :: PairRDD a b -> IO (RDD Row)
toRows prdd = do
  cls <- findClass "Helper"
  mth <- getStaticMethodID cls "toRows" "(Lorg/apache/spark/api/java/JavaPairRDD;)Lorg/apache/spark/api/java/JavaRDD;"
  coerce . unsafeCast <$> callStaticObjectMethod cls mth [JObject prdd]
