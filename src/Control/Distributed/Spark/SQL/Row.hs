{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}

module Control.Distributed.Spark.SQL.Row where

import Control.Distributed.Closure.TH
import Control.Distributed.Spark.PairRDD
import Control.Distributed.Spark.RDD
import Control.Distributed.Spark.SQL.StructType
import Data.Int
import Data.Text
import Language.Java

newtype Row = Row (J ('Class "org.apache.spark.sql.Row"))
type instance Interp Row = 'Class "org.apache.spark.sql.Row"

toRows :: PairRDD a b -> IO (RDD Row)
toRows prdd = callStatic (sing :: Sing "Helper") "toRows" [coerce prdd]

schema :: Row -> IO StructType
schema (Row r) = call r "schema" []

rowGet :: Int32 -> Row -> IO JObject
rowGet i (Row r) = call r "get" [coerce i]

rowSize :: Row -> IO Int32
rowSize (Row r) = call r "size" []

isNullAt :: Int32 -> Row -> IO Bool
isNullAt i (Row r) = call r "isNullAt" [coerce i]

getBoolean :: Int32 -> Row -> IO Bool
getBoolean i (Row r) = call r "getBoolean" [coerce i]

getDouble :: Int32 -> Row -> IO Double
getDouble i (Row r) = call r "getDouble" [coerce i]

getLong :: Int32 -> Row -> IO Int64
getLong i (Row r) = call r "getLong" [coerce i]

getString :: Int32 -> Row -> IO Text
getString i (Row r) = call r "getString" [coerce i] >>= reify

createRow :: [JObject] -> IO Row
createRow vs = do
    jvs <- reflect vs
    callStatic (sing :: Sing "org.apache.spark.sql.RowFactory")
               "create"
               [coerce jvs]
     >>= reify

withStatic [d|
  instance Reify Row ('Class "org.apache.spark.sql.Row") where
    reify j = Row <$> reify j

  instance Reflect Row ('Class "org.apache.spark.sql.Row") where
    reflect (Row x) = reflect x
 |]
