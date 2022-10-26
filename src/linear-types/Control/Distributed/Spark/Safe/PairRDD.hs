-- | Bindings for
-- <https://spark.apache.org/docs/latest/api/java/org/apache/spark/api/java/JavaPairRDD.html org.apache.spark.api.java.JavaPairRDD>.
--
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LinearTypes #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE UndecidableInstances #-}

{-# OPTIONS_GHC -fplugin=Language.Java.Inline.Plugin #-}

module Control.Distributed.Spark.Safe.PairRDD where

-- import Prelude.Linear hiding (IO, min, max, mod, and, or, otherwise)
-- import qualified Prelude.Linear as PL
import System.IO.Linear as LIO
import Control.Functor.Linear as Linear

import Control.Distributed.Closure
import Control.Distributed.Spark.Safe.Closure (reflectFun)
import Control.Distributed.Spark.Safe.Context
import Control.Distributed.Spark.Safe.RDD
import Data.Int
import Data.Text (Text)
import Data.Typeable (Typeable)
import Language.Java.Safe
import Language.Java.Inline.Safe
import Language.Scala.Tuple

newtype PairRDD a b = PairRDD (J ('Class "org.apache.spark.api.java.JavaPairRDD"))
  deriving Coercible

zipWithIndex :: RDD a %1 -> IO (PairRDD a Int64)
zipWithIndex rdd = [java| $rdd.zipWithIndex() |]

fromRDD :: RDD (Tuple2 a b) %1 -> IO (PairRDD a b)
fromRDD rdd =
    [java| org.apache.spark.api.java.JavaPairRDD.fromJavaRDD($rdd) |]

toRDD :: PairRDD a b %1 -> IO (RDD (Tuple2 a b))
toRDD prdd = [java| $prdd.rdd().toJavaRDD() |]

join :: PairRDD a b %1 -> PairRDD a c %1 -> IO (PairRDD a (Tuple2 b c))
join prdd0 prdd1 = [java| $prdd0.join($prdd1) |]

keyBy
  :: (Static (Reify v), Static (Reflect k), Typeable v, Typeable k)
  => Closure (v -> k) -> RDD v %1 -> IO (PairRDD k v)
keyBy byKeyOp rdd = Linear.do
  jbyKeyOp <- ungeneric <$> reflectFun (sing :: Sing 1) byKeyOp
  [java| $rdd.keyBy($jbyKeyOp) |]

mapValues
  :: (Static (Reify a), Static (Reflect b), Typeable a, Typeable b)
  => Closure (a -> b) -> PairRDD k a %1 -> IO (PairRDD k b)
mapValues f prdd = Linear.do
  jf <- ungeneric <$> reflectFun (sing :: Sing 1) f
  [java| $prdd.mapValues($jf) |]

zipWithUniqueId :: RDD a %1 -> IO (PairRDD a Int64)
zipWithUniqueId rdd = [java| $rdd.zipWithUniqueId() |]

reduceByKey
  :: (Static (Reify v), Static (Reflect v), Typeable v)
     => Closure (v -> v -> v)
     -> PairRDD k v
  %1 -> IO (PairRDD k v)
reduceByKey clos rdd = Linear.do
  f <- ungeneric <$> reflectFun (sing :: Sing 2) clos
  [java| $rdd.reduceByKey($f) |]

subtractByKey
  :: PairRDD a b
  %1 -> PairRDD a c
  %1 -> IO (PairRDD a b)
subtractByKey prdd0 prdd1 = [java| $prdd0.subtractByKey($prdd1) |]

wholeTextFiles :: SparkContext %1 -> Text -> IO (PairRDD Text Text)
wholeTextFiles sc uri = Linear.do
  juri <- reflect uri
  [java| $sc.wholeTextFiles($juri) |]

justValues :: PairRDD a b %1 -> IO (RDD b)
justValues prdd = [java| $prdd.values() |]

aggregateByKey
  :: (Static (Reify a), Static (Reify b), Static (Reflect b), Typeable a, Typeable b)
     => Closure (b -> a -> b)
     -> Closure (b -> b -> b)
     -> b
     -> PairRDD k a
  %1 -> IO (PairRDD k b)
aggregateByKey seqOp combOp zero prdd = Linear.do
    jseqOp <- ungeneric <$> reflectFun (sing :: Sing 2) seqOp
    jcombOp <- ungeneric <$> reflectFun (sing :: Sing 2) combOp
    jzero <- upcast <$> reflect zero
    [java| $prdd.aggregateByKey($jzero, $jseqOp, $jcombOp) |]

zip :: RDD a %1 -> RDD b %1 -> IO (PairRDD a b)
zip rdda rddb = [java| $rdda.zip($rddb) |]

sortByKey :: PairRDD a b %1 -> IO (PairRDD a b)
sortByKey prdd = [java| $prdd.sortByKey() |]

-- | Cartesian product of 2 RDDs
cartesian :: RDD a %1 -> RDD b %1 -> IO (PairRDD a b)
cartesian rdd0 rdd1 = [java| $rdd0.cartesian($rdd1) |]
