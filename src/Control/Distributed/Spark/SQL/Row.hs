{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
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
toRows prdd = callStatic "Helper" "toRows" [coerce prdd]

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

getList :: forall a. Reify a => Int32 -> Row -> IO [a]
getList i r =
    call r "getList" [coerce i] >>= listToArray >>= reify
  where
    listToArray :: J ('Iface "java.util.List") -> IO (J ('Array (Interp a)))
    listToArray jlist = cast <$> call jlist "toArray" []

    cast :: J ('Array ('Class "java.lang.Object")) -> J ('Array (Interp a))
    cast = unsafeCast

createRow :: [JObject] -> IO Row
createRow vs = do
    jvs <- toArray vs
    callStatic "org.apache.spark.sql.RowFactory"
               "create"
               [coerce jvs]
