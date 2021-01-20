-- | Bindings for
-- <https://spark.apache.org/docs/latest/api/java/org/apache/spark/api/java/JavaRDD.html org.apache.spark.api.java.JavaRDD>.
--
-- Please refer to that documentation for the meaning of each binding.

{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedLabels #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StaticPointers #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module Control.Distributed.Spark.RDD
  ( RDD(..)
  , isEmpty
  , toDebugString
  , cache
  , unpersist
  , repartition
  , coalesce
  , filter
  , map
  , module Choice
  , mapPartitions
  , mapPartitionsWithIndex
  , fold
  , reduce
  , slowReduce
  , aggregate
  , slowAggregate
  , treeAggregate
  , count
  , mean
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
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Typeable (Typeable)
import Data.Vector.Storable as V (fromList)
import Foreign.JNI
import Language.Java
import Language.Java.Inline
-- We don't need this instance. But import to bring it in scope transitively for users.
import Language.Java.Streaming ()
import Streaming (Stream, Of, effect)
import qualified Streaming.Prelude as S (fold_, uncons, yield)


newtype RDD a = RDD (J ('Class "org.apache.spark.api.java.JavaRDD"))
  deriving Coercible

cache :: RDD a -> IO (RDD a)
cache rdd = [java| $rdd.cache() |]

unpersist :: RDD a -> Bool -> IO (RDD a)
unpersist rdd blocking = [java| $rdd.unpersist($blocking) |]

isEmpty :: RDD a -> IO Bool
isEmpty rdd = [java| $rdd.isEmpty() |]

toDebugString :: RDD a -> IO Text
toDebugString rdd = withLocalRef [java| $rdd.toDebugString() |] reify

repartition :: Int32 -> RDD a -> IO (RDD a)
repartition n rdd = [java| $rdd.repartition($n) |]

coalesce :: Int32 -> RDD a -> IO (RDD a)
coalesce n rdd = [java| $rdd.coalesce($n) |]

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
  :: ( Static (Reify (Stream (Of a) IO ()))
     , Static (Reflect (Stream (Of b) IO ()))
     , Typeable a
     , Typeable b
     )
  => Choice "preservePartitions"
  -> Closure (Stream (Of a) IO () -> Stream (Of b) IO ())
  -> RDD a
  -> IO (RDD b)
mapPartitions preservePartitions clos rdd =
  mapPartitionsWithIndex preservePartitions (closure (static const) `cap` clos) rdd

mapPartitionsWithIndex
  :: ( Static (Reify (Stream (Of a) IO ()))
     , Static (Reflect (Stream (Of b) IO ()))
     , Typeable a
     , Typeable b
     )
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

slowReduce
  :: (Static (Reify a), Static (Reflect a), Typeable a)
  => Closure (a -> a -> a)
  -> RDD a
  -> IO a
slowReduce clos rdd = do
  f <- unsafeUngeneric <$> reflectFun (sing :: Sing 2) clos
  res :: JObject <- [java| $rdd.reduce($f) |]
  reify (unsafeCast res)

-- | A version of reduce implemented in terms of 'mapPartitions'.
--
-- NOTE: This is not defined in terms of 'aggregate' because we don't have a
-- unit element here.
reduce
  :: ( Static (Reify a)
     , Static (Reflect a)
     , Static (Reify (Stream (Of a) IO ()))
     , Static (Reflect (Stream (Of a) IO ()))
     , Typeable a
     )
  => Closure (a -> a -> a)
  -> RDD a
  -> IO a
reduce combOp rdd0 =
    withLocalRef
      (mapPartitions (Choice.Don't #preservePartitions) combOp' rdd0)
      (slowReduce combOp)
  where
    combOp' = closure (static (\f s -> effect $ S.uncons s >>= \case
                         Just (e, ss) -> S.yield <$> S.fold_ f e id ss
                         Nothing -> return mempty
                       ))
       `cap` combOp

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

slowAggregate
  :: (Static (Reify a), Static (Reify b), Static (Reflect b), Typeable a, Typeable b)
  => Closure (b -> a -> b)
  -> Closure (b -> b -> b)
  -> b
  -> RDD a
  -> IO b
slowAggregate seqOp combOp zero rdd = do
  jseqOp <- unsafeUngeneric <$> reflectFun (sing :: Sing 2) seqOp
  jcombOp <- unsafeUngeneric <$> reflectFun (sing :: Sing 2) combOp
  jzero <- upcast <$> reflect zero
  res :: JObject <- [java| $rdd.aggregate($jzero, $jseqOp, $jcombOp) |]
  reify (unsafeCast res)

-- | A version of aggregate implemented in terms of 'mapPartitions'.
aggregate
  :: ( Static (Reify (Stream (Of a) IO ()))
     , Static (Reflect (Stream (Of b) IO ()))
     , Static (Reify b)
     , Static (Reflect b)
     , Static (Serializable b)
     , Typeable a
     )
  => Closure (b -> a -> b)
  -> Closure (b -> b -> b)
  -> b
  -> RDD a
  -> IO b
aggregate seqOp combOp zero rdd0 =
    withLocalRef
      (mapPartitions (Choice.Don't #preservePartitions) seqOp' rdd0)
      (slowReduce combOp)
  where
    seqOp' = closure (static (\f e s -> effect (S.yield <$> S.fold_ f e id s)))
       `cap` seqOp
       `cap` cpure closureDict zero

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

mean :: RDD Double -> IO Double
mean rdd =
  [java| $rdd.mapToDouble(r -> (double)r).mean() |]

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
