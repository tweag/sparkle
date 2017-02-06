{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}

module Control.Distributed.Spark.SQL.Row where

import Control.Distributed.Spark.PairRDD
import Control.Distributed.Spark.RDD
import Control.Distributed.Spark.SQL.StructType
import Data.Int
import Data.Text
import Language.Java

newtype Row = Row (J ('Class "org.apache.spark.sql.Row"))
instance Coercible Row ('Class "org.apache.spark.sql.Row")

toRows :: PairRDD a b -> IO (RDD Row)
toRows prdd = callStatic (sing :: Sing "Helper") "toRows" [coerce prdd]

schema :: Row -> IO StructType
schema (Row r) = call r "schema" []

get :: Int32 -> Row -> IO JObject
get i r = call r "get" [coerce i]

size :: Row -> IO Int32
size r = call r "size" []

isNullAt :: Int32 -> Row -> IO Bool
isNullAt i (Row r) = call r "isNullAt" [coerce i]

getBoolean :: Int32 -> Row -> IO Bool
getBoolean i r = call r "getBoolean" [coerce i]

getDouble :: Int32 -> Row -> IO Double
getDouble i r = call r "getDouble" [coerce i]

getLong :: Int32 -> Row -> IO Int64
getLong i r = call r "getLong" [coerce i]

getString :: Int32 -> Row -> IO Text
getString i r = call r "getString" [coerce i] >>= reify

getList :: Int32 -> Row -> IO [JObject]
getList i r = do
    jarraylist <- call r "getList" [coerce i]
    call (jarraylist :: J ('Class "java.util.List")) "toArray" [] >>= reify

create :: [JObject] -> IO Row
create vs = do
    jvs <- reflect vs
    callStatic (sing :: Sing "org.apache.spark.sql.RowFactory")
               "create"
               [coerce jvs]
