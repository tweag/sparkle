{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module Control.Distributed.Spark.SQL.Row where

import Control.Distributed.Spark.PairRDD
import Control.Distributed.Spark.RDD
import Control.Distributed.Spark.SQL.StructType
import Data.Int
import Data.Text
import Language.Java
import Language.Java.Inline

imports "org.apache.spark.api.java.function.*"
imports "org.apache.spark.sql.Row"
imports "org.apache.spark.sql.RowFactory"


newtype Row = Row (J ('Class "org.apache.spark.sql.Row"))
  deriving (Coercible, Interpretation, Reify, Reflect)

toRows :: PairRDD a b -> IO (RDD Row)
toRows prdd =
    [java|
        $prdd.map(new Function<scala.Tuple2<String, Long>, Row>() {
            public Row call(scala.Tuple2<String, Long> tup) {
                return RowFactory.create(tup._2(), tup._1());
            }
        })
     |]

schema :: Row -> IO StructType
schema r = [java| $r.schema() |]

get :: Int32 -> Row -> IO JObject
get i r = [java| $r.get($i) |]

size :: Row -> IO Int32
size r = [java| $r.size() |]

isNullAt :: Int32 -> Row -> IO Bool
isNullAt i r = [java| $r.isNullAt($i) |]

getBoolean :: Int32 -> Row -> IO Bool
getBoolean i r = [java| $r.getBoolean($i) |]

getDouble :: Int32 -> Row -> IO Double
getDouble i r = [java| $r.getDouble($i) |]

getLong :: Int32 -> Row -> IO Int64
getLong i r = [java| $r.getLong($i) |]

getString :: Int32 -> Row -> IO Text
getString i r = [java| $r.getString($i) |] `withLocalRef` reify

getList :: forall a. Reify a => Int32 -> Row -> IO [a]
getList i r =
    [java| $r.getList($i).toArray() |] `withLocalRef` (reify . cast)
  where
    cast :: J ('Array ('Class "java.lang.Object")) -> J ('Array (Interp a))
    cast = unsafeCast

createRow :: [JObject] -> IO Row
createRow vs = do
    jvs <- toArray vs
    [java| RowFactory.create($jvs) |]
