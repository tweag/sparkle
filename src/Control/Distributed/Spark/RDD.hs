-- | Bindings for
-- <https://spark.apache.org/docs/latest/api/java/org/apache/spark/api/java/JavaRDD.html org.apache.spark.api.java.JavaRDD>.
--
-- Please refer to that documentation for the meaning of each binding.

{-# LANGUAGE CPP #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StaticPointers #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

{-# OPTIONS_GHC -fplugin=Language.Java.Inline.Plugin #-}

module Control.Distributed.Spark.RDD
  ( RDD(..)
  , repartition
  , filter
  , map
  , module Choice
  , mapPartitions
  , mapPartitionsWithIndex
  , fold
  , reduce
  , aggregate
  , treeAggregate
  , count
  , collect
  , take
  , distinct
  , intersection
  , union
  , sortBy
  , sample
  , randomSplit
  , first
  , getNumPartitions
  , saveAsTextFile
  , subtract
  -- $reading_files
  ) where

import Prelude hiding (filter, map, subtract, take)
import Control.Distributed.Closure
import Control.Distributed.Spark.Closure (reflectFun)
import Control.Monad
import Data.Choice (Choice)
import qualified Data.Choice as Choice
import Data.Int
import qualified Data.Text as Text
import Data.Typeable (Typeable)
import Data.Vector.Storable as V (fromList)
import Foreign.JNI
import Language.Java
import Language.Java.Inline
-- We don't need this instance. But import to bring it in scope transitively for users.
#if MIN_VERSION_base(4,9,1)
import Language.Java.Streaming ()
#endif
import Streaming (Stream, Of)

newtype RDD a = RDD (J ('Class "org.apache.spark.api.java.JavaRDD"))
  deriving Coercible

repartition :: Int32 -> RDD a -> IO (RDD a)
repartition n rdd = [java| $rdd.repartition($n) |]

filter
  :: (Static (Reify a), Typeable a)
  => Closure (a -> Bool)
  -> RDD a
  -> IO (RDD a)
filter clos rdd = do
    f <- unsafeUngeneric <$> reflectFun (sing :: Sing 1) clos
    [java| $rdd.filter($f) |]

map
  :: (Static (Reify a), Static (Reflect b), Typeable a, Typeable b)
  => Closure (a -> b)
  -> RDD a
  -> IO (RDD b)
map clos rdd = do
    f <- unsafeUngeneric <$> reflectFun (sing :: Sing 1) clos
    [java| $rdd.map($f) |]

mapPartitions
  :: (Static (Reify a), Static (Reflect b), Typeable a, Typeable b)
  => Choice "preservePartitions"
  -> Closure (Stream (Of a) IO () -> Stream (Of b) IO ())
  -> RDD a
  -> IO (RDD b)
mapPartitions preservePartitions clos rdd =
  mapPartitionsWithIndex preservePartitions (closure (static const) `cap` clos) rdd

mapPartitionsWithIndex
  :: (Static (Reify a), Static (Reflect b), Typeable a, Typeable b)
  => Choice "preservePartitions"
  -> Closure (Int32 -> Stream (Of a) IO () -> Stream (Of b) IO ())
  -> RDD a
  -> IO (RDD b)
mapPartitionsWithIndex preservePartitions clos rdd = do
  f <- unsafeUngeneric <$> reflectFun (sing :: Sing 2) clos
  [java| $rdd.mapPartitionsWithIndex($f, $preservePartitions) |]

fold
  :: (Static (Reify a), Static (Reflect a), Typeable a)
  => Closure (a -> a -> a)
  -> a
  -> RDD a
  -> IO a
fold clos zero rdd = do
  f <- unsafeUngeneric <$> reflectFun (sing :: Sing 2) clos
  jzero <- upcast <$> reflect zero
  res :: JObject <- [java| $rdd.fold($jzero, $f) |]
  reify (unsafeCast res)

reduce
  :: (Static (Reify a), Static (Reflect a), Typeable a)
  => Closure (a -> a -> a)
  -> RDD a
  -> IO a
reduce clos rdd = do
  f <- unsafeUngeneric <$> reflectFun (sing :: Sing 2) clos
  res :: JObject <- [java| $rdd.reduce($f) |]
  reify (unsafeCast res)

sortBy
  :: (Static (Reify a), Static (Reflect b), Typeable a, Typeable b)
  => Closure (a -> b)
  -> Choice "ascending"
  -> Int32
  -- ^ Number of partitions.
  -> RDD a
  -> IO (RDD a)
sortBy clos ascending numPartitions rdd = do
  f <- unsafeUngeneric <$> reflectFun (sing :: Sing 1) clos
  [java| $rdd.sortBy($f, $ascending, $numPartitions) |]

aggregate
  :: (Static (Reify a), Static (Reify b), Static (Reflect b), Typeable a, Typeable b)
  => Closure (b -> a -> b)
  -> Closure (b -> b -> b)
  -> b
  -> RDD a
  -> IO b
aggregate seqOp combOp zero rdd = do
  jseqOp <- unsafeUngeneric <$> reflectFun (sing :: Sing 2) seqOp
  jcombOp <- unsafeUngeneric <$> reflectFun (sing :: Sing 2) combOp
  jzero <- upcast <$> reflect zero
  res :: JObject <- [java| $rdd.aggregate($jzero, $jseqOp, $jcombOp) |]
  reify (unsafeCast res)

treeAggregate
  :: (Static (Reify a), Static (Reify b), Static (Reflect b), Typeable a, Typeable b)
  => Closure (b -> a -> b)
  -> Closure (b -> b -> b)
  -> b
  -> Int32
  -> RDD a
  -> IO b
treeAggregate seqOp combOp zero depth rdd = do
  jseqOp <- unsafeUngeneric <$> reflectFun (sing :: Sing 2) seqOp
  jcombOp <- unsafeUngeneric <$> reflectFun (sing :: Sing 2) combOp
  jzero <- upcast <$> reflect zero
  res :: JObject <- [java| $rdd.treeAggregate($jzero, $jseqOp, $jcombOp, $depth) |]
  reify (unsafeCast res)

count :: RDD a -> IO Int64
count rdd = [java| $rdd.count() |] >>= reify

subtract :: RDD a -> RDD a -> IO (RDD a)
subtract rdd1 rdd2 = [java| $rdd1.subtract($rdd2) |]

-- $reading_files
--
-- ==== Note [Reading files]
-- #reading_files#
--
-- File-reading functions might produce a particular form of RDD (HadoopRDD)
-- whose elements are sensitive to the order in which they are used. If
-- the elements are not used sequentially, then the RDD might show incorrect
-- contents [1].
--
-- In practice, most functions respect this access pattern, but 'collect' and
-- 'take' do not. A workaround is to use a copy of the RDD created with
-- 'map' before using those functions.
--
-- [1] https://issues.apache.org/jira/browse/SPARK-1018

-- | See Note [Reading Files] ("Control.Distributed.Spark.RDD#reading_files").
collect :: Reify a => RDD a -> IO [a]
collect rdd = do
    arr :: JObjectArray <- [java| $rdd.collect().toArray() |]
    reify (unsafeCast arr)

-- | See Note [Reading Files] ("Control.Distributed.Spark.RDD#reading_files").
take :: Reify a => Int32 -> RDD a -> IO [a]
take n rdd = do
  arr :: JObjectArray <- [java| $rdd.take($n).toArray() |]
  reify (unsafeCast arr)

distinct :: RDD a -> IO (RDD a)
distinct rdd = [java| $rdd.distinct() |]

intersection :: RDD a -> RDD a -> IO (RDD a)
intersection rdd1 rdd2 = [java| $rdd1.intersection($rdd2) |]

union :: RDD a -> RDD a -> IO (RDD a)
union rdd1 rdd2 = [java| $rdd1.union($rdd2) |]

sample
  :: RDD a
  -> Choice "replacement" -- ^ Whether to sample with replacement
  -> Double -- ^ fraction of elements to keep
  -> IO (RDD a)
sample rdd replacement frac = [java| $rdd.sample($replacement, $frac) |]

randomSplit
  :: RDD a
  -> [Double] -- ^ Statistical weights of RDD fractions.
  -> IO [RDD a]
randomSplit rdd weights = do
  jweights <- reflect $ V.fromList weights
  arr :: JObjectArray <- [java| $rdd.randomSplit($jweights) |]
  n <- getArrayLength arr
  forM [0 .. n - 1] (getObjectArrayElement arr)

first :: Reify a => RDD a -> IO a
first rdd = do
  res :: JObject <- [java| $rdd.first() |]
  reify (unsafeCast res)

getNumPartitions :: RDD a -> IO Int32
getNumPartitions rdd = [java| $rdd.getNumPartitions() |]

saveAsTextFile :: RDD a -> FilePath -> IO ()
saveAsTextFile rdd fp = do
  jfp <- reflect (Text.pack fp)
  -- XXX workaround for inline-java-0.6 not supporting void return types.
  _ :: JObject <- [java| { $rdd.saveAsTextFile($jfp); return null; } |]
  return ()
