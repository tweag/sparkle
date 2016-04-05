{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}
module Control.Distributed.Spark.RDD where

import Control.Distributed.Closure
import Control.Distributed.Spark.Closure ()
import Control.Distributed.Spark.Context
import Data.Coerce
import Data.Int
import Data.Text (Text)
import Foreign.JNI
import Language.Java

import qualified Data.Text as Text

newtype RDD a = RDD (J ('Class "org.apache.spark.api.java.JavaRDD"))

parallelize
  :: Reflect a ty
  => SparkContext
  -> [a]
  -> IO (RDD a)
parallelize sc xs = do
    klass <- findClass "org/apache/spark/api/java/JavaSparkContext"
    method <- getMethodID klass "parallelize" "(Ljava/util/List;)Lorg/apache/spark/api/java/JavaRDD;"
    jxs <- arrayToList =<< reflect xs
    coerce . unsafeCast <$> callObjectMethod sc method [JObject jxs]
  where
    arrayToList jxs = do
      klass <- findClass "java/util/Arrays"
      method <- getStaticMethodID klass "asList" "([Ljava/lang/Object;)Ljava/util/List;"
      callStaticObjectMethod klass method [JObject jxs]


filter
  :: Reflect (Closure (a -> Bool)) ty
  => Closure (a -> Bool)
  -> RDD a
  -> IO (RDD a)
filter clos rdd = do
    f <- reflect clos
    klass <- findClass "org/apache/spark/api/java/JavaRDD"
    method <- getMethodID klass "filter" "(Lorg/apache/spark/api/java/function/Function;)Lorg/apache/spark/api/java/JavaRDD;"
    coerce . unsafeCast <$> callObjectMethod rdd method [JObject f]

map
  :: Reflect (Closure (a -> b)) ty
  => Closure (a -> b)
  -> RDD a
  -> IO (RDD b)
map clos rdd = do
    f <- reflect clos
    klass <- findClass "org/apache/spark/api/java/JavaRDD"
    method <- getMethodID klass "map" "(Lorg/apache/spark/api/java/function/Function;)Lorg/apache/spark/api/java/JavaRDD;"
    coerce . unsafeCast <$> callObjectMethod rdd method [JObject f]

fold
  :: (Reflect (Closure (a -> a -> a)) ty1, Reflect a ty2, Reify a ty2)
  => Closure (a -> a -> a)
  -> a
  -> RDD a
  -> IO a
fold clos zero rdd = do
  f <- reflect clos
  jzero <- reflect zero
  klass <- findClass "org/apache/spark/api/java/JavaRDD"
  method <- getMethodID klass "fold" "(Ljava/lang/Object;Lorg/apache/spark/api/java/function/Function2;)Ljava/lang/Object;"
  res <- unsafeCast <$> callObjectMethod rdd method [JObject jzero, JObject f]
  reify res

reduce
  :: (Reflect (Closure (a -> a -> a)) ty1, Reify a ty2, Reflect a ty2)
  => Closure (a -> a -> a)
  -> RDD a
  -> IO a
reduce clos rdd = do
  f <- reflect clos
  klass <- findClass "org/apache/spark/api/java/JavaRDD"
  method <- getMethodID klass "reduce" "(Lorg/apache/spark/api/java/function/Function2;)Ljava/lang/Object;"
  res <- unsafeCast <$> callObjectMethod rdd method [JObject f]
  reify res

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
  jzero <- reflect zero
  klass <- findClass "org/apache/spark/api/java/JavaRDD"
  method <- getMethodID klass "aggregate" "(Ljava/lang/Object;Lorg/apache/spark/api/java/function/Function2;Lorg/apache/spark/api/java/function/Function2;)Ljava/lang/Object;"
  res <- unsafeCast <$> callObjectMethod rdd method [JObject jzero, JObject jseqOp, JObject jcombOp]
  reify res

count :: RDD a -> IO Int64
count rdd = do
  cls <- findClass "org/apache/spark/api/java/JavaRDD"
  mth <- getMethodID cls "count" "()J"
  callLongMethod rdd mth []

collect :: Reify a ty => RDD a -> IO [a]
collect rdd = do
  klass  <- findClass "org/apache/spark/api/java/JavaRDD"
  method <- getMethodID klass "collect" "()Ljava/util/List;"
  alst   <- callObjectMethod rdd method []
  aklass <- findClass "java/util/ArrayList"
  atoarr <- getMethodID aklass "toArray" "()[Ljava/lang/Object;"
  arr    <- callObjectMethod alst atoarr []
  reify (unsafeCast arr)

take :: Reify a ty => RDD a -> Int32 -> IO [a]
take rdd n = do
  cls <- findClass "org/apache/spark/api/java/JavaRDD"
  method <- getMethodID cls "take" "(I)Ljava/util/List;"
  res <- callObjectMethod rdd method [JInt n]
  aklass <- findClass "java/util/ArrayList"
  atoarr <- getMethodID aklass "toArray" "()[Ljava/lang/Object;"
  arr    <- callObjectMethod res atoarr []
  reify (unsafeCast arr)

textFile :: SparkContext -> FilePath -> IO (RDD Text)
textFile sc path = do
  jpath <- reflect (Text.pack path)
  cls <- findClass "org/apache/spark/api/java/JavaSparkContext"
  method <- getMethodID cls "textFile" "(Ljava/lang/String;)Lorg/apache/spark/api/java/JavaRDD;"
  coerce . unsafeCast <$> callObjectMethod sc method [JObject jpath]

distinct :: RDD a -> IO (RDD a)
distinct r = do
  cls <- findClass "org/apache/spark/api/java/JavaRDD"
  method <- getMethodID cls "distinct" "()Lorg/apache/spark/api/java/JavaRDD;"
  coerce . unsafeCast <$> callObjectMethod r method []

intersection :: RDD a -> RDD a -> IO (RDD a)
intersection r r' = do
  cls <- findClass "org/apache/spark/api/java/JavaRDD"
  method <- getMethodID cls "intersection" "(Lorg/apache/spark/api/java/JavaRDD;)Lorg/apache/spark/api/java/JavaRDD;"
  coerce . unsafeCast <$> callObjectMethod r method [JObject r']

union :: RDD a -> RDD a -> IO (RDD a)
union r r' = do
  cls <- findClass "org/apache/spark/api/java/JavaRDD"
  method <- getMethodID cls "union" "(Lorg/apache/spark/api/java/JavaRDD;)Lorg/apache/spark/api/java/JavaRDD;"
  coerce . unsafeCast <$> callObjectMethod r method [JObject r']

sample :: RDD a
       -> Bool   -- ^ sample with replacement (can elements be sampled
                 --   multiple times) ?
       -> Double -- ^ fraction of elements to keep
       -> IO (RDD a)
sample r withReplacement frac = do
  let rep = if withReplacement then 255 else 0
  cls <- findClass "org/apache/spark/api/java/JavaRDD"
  method <- getMethodID cls "sample" "(ZD)Lorg/apache/spark/api/java/JavaRDD;"
  coerce . unsafeCast <$> callObjectMethod r method [JBoolean rep, JDouble frac]

first :: Reify a ty => RDD a -> IO a
first rdd = do
  cls <- findClass "org/apache/spark/api/java/JavaRDD"
  method <- getMethodID cls "first" "()Ljava/lang/Object;"
  res <- fmap (coerce . unsafeCast) $ callObjectMethod rdd method []
  reify res

getNumPartitions :: RDD a -> IO Int32
getNumPartitions rdd = do
  cls <- findClass "org/apache/spark/api/java/JavaRDD"
  method <- getMethodID cls "getNumPartitions" "()I"
  callIntMethod rdd method []

saveAsTextFile :: RDD a -> FilePath -> IO ()
saveAsTextFile rdd fp = do
  jfp <- reflect (Text.pack fp)
  cls <- findClass "org/apache/spark/api/java/JavaRDD"
  method <- getMethodID cls "saveAsTextFile" "(Ljava/lang/String;)V"
  callVoidMethod rdd method [JObject jfp]
