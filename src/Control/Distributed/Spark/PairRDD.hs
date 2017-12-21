{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE UndecidableInstances #-}

{-# OPTIONS_GHC -fplugin=Language.Java.Inline.Plugin #-}

module Control.Distributed.Spark.PairRDD where

import Control.Distributed.Closure
import Control.Distributed.Spark.Closure (reflectFun)
import Control.Distributed.Spark.Context
import Control.Distributed.Spark.RDD
import Data.Int
import Data.Text (Text)
import Data.Typeable (Typeable)
import Language.Java
import Language.Java.Inline (java)
import Language.Scala.Tuple

newtype PairRDD a b = PairRDD (J ('Class "org.apache.spark.api.java.JavaPairRDD"))
  deriving Coercible

zipWithIndex :: RDD a -> IO (PairRDD a Int64)
zipWithIndex rdd = call rdd "zipWithIndex" []

toRDD :: PairRDD a b -> IO (RDD (Tuple2 a b))
toRDD prdd = do
  scalaRDD <- call prdd "rdd" []
  call (scalaRDD :: J ('Class "org.apache.spark.rdd.RDD")) "toJavaRDD" []

fromRDD :: RDD (Tuple2 a b) -> IO (PairRDD a b)
fromRDD rdd =
  callStatic
    "org.apache.spark.api.java.JavaPairRDD"
    "fromJavaRDD"
    [coerce rdd]

fromPairRDD :: PairRDD a b -> IO (RDD (Tuple2 a b))
fromPairRDD prdd = [java| $prdd.rdd().toJavaRDD() |]

toPairRDD :: RDD (Tuple2 a b) -> IO (PairRDD a b)
toPairRDD rdd =
    [java| org.apache.spark.api.java.JavaPairRDD.fromJavaRDD($rdd) |]

join :: PairRDD a b -> PairRDD a c -> IO (PairRDD a (Tuple2 b c))
join prdd0 prdd1 = call prdd0 "join" [coerce prdd1]

keyBy
  :: (Static (Reify v), Static (Reflect k), Typeable v, Typeable k)
  => Closure (v -> k) -> RDD v -> IO (PairRDD k v)
keyBy byKeyOp rdd = do
  jbyKeyOp <- reflectFun (sing :: Sing 1) byKeyOp
  call rdd "keyBy" [ coerce jbyKeyOp ]

mapValues
  :: (Static (Reify a), Static (Reflect b), Typeable a, Typeable b)
  => Closure (a -> b) -> PairRDD k a -> IO (PairRDD k b)
mapValues f prdd = do
  jf <- reflectFun (sing :: Sing 1) f
  call prdd "mapValues" [coerce jf]

wholeTextFiles :: SparkContext -> Text -> IO (PairRDD Text Text)
wholeTextFiles sc uri = do
  juri <- reflect uri
  call sc "wholeTextFiles" [coerce juri]

justValues :: PairRDD a b -> IO (RDD b)
justValues prdd = call prdd "values" []

aggregateByKey
  :: (Static (Reify a), Static (Reify b), Static (Reflect b), Typeable a, Typeable b)
  => Closure (b -> a -> b)
  -> Closure (b -> b -> b)
  -> b
  -> PairRDD k a
  -> IO (PairRDD k b)
aggregateByKey seqOp combOp zero prdd = do
    jseqOp <- reflectFun (sing :: Sing 2) seqOp
    jcombOp <- reflectFun (sing :: Sing 2) combOp
    jzero <- upcast <$> reflect zero
    call prdd "aggregateByKey"
      [coerce jzero, coerce jseqOp, coerce jcombOp]

zip :: RDD a -> RDD b -> IO (PairRDD a b)
zip rdda rddb = call rdda "zip" [coerce rddb]

sortByKey :: PairRDD a b -> IO (PairRDD a b)
sortByKey prdd = call prdd "sortByKey" []
