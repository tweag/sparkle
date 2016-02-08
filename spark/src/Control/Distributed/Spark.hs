{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE StaticPointers #-}
module Control.Distributed.Spark where

import           Control.Distributed.Closure
import           Control.Distributed.Spark.Closure
import           Control.Distributed.Spark.JNI
-- import           Data.Binary.Serialise.CBOR
import qualified Data.ByteString as BS
import           Data.ByteString (ByteString)
import           Data.ByteString.Unsafe (unsafeUseAsCStringLen)
import           Data.Monoid     ((<>))
import           Foreign.C.String (withCString)
import           Foreign.C.Types
import           Foreign.Marshal.Array (withArrayLen, peekArray)
import           Foreign.Marshal.Alloc (alloca)
import           Foreign.Storable (peek)
import qualified Language.C.Inline as C

C.context (C.baseCtx <> jniCtx)

-- TODO:
-- eventually turn all the 'type's into 'newtype's?

type SparkConf = JObject

newSparkConf :: JNIEnv -> String -> IO SparkConf
newSparkConf env appname = do
  cls <- findClass env "org/apache/spark/SparkConf"
  setAppName <- findMethod env cls "setAppName" "(Ljava/lang/String;)Lorg/apache/spark/SparkConf;"
  cnf <- newObject env cls "()V" []
  jname <- newString env appname
  callObjectMethod env cnf setAppName [JObj jname]
  return cnf

type SparkContext = JObject

newSparkContext :: JNIEnv -> SparkConf -> IO SparkContext
newSparkContext env conf = do
  cls <- findClass env "org/apache/spark/api/java/JavaSparkContext"
  newObject env cls "(Lorg/apache/spark/SparkConf;)V" [JObj conf]

type RDD a = JObject

parallelize :: JNIEnv -> SparkContext -> [CInt] -> IO (RDD CInt)
parallelize env sc xs = do
  cls <- findClass env "Helper"
  method <- findStaticMethod env cls "parallelize" "(Lorg/apache/spark/api/java/JavaSparkContext;[I)Lorg/apache/spark/api/java/JavaRDD;"
  jxs <- newIntArray env (fromIntegral $ length xs) xs
  callStaticObjectMethod env cls method [JObj sc, JObj jxs]

{-
rddmap :: (FromJObject a, ToJObject b)
       => JNIEnv
       -> Closure (a -> b)
       -> RDD a
       -> IO (RDD b)
rddmap env clos rdd =
  unsafeUseAsCStringLen closBS $ \(closBuf, closSize) -> do
    closArr <- newByteArray' env (fromIntegral closSize) closBuf
    cls <- findClass env "Helper"
    method <- findStaticMethod env cls "map" "(Lorg/apache/spark/api/java/JavaRDD;[B)Lorg/apache/spark/api/java/JavaRDD;"
    callStaticObjectMethod env cls method [JObj rdd, JObj closArr]

  where closBS = clos2bs clos'
        clos'  = closure (static wrap) `cap` clos 
-}

{-
filter :: FromJObject a
       => JNIEnv
       -> Closure (a -> Bool)
       -> RDD a
       -> IO (RDD a)
filter env clos rdd = do
  unsafeUseAsCStringLen closBS $ \(closBuf, closSize) -> do
    closArr <- newByteArray' env (fromIntegral closSize) closBuf
    cls <- findClass env "Helper"
    method <- findStaticMethod env cls "filter" "(Lorg/apache/spark/api/java/JavaRDD;[B)Lorg/apache/spark/api/java/JavaRDD;"
    callStaticObjectMethod env cls method [JObj rdd, JObj closArr]

  where closBS = clos2bs clos'
        clos'  = closure (static wrap) `cap` clos 
-}

filter :: JNIEnv -> Closure (String -> Bool) -> RDD String -> IO (RDD String)
filter env clos rdd = do
  unsafeUseAsCStringLen closBS $ \(closBuf, closSize) -> do
    closArr <- newByteArray' env (fromIntegral closSize) closBuf
    cls <- findClass env "Helper"
    method <- findStaticMethod env cls "filter" "(Lorg/apache/spark/api/java/JavaRDD;[B)Lorg/apache/spark/api/java/JavaRDD;"
    callStaticObjectMethod env cls method [JObj rdd, JObj closArr]

  where closBS = clos2bs clos

count :: JNIEnv -> RDD a -> IO CLong
count env rdd = do
  cls <- findClass env "org/apache/spark/api/java/JavaRDD"
  mth <- findMethod env cls "count" "()J"
  callLongMethod env rdd mth []

{-
-- TODO: rewrite this without using inline-c
collect :: JNIEnv -> RDD CInt -> IO [CInt]
collect env rdd = fmap (map fromIntegral) $
  alloca $ \buf ->
  alloca $ \size -> do
    [C.block| void {
      collect($(JNIEnv* env), $(jobject rdd), $(int** buf), $(size_t* size));
    } |]
    sz <- peek size
    b  <- peek buf
    peekArray (fromIntegral sz) b
-}

type PairRDD a b = JObject

zipWithIndex :: JNIEnv -> RDD a -> IO (PairRDD CLong a)
zipWithIndex env rdd = do
  cls <- findClass env "org/apache/spark/api/java/JavaRDD"
  method <- findMethod env cls "zipWithIndex" "()Lorg/apache/spark/api/java/JavaPairRDD;"
  prdd <- callObjectMethod env rdd method []
  helper <- findClass env "Helper"
  swap <- findStaticMethod env helper "swapPairs" "(Lorg/apache/spark/api/java/JavaPairRDD;)Lorg/apache/spark/api/java/JavaPairRDD;"
  callStaticObjectMethod env helper swap [JObj prdd]

textFile :: JNIEnv -> SparkContext -> String -> IO (RDD String)
textFile env sc path = do
  jpath <- newString env path
  cls <- findClass env "org/apache/spark/api/java/JavaSparkContext"
  method <- findMethod env cls "textFile" "(Ljava/lang/String;)Lorg/apache/spark/api/java/JavaRDD;"
  callObjectMethod env sc method [JObj jpath]

wholeTextFiles :: JNIEnv -> SparkContext -> String -> IO (PairRDD String String)
wholeTextFiles env sc uri = do
  juri <- newString env uri
  cls <- findClass env "org/apache/spark/api/java/JavaSparkContext"
  method <- findMethod env cls "wholeTextFiles" "(Ljava/lang/String;)Lorg/apache/spark/api/java/JavaPairRDD;"
  callObjectMethod env sc method [JObj juri]

justValues :: JNIEnv -> PairRDD a b -> IO (RDD b)
justValues env prdd = do
  cls <- findClass env "org/apache/spark/api/java/JavaPairRDD"
  values <- findMethod env cls "values" "()Lorg/apache/spark/api/java/JavaRDD;"
  callObjectMethod env prdd values []

type SQLContext = JObject

newSQLContext :: JNIEnv -> SparkContext -> IO SQLContext
newSQLContext env sc = do
  cls <- findClass env "org/apache/spark/sql/SQLContext"
  newObject env cls "(Lorg/apache/spark/api/java/JavaSparkContext;)V" [JObj sc]

type Row = JObject
type DataFrame = JObject

toRows :: JNIEnv -> PairRDD a b -> IO (RDD Row)
toRows env prdd = do
  cls <- findClass env "Helper"
  mth <- findStaticMethod env cls "toRows" "(Lorg/apache/spark/api/java/JavaPairRDD;)Lorg/apache/spark/api/java/JavaRDD;"
  callStaticObjectMethod env cls mth [JObj prdd]

toDF :: JNIEnv -> SQLContext -> RDD Row -> String -> String -> IO DataFrame
toDF env sqlc rdd s1 s2 = do
  cls <- findClass env "Helper"
  mth <- findStaticMethod env cls "toDF" "(Lorg/apache/spark/sql/SQLContext;Lorg/apache/spark/api/java/JavaRDD;Ljava/lang/String;Ljava/lang/String;)Lorg/apache/spark/sql/DataFrame;"
  col1 <- newString env s1
  col2 <- newString env s2
  callStaticObjectMethod env cls mth [JObj sqlc, JObj rdd, JObj col1, JObj col2]

type RegexTokenizer = JObject

newTokenizer :: JNIEnv -> String -> String -> IO RegexTokenizer
newTokenizer env icol ocol = do
  cls <- findClass env "org/apache/spark/ml/feature/RegexTokenizer"
  tok0 <- newObject env cls "()V" []
  let patt = "\\p{L}+"
  let gaps = False
  let jgaps = if gaps then 1 else 0
  jpatt <- newString env patt
  jicol <- newString env icol
  jocol <- newString env ocol
  helper <- findClass env "Helper"
  setuptok <- findStaticMethod env helper "setupTokenizer" "(Lorg/apache/spark/ml/feature/RegexTokenizer;Ljava/lang/String;Ljava/lang/String;ZLjava/lang/String;)Lorg/apache/spark/ml/feature/RegexTokenizer;"
  callStaticObjectMethod env helper setuptok [JObj tok0, JObj jicol, JObj jocol, JBoolean jgaps, JObj jpatt]

tokenize :: JNIEnv -> RegexTokenizer -> DataFrame -> IO DataFrame
tokenize env tok df = do
  cls <- findClass env "org/apache/spark/ml/feature/RegexTokenizer"
  mth <- findMethod env cls "transform" "(Lorg/apache/spark/sql/DataFrame;)Lorg/apache/spark/sql/DataFrame;"
  callObjectMethod env tok mth [JObj df]

type StopWordsRemover = JObject

newStopWordsRemover :: JNIEnv -> [String] -> String -> String -> IO StopWordsRemover
newStopWordsRemover env stopwords icol ocol = do
  cls <- findClass env "org/apache/spark/ml/feature/StopWordsRemover"
  swr0 <- newObject env cls "()V" []
  setSw <- findMethod env cls "setStopWords" "([Ljava/lang/String;)Lorg/apache/spark/ml/feature/StopWordsRemover;"
  stringCls <- findClass env "java/lang/String"
  let len = fromIntegral (length stopwords)
  jstopwords <- newObjectArray env len stringCls =<< mapM (newString env) stopwords
  swr1 <- callObjectMethod env swr0 setSw [JObj jstopwords]
  setCS <- findMethod env cls "setCaseSensitive" "(Z)Lorg/apache/spark/ml/feature/StopWordsRemover;"
  swr2 <- callObjectMethod env swr1 setCS [JBoolean 0]
  seticol <- findMethod env cls "setInputCol" "(Ljava/lang/String;)Lorg/apache/spark/ml/feature/StopWordsRemover;"
  setocol <- findMethod env cls "setOutputCol" "(Ljava/lang/String;)Lorg/apache/spark/ml/feature/StopWordsRemover;"
  jicol <- newString env icol
  jocol <- newString env ocol
  swr3 <- callObjectMethod env swr2 seticol [JObj jicol]
  callObjectMethod env swr3 setocol [JObj jocol]

removeStopWords :: JNIEnv -> StopWordsRemover -> DataFrame -> IO DataFrame
removeStopWords env sw df = do
  cls <- findClass env "org/apache/spark/ml/feature/StopWordsRemover"
  mth <- findMethod env cls "transform" "(Lorg/apache/spark/sql/DataFrame;)Lorg/apache/spark/sql/DataFrame;"
  callObjectMethod env sw mth [JObj df]

type CountVectorizer = JObject

newCountVectorizer :: JNIEnv -> CInt -> String -> String -> IO CountVectorizer
newCountVectorizer env vocSize icol ocol = do
  cls <- findClass env "org/apache/spark/ml/feature/CountVectorizer"
  cv  <- newObject env cls "()V" []
  setInpc <- findMethod env cls "setInputCol" "(Ljava/lang/String;)Lorg/apache/spark/ml/feature/CountVectorizer;"
  jfiltered <- newString env icol
  cv' <- callObjectMethod env cv setInpc [JObj jfiltered]
  setOutc <- findMethod env cls "setOutputCol" "(Ljava/lang/String;)Lorg/apache/spark/ml/feature/CountVectorizer;"
  jfeatures <- newString env ocol
  cv'' <- callObjectMethod env cv' setOutc [JObj jfeatures]
  setVocSize <- findMethod env cls "setVocabSize" "(I)Lorg/apache/spark/ml/feature/CountVectorizer;"
  callObjectMethod env cv'' setVocSize [JInt vocSize]

type CountVectorizerModel = JObject

fitCV :: JNIEnv -> CountVectorizer -> DataFrame -> IO CountVectorizerModel
fitCV env cv df = do
  cls <- findClass env "org/apache/spark/ml/feature/CountVectorizer"
  mth <- findMethod env cls "fit" "(Lorg/apache/spark/sql/DataFrame;)Lorg/apache/spark/ml/feature/CountVectorizerModel;"
  callObjectMethod env cv mth [JObj df]

type SparkVector = JObject

toTokenCounts :: JNIEnv -> CountVectorizerModel -> DataFrame -> String -> String -> IO (PairRDD CLong SparkVector)
toTokenCounts env cvModel df col1 col2 = do
  cls <- findClass env "org/apache/spark/ml/feature/CountVectorizerModel"
  mth <- findMethod env cls "transform" "(Lorg/apache/spark/sql/DataFrame;)Lorg/apache/spark/sql/DataFrame;"
  df' <- callObjectMethod env cvModel mth [JObj df]

  helper <- findClass env "Helper"
  fromDF <- findStaticMethod env helper "fromDF" "(Lorg/apache/spark/sql/DataFrame;Ljava/lang/String;Ljava/lang/String;)Lorg/apache/spark/api/java/JavaRDD;"
  fromRows <- findStaticMethod env helper "fromRows" "(Lorg/apache/spark/api/java/JavaRDD;)Lorg/apache/spark/api/java/JavaPairRDD;"
  jcol1 <- newString env col1
  jcol2 <- newString env col2
  rdd <- callStaticObjectMethod env helper fromDF [JObj df', JObj jcol1, JObj jcol2]
  callStaticObjectMethod env helper fromRows [JObj rdd]

type LDA = JObject

newLDA :: JNIEnv
       -> CDouble -- ^ fraction of documents
       -> CInt    -- ^ number of topics
       -> CInt    -- ^ maximum number of iterations
       -> IO LDA
newLDA env frac numTopics maxIterations = do
  cls <- findClass env "org/apache/spark/mllib/clustering/LDA"
  lda <- newObject env cls "()V" []

  opti_cls <- findClass env "org/apache/spark/mllib/clustering/OnlineLDAOptimizer"
  opti <- newObject env opti_cls "()V" []
  setMiniBatch <- findMethod env opti_cls "setMiniBatchFraction" "(D)Lorg/apache/spark/mllib/clustering/OnlineLDAOptimizer;"
  opti' <- callObjectMethod env opti setMiniBatch [JDouble frac]

  setOpti <- findMethod env cls "setOptimizer" "(Lorg/apache/spark/mllib/clustering/LDAOptimizer;)Lorg/apache/spark/mllib/clustering/LDA;"
  lda' <- callObjectMethod env lda setOpti [JObj opti']

  setK <- findMethod env cls "setK" "(I)Lorg/apache/spark/mllib/clustering/LDA;"
  lda'' <- callObjectMethod env lda' setK [JInt numTopics]

  setMaxIter <- findMethod env cls "setMaxIterations" "(I)Lorg/apache/spark/mllib/clustering/LDA;"
  lda''' <- callObjectMethod env lda'' setMaxIter [JInt maxIterations]

  setDocConc <- findMethod env cls "setDocConcentration" "(D)Lorg/apache/spark/mllib/clustering/LDA;"
  lda'''' <- callObjectMethod env lda''' setDocConc [JDouble $ negate 1]

  setTopicConc <- findMethod env cls "setTopicConcentration" "(D)Lorg/apache/spark/mllib/clustering/LDA;"
  lda''''' <- callObjectMethod env lda'''' setTopicConc [JDouble $ negate 1]

  return lda'''''

type LDAModel = JObject

runLDA :: JNIEnv -> LDA -> PairRDD CLong SparkVector -> IO LDAModel
runLDA env lda rdd = do
  cls <- findClass env "Helper"
  run <- findStaticMethod env cls "runLDA" "(Lorg/apache/spark/mllib/clustering/LDA;Lorg/apache/spark/api/java/JavaPairRDD;)Lorg/apache/spark/mllib/clustering/LDAModel;"
  callStaticObjectMethod env cls run [JObj lda, JObj rdd]

describeResults :: JNIEnv -> LDAModel -> CountVectorizerModel -> CInt -> IO ()
describeResults env lm cvm maxTerms = do
  cls <- findClass env "Helper"
  mth <- findStaticMethod env cls "describeResults" "(Lorg/apache/spark/mllib/clustering/LDAModel;Lorg/apache/spark/ml/feature/CountVectorizerModel;I)V"
  callStaticVoidMethod env cls mth [JObj lm, JObj cvm, JInt maxTerms]

selectDF :: JNIEnv -> DataFrame -> [String] -> IO DataFrame
selectDF env df (col:cols) = do
  cls <- findClass env "org/apache/spark/sql/DataFrame"
  mth <- findMethod env cls "select" "(Ljava/lang/String;[Ljava/lang/String;)Lorg/apache/spark/sql/DataFrame;"
  jcol <- newString env col
  jcols <- mapM (newString env) cols
  strCls <- findClass env "java/lang/String"
  jcolA <- newObjectArray env (fromIntegral $ length jcols) strCls jcols
  callObjectMethod env df mth [JObj jcol, JObj jcolA]

debugDF :: JNIEnv -> DataFrame -> IO ()
debugDF env df = do
  cls <- findClass env "org/apache/spark/sql/DataFrame"
  mth <- findMethod env cls "show" "()V"
  callVoidMethod env df mth []
