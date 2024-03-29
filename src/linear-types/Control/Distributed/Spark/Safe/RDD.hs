-- | Bindings for
-- <https://spark.apache.org/docs/latest/api/java/org/apache/spark/api/java/JavaRDD.html org.apache.spark.api.java.JavaRDD>.
--
-- Please refer to that documentation for the meaning of each binding.

{-# LANGUAGE DataKinds #-}
{-# LANGUAGE ExplicitForAll #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE LinearTypes #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedLabels #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StaticPointers #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module Control.Distributed.Spark.Safe.RDD
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
  , collectJ
  , take
  , takeJ
  , distinct
  , intersection
  , union
  , sortBy
  , sample
  , randomSplit
  , first
  , firstJ
  , getNumPartitions
  , saveAsTextFile
  , subtract
  -- $reading_files
  ) where

import qualified Prelude
import Prelude.Linear hiding (IO, filter, map, subtract, take, zero)
import qualified Prelude.Linear as PL
import System.IO.Linear as LIO
import Control.Functor.Linear as Linear
import qualified Data.Functor.Linear as Data

import Control.Distributed.Closure
import Control.Distributed.Spark.Safe.Closure (reflectFun)

import Data.Choice (Choice)
import qualified Data.Choice as Choice
import Data.Int
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Typeable (Typeable)
import Data.Vector.Storable as V (fromList)

-- NOTE: We need this in order to be able to use newLocalRef and deleteLocalRef,
-- as the typechecker needs to be able to see the unsafe J data constructor to
-- derive Coercible instances
import qualified Foreign.JNI.Types

import Foreign.JNI.Safe
import Foreign.JNI.Types.Safe
import Language.Java.Safe
import Language.Java.Inline.Safe

import Streaming (Stream, Of, effect)
import qualified Streaming.Prelude as S (fold_, uncons, yield)


newtype RDD a = RDD (J ('Class "org.apache.spark.api.java.JavaRDD"))
  deriving Coercible

cache :: RDD a %1 -> IO (RDD a)
cache rdd = [java| $rdd.cache() |]

unpersist :: RDD a %1 -> Bool -> IO (RDD a)
unpersist rdd blocking = [java| $rdd.unpersist($blocking) |]

isEmpty :: RDD a %1 -> IO (Ur Bool)
isEmpty rdd = [java| $rdd.isEmpty() |]

toDebugString :: RDD a %1 -> IO (Ur Text)
toDebugString rdd = [java| $rdd.toDebugString() |] >>= reify_

repartition :: Int32 -> RDD a %1 -> IO (RDD a)
repartition n rdd = [java| $rdd.repartition($n) |]

coalesce :: Int32 -> RDD a %1 -> IO (RDD a)
coalesce n rdd = [java| $rdd.coalesce($n) |]

filter
  :: (Static (Reify a), Typeable a)
     => Closure (a -> Bool)
     -> RDD a
  %1 -> IO (RDD a)
filter clos rdd = Linear.do
    f <- ungeneric <$> reflectFun (sing :: Sing 1) clos
    [java| $rdd.filter($f) |]

map
  :: (Static (Reify a), Static (Reflect b), Typeable a, Typeable b)
     => Closure (a -> b)
     -> RDD a
  %1 -> IO (RDD b)
map clos rdd = Linear.do
    f <- ungeneric <$> reflectFun (sing :: Sing 1) clos
    [java| $rdd.map($f) |]

mapPartitions
  :: ( Static (Reify (Stream (Of a) PL.IO ()))
     , Static (Reflect (Stream (Of b) PL.IO ()))
     , Typeable a
     , Typeable b
     )
     => Choice "preservePartitions"
     -> Closure (Stream (Of a) PL.IO () -> Stream (Of b) PL.IO ())
     -> RDD a
  %1 -> IO (RDD b)
mapPartitions preservePartitions clos rdd =
  mapPartitionsWithIndex preservePartitions (closure (static const) `cap` clos) rdd

mapPartitionsWithIndex
  :: ( Static (Reify (Stream (Of a) PL.IO ()))
     , Static (Reflect (Stream (Of b) PL.IO ()))
     , Typeable a
     , Typeable b
     )
     => Choice "preservePartitions"
     -> Closure (Int32 -> Stream (Of a) PL.IO () -> Stream (Of b) PL.IO ())
     -> RDD a
  %1 -> IO (RDD b)
mapPartitionsWithIndex preservePartitions clos rdd = Linear.do
  f <- ungeneric <$> reflectFun (sing :: Sing 2) clos
  [java| $rdd.mapPartitionsWithIndex($f, $preservePartitions) |]

-- NOTE: we cannot implement foldJ at this time without the ability to 
-- write instances for linear static closures
fold
  :: (Static (Reify a), Static (Reflect a), Typeable a)
     => Closure (a -> a -> a)
     -> a
     -> RDD a
  %1 -> IO (Ur a)
fold clos zero rdd = Linear.do
  f <- ungeneric <$> reflectFun (sing :: Sing 2) clos
  jzero <- upcast <$> reflect zero
  res :: JObject <- [java| $rdd.fold($jzero, $f) |]
  reify_ (unsafeCast res)

slowReduce
  :: (Static (Reify a), Static (Reflect a), Typeable a)
     => Closure (a -> a -> a)
     -> RDD a
  %1 -> IO (Ur a)
slowReduce clos rdd = Linear.do
  f <- ungeneric <$> reflectFun (sing :: Sing 2) clos
  res :: JObject <- [java| $rdd.reduce($f) |]
  reify_ (unsafeCast res)

-- | A version of reduce implemented in terms of 'mapPartitions'.
--
-- NOTE: This is not defined in terms of 'aggregate' because we don't have a
-- unit element here.
reduce
  :: ( Static (Reify a)
     , Static (Reflect a)
     , Static (Reify (Stream (Of a) PL.IO ()))
     , Static (Reflect (Stream (Of a) PL.IO ()))
     , Typeable a
     )
     => Closure (a -> a -> a)
     -> RDD a
  %1 -> IO (Ur a)
reduce combOp rdd0 =
    mapPartitions (Choice.Don't #preservePartitions) combOp' rdd0 >>= slowReduce combOp
  where
    combOp' = closure (static (\f s -> effect $ S.uncons s Prelude.>>= \case
                         Just (e, ss) -> S.yield Prelude.<$> S.fold_ f e id ss
                         Nothing -> Prelude.return Prelude.mempty
                       ))
       `cap` combOp

sortBy
  :: (Static (Reify a), Static (Reflect b), Typeable a, Typeable b)
     => Closure (a -> b)
     -> Choice "ascending"
     -> Int32
     -- ^ Number of partitions.
     -> RDD a
  %1 -> IO (RDD a)
sortBy clos ascending numPartitions rdd = Linear.do
  f <- ungeneric <$> reflectFun (sing :: Sing 1) clos
  [java| $rdd.sortBy($f, $ascending, $numPartitions) |]

slowAggregate
  :: (Static (Reify a), Static (Reify b), Static (Reflect b), Typeable a, Typeable b)
     => Closure (b -> a -> b)
     -> Closure (b -> b -> b)
     -> b
     -> RDD a
  %1 -> IO (Ur b)
slowAggregate seqOp combOp zero rdd = Linear.do
  jseqOp <- ungeneric <$> reflectFun (sing :: Sing 2) seqOp
  jcombOp <- ungeneric <$> reflectFun (sing :: Sing 2) combOp
  jzero <- upcast <$> reflect zero
  res :: JObject <- [java| $rdd.aggregate($jzero, $jseqOp, $jcombOp) |]
  reify_ (unsafeCast res)

-- | A version of aggregate implemented in terms of 'mapPartitions'.
aggregate
  :: ( Static (Reify (Stream (Of a) PL.IO ()))
     , Static (Reflect (Stream (Of b) PL.IO ()))
     , Static (Reify b)
     , Static (Reflect b)
     , Static (Serializable b)
     , Typeable a
     )
     => Closure (b -> a -> b)
     -> Closure (b -> b -> b)
     -> b
     -> RDD a
  %1 -> IO (Ur b)
aggregate seqOp combOp zero rdd0 =
    mapPartitions (Choice.Don't #preservePartitions) seqOp' rdd0 >>= slowReduce combOp
  where
    seqOp' = closure (static (\f e s -> effect (S.yield Prelude.<$> S.fold_ f e id s)))
       `cap` seqOp
       `cap` cpure closureDict zero

treeAggregate
     :: (Static (Reify a), Static (Reify b), Static (Reflect b), Typeable a, Typeable b)
     => Closure (b -> a -> b)
     -> Closure (b -> b -> b)
     -> b
     -> Int32
     -> RDD a
  %1 -> IO (Ur b)
treeAggregate seqOp combOp zero depth rdd = Linear.do
  jseqOp <- ungeneric <$> reflectFun (sing :: Sing 2) seqOp
  jcombOp <- ungeneric <$> reflectFun (sing :: Sing 2) combOp
  jzero <- upcast <$> reflect zero
  res :: JObject <- [java| $rdd.treeAggregate($jzero, $jseqOp, $jcombOp, $depth) |]
  reify_ (unsafeCast res)

count :: RDD a %1 -> IO (Ur Int64)
count rdd =
  [java| $rdd.count() |] >>= reify_

mean :: RDD Double %1 -> IO (Ur Double)
mean rdd =
  [java| $rdd.mapToDouble(r -> (double)r).mean() |]

subtract :: RDD a %1 -> RDD a %1 -> IO (RDD a)
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
collect :: Reify a => RDD a %1 -> IO (Ur [a])
collect rdd = Linear.do
    arr :: JObjectArray <- [java| $rdd.collect().toArray() |]
    reify_ (unsafeCast arr)

collectJ :: forall a. (Coercible a, IsReferenceType (Ty a)) => RDD a %1 -> IO [a]
collectJ rdd = Linear.do
  arr :: JObjectArray <- [java| $rdd.collect().toArray() |]
  refList :: [J (Ty a)] <- fromArray (unsafeCast arr)
  pure $ Data.fmap (unsafeUncoerce . coerce) refList

-- | See Note [Reading Files] ("Control.Distributed.Spark.RDD#reading_files").
take :: Reify a => Int32 -> RDD a %1 -> IO (Ur [a])
take n rdd = Linear.do
  arr :: JObjectArray <- [java| $rdd.take($n).toArray() |]
  reify_ (unsafeCast arr)

takeJ :: forall a. (Coercible a, IsReferenceType (Ty a)) => Int32 -> RDD a %1 -> IO [a]
takeJ n rdd = Linear.do
  arr :: JObjectArray <- [java| $rdd.take($n).toArray() |]
  refList :: [J (Ty a)] <- fromArray (unsafeCast arr)
  pure $ Data.fmap (unsafeUncoerce . coerce) refList

distinct :: RDD a %1 -> IO (RDD a)
distinct rdd = [java| $rdd.distinct() |]

intersection :: RDD a %1 -> RDD a %1 -> IO (RDD a)
intersection rdd1 rdd2 = [java| $rdd1.intersection($rdd2) |]

union :: RDD a %1 -> RDD a %1 -> IO (RDD a)
union rdd1 rdd2 = [java| $rdd1.union($rdd2) |]

sample
  :: RDD a
  -> Choice "replacement" -- ^ Whether to sample with replacement
  -> Double -- ^ fraction of elements to keep
  -> IO (RDD a)
sample rdd replacement frac = [java| $rdd.sample($replacement, $frac) |]

randomSplit
     :: RDD a
  %1 -> [Double] -- ^ Statistical weights of RDD fractions.
     -> IO [RDD a]
randomSplit rdd weights = Linear.do
  jweights <- reflect $ V.fromList weights
  arr :: JObjectArray <- [java| $rdd.randomSplit($jweights) |]
  (arr', Ur n) <- getArrayLength arr
  go [] arr' (fromEnum n)
    where
      -- Fold-like helper to thread array reference through
      go :: [RDD a] %1 -> JObjectArray %1 -> Int -> IO [RDD a]
      go acc arr' n
        | n == -1   = pure acc <* deleteLocalRef arr'
        | otherwise = Linear.do
          (arr'', elt) <- getObjectArrayElement arr' (toEnum n)
          go ((RDD . unsafeCast) elt : acc) arr'' (n - 1)

first :: Reify a => RDD a %1 -> IO (Ur a)
first rdd = Linear.do
  res :: JObject <- [java| $rdd.first() |]
  reify_ (unsafeCast res)

firstJ :: forall a. Coercible a => RDD a %1 -> IO a
firstJ rdd = Linear.do
  res :: JObject <- [java| $rdd.first() |]
  ref :: J (Ty a) <- pure (unsafeCast res)
  pure . unsafeUncoerce . JObject $ ref

getNumPartitions :: RDD a %1 -> IO (Ur Int32)
getNumPartitions rdd = [java| $rdd.getNumPartitions() |]

saveAsTextFile :: RDD a %1 -> FilePath -> IO ()
saveAsTextFile rdd fp = Linear.do
  jfp <- reflect (Text.pack fp)
  [java| { $rdd.saveAsTextFile($jfp); } |]
