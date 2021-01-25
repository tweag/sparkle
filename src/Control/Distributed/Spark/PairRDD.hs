-- | Bindings for
-- <https://spark.apache.org/docs/latest/api/java/org/apache/spark/api/java/JavaPairRDD.html org.apache.spark.api.java.JavaPairRDD>.
--
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
zipWithIndex rdd = [java| $rdd.zipWithIndex() |]

fromRDD :: RDD (Tuple2 a b) -> IO (PairRDD a b)
fromRDD rdd =
    [java| org.apache.spark.api.java.JavaPairRDD.fromJavaRDD($rdd) |]

toRDD :: PairRDD a b -> IO (RDD (Tuple2 a b))
toRDD prdd = [java| $prdd.rdd().toJavaRDD() |]

join :: PairRDD a b -> PairRDD a c -> IO (PairRDD a (Tuple2 b c))
join prdd0 prdd1 = [java| $prdd0.join($prdd1) |]

keyBy
  :: (Static (Reify v), Static (Reflect k), Typeable v, Typeable k)
  => Closure (v -> k) -> RDD v -> IO (PairRDD k v)
keyBy byKeyOp rdd = do
  jbyKeyOp <- unsafeUngeneric <$> reflectFun (sing :: Sing 1) byKeyOp
  [java| $rdd.keyBy($jbyKeyOp) |]

mapValues
  :: (Static (Reify a), Static (Reflect b), Typeable a, Typeable b)
  => Closure (a -> b) -> PairRDD k a -> IO (PairRDD k b)
mapValues f prdd = do
  jf <- unsafeUngeneric <$> reflectFun (sing :: Sing 1) f
  [java| $prdd.mapValues($jf) |]

zipWithUniqueId :: RDD a -> IO (PairRDD a Int64)
zipWithUniqueId rdd = [java| $rdd.zipWithUniqueId() |]

reduceByKey
  :: (Static (Reify v), Static (Reflect v), Typeable v)
  => Closure (v -> v -> v)
  -> PairRDD k v
  -> IO (PairRDD k v)
reduceByKey clos rdd = do
  f <- unsafeUngeneric <$> reflectFun (sing :: Sing 2) clos
  [java| $rdd.reduceByKey($f) |]

subtractByKey
  :: PairRDD a b
  -> PairRDD a c
  -> IO (PairRDD a b)
subtractByKey prdd0 prdd1 = [java| $prdd0.subtractByKey($prdd1) |]

wholeTextFiles :: SparkContext -> Text -> IO (PairRDD Text Text)
wholeTextFiles sc uri = do
  juri <- reflect uri
  [java| $sc.wholeTextFiles($juri) |]

justValues :: PairRDD a b -> IO (RDD b)
justValues prdd = [java| $prdd.values() |]

aggregateByKey
  :: (Static (Reify a), Static (Reify b), Static (Reflect b), Typeable a, Typeable b)
  => Closure (b -> a -> b)
  -> Closure (b -> b -> b)
  -> b
  -> PairRDD k a
  -> IO (PairRDD k b)
aggregateByKey seqOp combOp zero prdd = do
    jseqOp <- unsafeUngeneric <$> reflectFun (sing :: Sing 2) seqOp
    jcombOp <- unsafeUngeneric <$> reflectFun (sing :: Sing 2) combOp
    jzero <- upcast <$> reflect zero
    [java| $prdd.aggregateByKey($jzero, $jseqOp, $jcombOp) |]

zip :: RDD a -> RDD b -> IO (PairRDD a b)
zip rdda rddb = [java| $rdda.zip($rddb) |]

sortByKey :: PairRDD a b -> IO (PairRDD a b)
sortByKey prdd = [java| $prdd.sortByKey() |]

-- | Cartesian product of 2 RDDs
cartesian :: RDD a -> RDD b -> IO (PairRDD a b)
cartesian rdd0 rdd1 = [java| $rdd0.cartesian($rdd1) |]
