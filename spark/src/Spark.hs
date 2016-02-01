{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE StaticPointers #-}
module Spark where

import           Closure
import           Control.Distributed.Closure
-- import           Data.Binary.Serialise.CBOR
import qualified Data.ByteString as BS
import           Data.ByteString (ByteString)
import           Data.ByteString.Unsafe (unsafeUseAsCStringLen)
import           Data.Monoid     ((<>))
import           Data.Vector     (Vector, fromList)
import           Foreign.C.String (withCString)
import           Foreign.C.Types
import           Foreign.Marshal.Array (withArrayLen, peekArray)
import           Foreign.Marshal.Alloc (alloca)
import           Foreign.Storable (peek)
import           JNI
import qualified Language.C.Inline as C

C.context (C.baseCtx <> jniCtx)

C.include "../SparkClasses.h"

-- TODO:
-- eventually turn all the 'type's into 'newtype's?

type SparkConf = JObject

{-
newSparkConf :: String -> IO SparkConf
newSparkConf name =
    withCString name $ \nameptr -> do
      [C.block| jobject {
           newSparkConf($(char *nameptr));
      } |]
-}

newSparkConf :: String -> IO SparkConf
newSparkConf appname = do
  cls <- findClass "org/apache/spark/SparkConf"
  setAppName <- findMethod cls "setAppName" "(Ljava/lang/String;)Lorg/apache/spark/SparkConf;"
  cnf <- newObject cls "()V" []
  jname <- newString appname
  callObjectMethod cnf setAppName [JObj jname]
  return cnf

type SparkContext = JObject

{-
newSparkContext :: SparkConf -> IO SparkContext
newSparkContext conf =
    [C.block| jobject {
         newSparkContext($(jobject conf));
    } |]
-}

newSparkContext :: SparkConf -> IO SparkContext
newSparkContext conf = do
  cls <- findClass "org/apache/spark/api/java/JavaSparkContext"
  newObject cls "(Lorg/apache/spark/SparkConf;)V" [JObj conf]

type RDD a = JObject

{-
parallelize :: SparkContext -> [Int] -> IO RDD
parallelize sc vec = withArrayLen (map fromIntegral vec) $ \vecLen vecBuf ->
  let vecLen' = fromIntegral vecLen in
  [C.block| jobject {
      parallelize($(jobject sc), $(int* vecBuf), $(size_t vecLen'));
  } |]
-}

parallelize :: SparkContext -> [CInt] -> IO (RDD CInt)
parallelize sc xs = do
  cls <- findClass "Helper"
  method <- findStaticMethod cls "parallelize" "(Lorg/apache/spark/api/java/JavaSparkContext;[I)Lorg/apache/spark/api/java/JavaRDD;"
  jxs <- newIntArray (fromIntegral $ length xs) xs
  callStaticObjectMethod cls method [JObj sc, JObj jxs]

{-
rddmap :: Closure (CInt -> CInt)
       -> RDD
       -> IO RDD
rddmap clos rdd =
  unsafeUseAsCStringLen closBS $ \(closBuf, closSize) ->
  let closSize' = fromIntegral closSize in
  [C.block| jobject {
      rddmap($(jobject rdd), $(char* closBuf), $(long closSize'));
  } |]

  where closBS = clos2bs clos
-}

rddmap :: Closure (CInt -> CInt)
       -> RDD CInt
       -> IO (RDD CInt)
rddmap clos rdd =
  unsafeUseAsCStringLen closBS $ \(closBuf, closSize) -> do
    closArr <- newByteArray' (fromIntegral closSize) closBuf
    cls <- findClass "Helper"
    method <- findStaticMethod cls "map" "(Lorg/apache/spark/api/java/JavaRDD;[B)Lorg/apache/spark/api/java/JavaRDD;"
    callStaticObjectMethod cls method [JObj rdd, JObj closArr]

  where closBS = clos2bs clos

collect :: RDD CInt -> IO [CInt]
collect rdd = fmap (map fromIntegral) $
  alloca $ \buf ->
  alloca $ \size -> do
    [C.block| void {
      collect($(jobject rdd), $(int** buf), $(size_t* size));
    } |]
    sz <- peek size
    b  <- peek buf
    peekArray (fromIntegral sz) b

{-
collect :: RDD -> IO [CInt]
collect rdd =
  alloca $ \buf ->
  alloca $ \size -> do
    cls <- findClass "Helper"
    method <- findStaticMethod cls "collect" "(Lorg/apache/spark/api/java/JavaRDD;)[I"
-}

type PairRDD a b = JObject

zipWithIndex :: RDD a -> IO (PairRDD a CLong)
zipWithIndex rdd = do
  cls <- findClass "org/apache/spark/api/java/JavaRDD"
  method <- findMethod cls "zipWithIndex" "()Lorg/apache/spark/api/java/JavaPairRDD;"
  callObjectMethod rdd method []

wholeTextFiles :: SparkContext -> String -> IO (PairRDD String String)
wholeTextFiles sc uri = do
  juri <- newString uri
  cls <- findClass "org/apache/spark/api/java/JavaSparkContext"
  method <- findMethod cls "wholeTextFiles" "(Ljava/lang/String;)Lorg/apache/spark/api/java/JavaPairRDD;"
  callObjectMethod sc method [JObj juri]

type SQLContext = JObject

newSQLContext :: SparkContext -> IO SQLContext
newSQLContext sc = do
  cls <- findClass "org/apache/spark/sql/SQLContext"
  newObject cls "(Lorg/apache/spark/api/java/JavaSparkContext;)V" [JObj sc]

type Row = JObject
type DataFrame = JObject

toRows :: PairRDD a b -> IO (RDD Row)
toRows prdd = do
  cls <- findClass "Helper"
  mth <- findStaticMethod cls "toRows" "(Lorg/apache/spark/api/java/JavaPairRDD;)Lorg/apache/spark/api/java/JavaRDD;"
  callStaticObjectMethod cls mth [JObj prdd]

toDF :: SQLContext -> RDD Row -> String -> String -> IO DataFrame
toDF sqlc rdd s1 s2 = do
  cls <- findClass "Helper"
  mth <- findStaticMethod cls "toDF" "(Lorg/apache/spark/sql/SQLContext;Lorg/apache/spark/api/java/JavaRDD;Ljava/lang/String;Ljava/lang/String;)Lorg/apache/spark/sql/DataFrame;"
  col1 <- newString s1
  col2 <- newString s2
  callStaticObjectMethod cls mth [JObj sqlc, JObj rdd, JObj col1, JObj col2]

type RegexTokenizer = JObject

newTokenizer :: IO RegexTokenizer
newTokenizer = do
  cls <- findClass "org/apache/spark/ml/feature/RegexTokenizer"
  tok <- newObject cls "()V" []
  setgaps <- findMethod cls "setGaps" "(Z)Lorg/apache/spark/ml/feature/RegexTokenizer;"
  setpatt <- findMethod cls "setPattern" "(Ljava/lang/String;)Lorg/apache/spark/ml/feature/RegexTokenizer;"
  tok' <- callObjectMethod tok setgaps [JBoolean 1]
  jpatt <- newString "\\p{L}+"
  callObjectMethod tok' setpatt [JObj jpatt]

tokenize :: RegexTokenizer -> DataFrame -> IO DataFrame
tokenize tok df = do
  cls <- findClass "org/apache/spark/ml/feature/RegexTokenizer"
  mth <- findMethod cls "transform" "(Lorg/apache/spark/sql/DataFrame;)Lorg/apache/spark/sql/DataFrame;"
  callObjectMethod tok mth [JObj df]

type StopWordsRemover = JObject

newStopWordsRemover :: [String] -> IO StopWordsRemover
newStopWordsRemover stopwords = do
  cls <- findClass "org/apache/spark/ml/feature/StopWordsRemover"
  swr <- newObject cls "()V" []
  setSw <- findMethod cls "setStopWords" "([Ljava/lang/String;)Lorg/apache/spark/ml/feature/StopWordsRemover;"
  stringCls <- findClass "java/lang/String"
  let len = fromIntegral (length stopwords)
  jstopwords <- newObjectArray len stringCls =<< mapM newString stopwords
  swr' <- callObjectMethod swr setSw [JObj jstopwords]
  setCS <- findMethod cls "setCaseSensitive" "(Z)Lorg/apache/spark/ml/feature/StopWordsRemover;"
  callObjectMethod swr setCS [JBoolean 0]

removeStopWords :: StopWordsRemover -> DataFrame -> IO DataFrame
removeStopWords sw df = do
  cls <- findClass "org/apache/spark/ml/feature/StopWordsRemover"
  mth <- findMethod cls "transform" "(Lorg/apache/spark/sql/DataFrame;)Lorg/apache/spark/sql/DataFrame;"
  callObjectMethod sw mth [JObj df]

type CountVectorizer = JObject

newCountVectorizer :: CInt -> IO CountVectorizer
newCountVectorizer vocSize = do
  cls <- findClass "org/apache/spark/ml/feature/CountVectorizer"
  cv  <- newObject cls "()V" []
  setInpc <- findMethod cls "setInputCol" "(Ljava/lang/String;)Lorg/apache/spark/ml/feature/CountVectorizer;"
  jfiltered <- newString "filtered"
  cv' <- callObjectMethod cv setInpc [JObj jfiltered]
  setOutc <- findMethod cls "setOutputCol" "(Ljava/lang/String;)Lorg/apache/spark/ml/feature/CountVectorizer;"
  jfeatures <- newString "features"
  cv'' <- callObjectMethod cv' setOutc [JObj jfeatures]
  setVocSize <- findMethod cls "setVocabSize" "(I)Lorg/apache/spark/ml/feature/CountVectorizer;"
  callObjectMethod cv'' setVocSize [JInt vocSize]

type CountVectorizerModel = JObject

fitCV :: CountVectorizer -> DataFrame -> IO CountVectorizerModel
fitCV cv df = do
  cls <- findClass "org/apache/spark/ml/feature/CountVectorizer"
  mth <- findMethod cls "fit" "(Lorg/apache/spark/sql/DataFrame;)Lorg/apache/spark/ml/feature/CountVectorizerModel;"
  callObjectMethod cv mth [JObj df]

type SparkVector = JObject

toTokenCounts :: CountVectorizerModel -> DataFrame -> IO (PairRDD String SparkVector)
toTokenCounts cvModel df = do
  cls <- findClass "org/apache/spark/ml/feature/CountVectorizerModel"
  mth <- findMethod cls "transform" "(Lorg/apache/spark/sql/DataFrame;)Lorg/apache/spark/sql/DataFrame;"
  df' <- callObjectMethod cvModel mth [JObj df]

  helper <- findClass "Helper"
  fromDF <- findStaticMethod helper "fromDF" "(Lorg/apache/spark/sql/DataFrame;)Lorg/apache/spark/api/java/JavaRDD;"
  fromRows <- findStaticMethod helper "fromRows" "(Lorg/apache/spark/api/java/JavaRDD;)Lorg/apache/spark/api/java/JavaPairRDD;"
  rdd <- callStaticObjectMethod helper fromDF [JObj df']
  callStaticObjectMethod helper fromRows [JObj rdd]

type LDA = JObject

newLDA :: CDouble -- ^ fraction of documents
       -> CInt    -- ^ number of topics
       -> IO LDA
newLDA frac numTopics = do
  cls <- findClass "org/apache/spark/mllib/clustering/LDA"
  lda <- newObject cls "()V" []

  opti_cls <- findClass "org/apache/spark/mllib/clustering/OnlineLDAOptimizer"
  opti <- newObject opti_cls "()V" []
  setMiniBatch <- findMethod opti_cls "setMiniBatchFraction" "(D)Lorg/apache/spark/mllib/clustering/OnlineLDAOptimizer;"
  opti' <- callObjectMethod opti setMiniBatch [JDouble frac]

  setOpti <- findMethod cls "setOptimizer" "(Lorg/apache/spark/mllib/clustering/LDAOptimizer;)Lorg/apache/spark/mllib/clustering/LDA;"
  lda' <- callObjectMethod lda setOpti [JObj opti']

  setK <- findMethod cls "setK" "(I)Lorg/apache/spark/mllib/clustering/LDA;"
  lda'' <- callObjectMethod lda' setK [JInt numTopics]

  setMaxIter <- findMethod cls "setMaxIterations" "(I)Lorg/apache/spark/mllib/clustering/LDA;"
  lda''' <- callObjectMethod lda'' setMaxIter [JInt 2]

  setDocConc <- findMethod cls "setDocConcentration" "(D)Lorg/apache/spark/mllib/clustering/LDA;"
  lda'''' <- callObjectMethod lda''' setDocConc [JDouble $ negate 1]

  setTopicConc <- findMethod cls "setTopicConcentration" "(D)Lorg/apache/spark/mllib/clustering/LDA;"
  lda''''' <- callObjectMethod lda'''' setTopicConc [JDouble $ negate 1]

  return lda'''''

f :: CInt -> CInt
f x = x * 2

wrapped_f :: Closure (CInt -> CInt)
wrapped_f = closure (static f)

sparkMain :: IO ()
sparkMain = do
    conf <- newSparkConf "Hello sparkle!"
    sc   <- newSparkContext conf
    sqlc <- newSQLContext sc
    rdd  <- parallelize sc [1..10]
    rdd' <- rddmap wrapped_f rdd
    irdd <- zipWithIndex rdd'
    trdd <- wholeTextFiles sc "src/"
    res  <- collect rdd'
    tok  <- newTokenizer
    swr  <- newStopWordsRemover ["a", "the", "house"]
    cv   <- newCountVectorizer 20
    lda  <- newLDA 0.2 10000
    print res

foreign export ccall sparkMain :: IO ()
