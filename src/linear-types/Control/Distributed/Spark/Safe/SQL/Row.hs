{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LinearTypes #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module Control.Distributed.Spark.Safe.SQL.Row where

import Prelude.Linear hiding (IO)
import System.IO.Linear as LIO
import Control.Functor.Linear as Linear

import Control.Distributed.Spark.Safe.PairRDD
import Control.Distributed.Spark.Safe.RDD
import Control.Distributed.Spark.Safe.SQL.StructType
import Data.Int
import Data.Text
import Foreign.JNI.Safe
import qualified Foreign.JNI.Types
import Language.Java.Safe
import Language.Java.Inline.Safe

imports "org.apache.spark.api.java.function.*"
imports "org.apache.spark.sql.Row"
imports "org.apache.spark.sql.RowFactory"


newtype Row = Row (J ('Class "org.apache.spark.sql.Row"))
  deriving (Coercible)

toRows :: PairRDD a b %1 -> IO (RDD Row)
toRows prdd =
    [java|
        $prdd.map(new Function<scala.Tuple2<String, Long>, Row>() {
            public Row call(scala.Tuple2<String, Long> tup) {
                return RowFactory.create(tup._2(), tup._1());
            }
        })
     |]

schema :: Row %1 -> IO StructType
schema r = [java| $r.schema() |]

get :: Int32 -> Row %1 -> IO JObject
get i r = [java| $r.get($i) |]

size :: Row %1 -> IO (Ur Int32)
size r = [java| $r.size() |]

isNullAt :: Int32 -> Row %1 -> IO (Ur Bool)
isNullAt i r = [java| $r.isNullAt($i) |]

getBoolean :: Int32 -> Row %1 -> IO (Ur Bool)
getBoolean i r = [java| $r.getBoolean($i) |]

getDouble :: Int32 -> Row %1 -> IO (Ur Double)
getDouble i r = [java| $r.getDouble($i) |]

getLong :: Int32 -> Row %1 -> IO (Ur Int64)
getLong i r = [java| $r.getLong($i) |]

getString :: Int32 -> Row %1 -> IO (Ur Text)
getString i r = [java| $r.getString($i) |] >>= reify_

getList :: forall a. Reify a => Int32 -> Row %1 -> IO (Ur [a])
getList i r =
    [java| $r.getList($i).toArray() |] >>= (reify_ . cast)
  where
    cast :: J ('Array ('Class "java.lang.Object")) %1 -> J ('Array (Interp a))
    cast = unsafeCast

createRow :: [JObject] %1 -> IO Row
createRow vs = Linear.do
  (jvs, arr) <- toArray vs
  foldM (\() -> deleteLocalRef) () jvs
  [java| RowFactory.create($arr) |]
