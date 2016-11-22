{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Control.Distributed.Spark.RDD where

import Control.Distributed.Closure
import Control.Distributed.Spark.Closure ()
import Control.Distributed.Spark.Context
import Data.ByteString (ByteString)
import Data.Int
import Data.Text (Text)
import Language.Java

import qualified Data.Text as Text

newtype RDD a = RDD (J ('Class "org.apache.spark.api.java.JavaRDD"))
instance Coercible (RDD a) ('Class "org.apache.spark.api.java.JavaRDD")

parallelize
  :: Reflect a ty
  => SparkContext
  -> [a]
  -> IO (RDD a)
parallelize sc xs = do
    jxs :: J ('Iface "java.util.List") <- arrayToList =<< reflect xs
    call sc "parallelize" [coerce jxs]
  where
    arrayToList jxs =
        callStatic
          (sing :: Sing "java.util.Arrays")
          "asList"
          [coerce (unsafeCast jxs :: JObjectArray)]

repartition :: Int32 -> RDD a -> IO (RDD a)
repartition nbPart rdd = call rdd "repartition" [JInt nbPart]

filter
  :: Reflect (Closure (a -> Bool)) ty
  => Closure (a -> Bool)
  -> RDD a
  -> IO (RDD a)
filter clos rdd = do
    f <- reflect clos
    call rdd "filter" [coerce f]

map
  :: Reflect (Closure (a -> b)) ty
  => Closure (a -> b)
  -> RDD a
  -> IO (RDD b)
map clos rdd = do
    f <- reflect clos
    call rdd "map" [coerce f]

fold
  :: (Reflect (Closure (a -> a -> a)) ty1, Reflect a ty2, Reify a ty2)
  => Closure (a -> a -> a)
  -> a
  -> RDD a
  -> IO a
fold clos zero rdd = do
  f <- reflect clos
  jzero <- upcast <$> reflect zero
  res :: JObject <- call rdd "fold" [coerce jzero, coerce f]
  reify (unsafeCast res)

reduce
  :: (Reflect (Closure (a -> a -> a)) ty1, Reify a ty2, Reflect a ty2)
  => Closure (a -> a -> a)
  -> RDD a
  -> IO a
reduce clos rdd = do
  f <- reflect clos
  res :: JObject <- call rdd "reduce" [coerce f]
  reify (unsafeCast res)

aggregate
  :: ( Reflect (Closure (b -> a -> b)) ty1
     , Reflect (Closure (b -> b -> b)) ty2
     , Reify b ty3
     , Reflect b ty3
     )
  => Closure (b -> a -> b)
  -> Closure (b -> b -> b)
  -> b
  -> RDD a
  -> IO b
aggregate seqOp combOp zero rdd = do
  jseqOp <- reflect seqOp
  jcombOp <- reflect combOp
  jzero <- upcast <$> reflect zero
  res :: JObject <- call rdd "aggregate" [coerce jzero, coerce jseqOp, coerce jcombOp]
  reify (unsafeCast res)

treeAggregate
  :: ( Reflect (Closure (b -> a -> b)) ty1
     , Reflect (Closure (b -> b -> b)) ty2
     , Reflect b ty3
     , Reify b ty3
     )
  => Closure (b -> a -> b)
  -> Closure (b -> b -> b)
  -> b
  -> Int32
  -> RDD a
  -> IO b
treeAggregate seqOp combOp zero depth rdd = do
  jseqOp <- reflect seqOp
  jcombOp <- reflect combOp
  jzero <- upcast <$> reflect zero
  let jdepth = coerce depth
  res :: JObject <-
    call rdd "treeAggregate"
      [ coerce jseqOp, coerce jcombOp, coerce jzero, jdepth ]
  reify (unsafeCast res)

count :: RDD a -> IO Int64
count rdd = call rdd "count" []

collect :: Reify a ty => RDD a -> IO [a]
collect rdd = do
  alst :: J ('Iface "java.util.List") <- call rdd "collect" []
  arr :: JObjectArray <- call alst "toArray" []
  reify (unsafeCast arr)

take :: Reify a ty => RDD a -> Int32 -> IO [a]
take rdd n = do
  res :: J ('Class "java.util.List") <- call rdd "take" [JInt n]
  arr :: JObjectArray <- call res "toArray" []
  reify (unsafeCast arr)

textFile :: SparkContext -> FilePath -> IO (RDD Text)
textFile sc path = do
  jpath <- reflect (Text.pack path)
  call sc "textFile" [coerce jpath]

-- recordLength = number of bytes
binaryRecords :: SparkContext -> FilePath -> Int32 -> IO (RDD ByteString)
binaryRecords sc fp recordLength = do
  jpath <- reflect (Text.pack fp)
  call sc "binaryRecords" [coerce jpath, coerce recordLength]

distinct :: RDD a -> IO (RDD a)
distinct r = call r "distinct" []

intersection :: RDD a -> RDD a -> IO (RDD a)
intersection r r' = call r "intersection" [coerce r']

union :: RDD a -> RDD a -> IO (RDD a)
union r r' = call r "union" [coerce r']

sample :: RDD a
       -> Bool   -- ^ sample with replacement (can elements be sampled
                 --   multiple times) ?
       -> Double -- ^ fraction of elements to keep
       -> IO (RDD a)
sample r withReplacement frac = do
  let rep = if withReplacement then 255 else 0
  call r "sample" [JBoolean rep, JDouble frac]

first :: Reify a ty => RDD a -> IO a
first rdd = do
  res :: JObject <- call rdd "first" []
  reify (unsafeCast res)

getNumPartitions :: RDD a -> IO Int32
getNumPartitions rdd = call rdd "getNumPartitions" []

saveAsTextFile :: RDD a -> FilePath -> IO ()
saveAsTextFile rdd fp = do
  jfp <- reflect (Text.pack fp)
  call rdd "saveAsTextFile" [coerce jfp]
