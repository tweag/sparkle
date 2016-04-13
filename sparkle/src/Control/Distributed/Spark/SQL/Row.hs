{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}

module Control.Distributed.Spark.SQL.Row where

import Control.Distributed.Spark.PairRDD
import Control.Distributed.Spark.RDD
import Foreign.JNI
import Language.Java

newtype Row = Row (J ('Class "org.apache.spark.sql.Row"))

toRows :: PairRDD a b -> IO (RDD Row)
toRows prdd = callStatic (sing :: Sing "Helper") "toRows" [coerce prdd]
