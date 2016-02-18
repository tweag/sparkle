{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}

module Control.Distributed.Spark where

import           Control.Distributed.Closure
import           Control.Distributed.Spark.Closure
import           Data.Int
import qualified Data.Text as Text
import           Data.Text (Text)
import           Data.Typeable
import           Foreign.C.Types
import           Foreign.Java

-- TODO:
-- eventually turn all the 'type's into 'newtype's?

type SparkConf = JObject

newSparkConf :: JNIEnv -> Text -> IO SparkConf
newSparkConf env appname = do
  cls <- findClass env "org/apache/spark/SparkConf"
  setAppName <- getMethodID env cls "setAppName" "(Ljava/lang/String;)Lorg/apache/spark/SparkConf;"
  cnf <- newObject env cls "()V" []
  jname <- reflect env appname
  _ <- callObjectMethod env cnf setAppName [JObject jname]
  return cnf

type SparkContext = JObject

newSparkContext :: JNIEnv -> SparkConf -> IO SparkContext
newSparkContext env conf = do
  cls <- findClass env "org/apache/spark/api/java/JavaSparkContext"
  newObject env cls "(Lorg/apache/spark/SparkConf;)V" [JObject conf]

type RDD a = JObject

parallelize
  :: Reflect [a] a'
  => JNIEnv
  -> SparkContext
  -> [a]
  -> IO (RDD CInt)
parallelize env sc xs = do
    klass <- findClass env "org/apache/spark/api/java/JavaSparkContext"
    method <- getMethodID env klass "parallelize" "(Ljava/util/List;)Lorg/apache/spark/api/java/JavaRDD;"
    jxs <- arrayToList =<< reflect env xs
    callObjectMethod env sc method [JObject jxs]
  where
    arrayToList jxs = do
      klass <- findClass env "java/util/Arrays"
      method <- getStaticMethodID env klass "asList" "([Ljava/lang/Object;)Ljava/util/List;"
      callStaticObjectMethod env klass method [JObject jxs]

filter :: (Reify a a', Typeable a) => JNIEnv -> Closure (a -> Bool) -> RDD a -> IO (RDD a)
filter env clos rdd = do
    f <- reflect env clos
    klass <- findClass env "org/apache/spark/api/java/JavaRDD"
    method <- getMethodID env klass "filter" "(Lorg/apache/spark/api/java/function/Function;)Lorg/apache/spark/api/java/JavaRDD;"
    callObjectMethod env rdd method [JObject f]

count :: JNIEnv -> RDD a -> IO Int64
count env rdd = do
  cls <- findClass env "org/apache/spark/api/java/JavaRDD"
  mth <- getMethodID env cls "count" "()J"
  callLongMethod env rdd mth []

type PairRDD a b = JObject

zipWithIndex :: JNIEnv -> RDD a -> IO (PairRDD Int64 a)
zipWithIndex env rdd = do
  cls <- findClass env "org/apache/spark/api/java/JavaRDD"
  method <- getMethodID env cls "zipWithIndex" "()Lorg/apache/spark/api/java/JavaPairRDD;"
  callObjectMethod env rdd method []

textFile :: JNIEnv -> SparkContext -> FilePath -> IO (RDD Text)
textFile env sc path = do
  jpath <- reflect env (Text.pack path)
  cls <- findClass env "org/apache/spark/api/java/JavaSparkContext"
  method <- getMethodID env cls "textFile" "(Ljava/lang/String;)Lorg/apache/spark/api/java/JavaRDD;"
  callObjectMethod env sc method [JObject jpath]

wholeTextFiles :: JNIEnv -> SparkContext -> Text -> IO (PairRDD Text Text)
wholeTextFiles env sc uri = do
  juri <- reflect env uri
  cls <- findClass env "org/apache/spark/api/java/JavaSparkContext"
  method <- getMethodID env cls "wholeTextFiles" "(Ljava/lang/String;)Lorg/apache/spark/api/java/JavaPairRDD;"
  callObjectMethod env sc method [JObject juri]

justValues :: JNIEnv -> PairRDD a b -> IO (RDD b)
justValues env prdd = do
  cls <- findClass env "org/apache/spark/api/java/JavaPairRDD"
  values <- getMethodID env cls "values" "()Lorg/apache/spark/api/java/JavaRDD;"
  callObjectMethod env prdd values []

type SQLContext = JObject

newSQLContext :: JNIEnv -> SparkContext -> IO SQLContext
newSQLContext env sc = do
  cls <- findClass env "org/apache/spark/sql/SQLContext"
  newObject env cls "(Lorg/apache/spark/api/java/JavaSparkContext;)V" [JObject sc]

type Row = JObject
type DataFrame = JObject

toRows :: JNIEnv -> PairRDD a b -> IO (RDD Row)
toRows env prdd = do
  cls <- findClass env "Helper"
  mth <- getStaticMethodID env cls "toRows" "(Lorg/apache/spark/api/java/JavaPairRDD;)Lorg/apache/spark/api/java/JavaRDD;"
  callStaticObjectMethod env cls mth [JObject prdd]

toDF :: JNIEnv -> SQLContext -> RDD Row -> Text -> Text -> IO DataFrame
toDF env sqlc rdd s1 s2 = do
  cls <- findClass env "Helper"
  mth <- getStaticMethodID env cls "toDF" "(Lorg/apache/spark/sql/SQLContext;Lorg/apache/spark/api/java/JavaRDD;Ljava/lang/String;Ljava/lang/String;)Lorg/apache/spark/sql/DataFrame;"
  col1 <- reflect env s1
  col2 <- reflect env s2
  callStaticObjectMethod env cls mth [JObject sqlc, JObject rdd, JObject col1, JObject col2]

type RegexTokenizer = JObject

newTokenizer :: JNIEnv -> Text -> Text -> IO RegexTokenizer
newTokenizer env icol ocol = do
  cls <- findClass env "org/apache/spark/ml/feature/RegexTokenizer"
  tok0 <- newObject env cls "()V" []
  let patt = "\\p{L}+" :: Text
  let gaps = False
  let jgaps = if gaps then 1 else 0
  jpatt <- reflect env patt
  jicol <- reflect env icol
  jocol <- reflect env ocol
  helper <- findClass env "Helper"
  setuptok <- getStaticMethodID env helper "setupTokenizer" "(Lorg/apache/spark/ml/feature/RegexTokenizer;Ljava/lang/String;Ljava/lang/String;ZLjava/lang/String;)Lorg/apache/spark/ml/feature/RegexTokenizer;"
  callStaticObjectMethod env helper setuptok [JObject tok0, JObject jicol, JObject jocol, JBoolean jgaps, JObject jpatt]

tokenize :: JNIEnv -> RegexTokenizer -> DataFrame -> IO DataFrame
tokenize env tok df = do
  cls <- findClass env "org/apache/spark/ml/feature/RegexTokenizer"
  mth <- getMethodID env cls "transform" "(Lorg/apache/spark/sql/DataFrame;)Lorg/apache/spark/sql/DataFrame;"
  callObjectMethod env tok mth [JObject df]

type StopWordsRemover = JObject

newStopWordsRemover :: JNIEnv -> [Text] -> Text -> Text -> IO StopWordsRemover
newStopWordsRemover env stopwords icol ocol = do
  cls <- findClass env "org/apache/spark/ml/feature/StopWordsRemover"
  swr0 <- newObject env cls "()V" []
  setSw <- getMethodID env cls "setStopWords" "([Ljava/lang/String;)Lorg/apache/spark/ml/feature/StopWordsRemover;"
  jstopwords <- reflect env stopwords
  swr1 <- callObjectMethod env swr0 setSw [JObject jstopwords]
  setCS <- getMethodID env cls "setCaseSensitive" "(Z)Lorg/apache/spark/ml/feature/StopWordsRemover;"
  swr2 <- callObjectMethod env swr1 setCS [JBoolean 0]
  seticol <- getMethodID env cls "setInputCol" "(Ljava/lang/String;)Lorg/apache/spark/ml/feature/StopWordsRemover;"
  setocol <- getMethodID env cls "setOutputCol" "(Ljava/lang/String;)Lorg/apache/spark/ml/feature/StopWordsRemover;"
  jicol <- reflect env icol
  jocol <- reflect env ocol
  swr3 <- callObjectMethod env swr2 seticol [JObject jicol]
  callObjectMethod env swr3 setocol [JObject jocol]

removeStopWords :: JNIEnv -> StopWordsRemover -> DataFrame -> IO DataFrame
removeStopWords env sw df = do
  cls <- findClass env "org/apache/spark/ml/feature/StopWordsRemover"
  mth <- getMethodID env cls "transform" "(Lorg/apache/spark/sql/DataFrame;)Lorg/apache/spark/sql/DataFrame;"
  callObjectMethod env sw mth [JObject df]

type CountVectorizer = JObject

newCountVectorizer :: JNIEnv -> Int32 -> Text -> Text -> IO CountVectorizer
newCountVectorizer env vocSize icol ocol = do
  cls <- findClass env "org/apache/spark/ml/feature/CountVectorizer"
  cv  <- newObject env cls "()V" []
  setInpc <- getMethodID env cls "setInputCol" "(Ljava/lang/String;)Lorg/apache/spark/ml/feature/CountVectorizer;"
  jfiltered <- reflect env icol
  cv' <- callObjectMethod env cv setInpc [JObject jfiltered]
  setOutc <- getMethodID env cls "setOutputCol" "(Ljava/lang/String;)Lorg/apache/spark/ml/feature/CountVectorizer;"
  jfeatures <- reflect env ocol
  cv'' <- callObjectMethod env cv' setOutc [JObject jfeatures]
  setVocSize <- getMethodID env cls "setVocabSize" "(I)Lorg/apache/spark/ml/feature/CountVectorizer;"
  callObjectMethod env cv'' setVocSize [JInt vocSize]

type CountVectorizerModel = JObject

fitCV :: JNIEnv -> CountVectorizer -> DataFrame -> IO CountVectorizerModel
fitCV env cv df = do
  cls <- findClass env "org/apache/spark/ml/feature/CountVectorizer"
  mth <- getMethodID env cls "fit" "(Lorg/apache/spark/sql/DataFrame;)Lorg/apache/spark/ml/feature/CountVectorizerModel;"
  callObjectMethod env cv mth [JObject df]

type SparkVector = JObject

toTokenCounts :: JNIEnv -> CountVectorizerModel -> DataFrame -> Text -> Text -> IO (PairRDD CLong SparkVector)
toTokenCounts env cvModel df col1 col2 = do
  cls <- findClass env "org/apache/spark/ml/feature/CountVectorizerModel"
  mth <- getMethodID env cls "transform" "(Lorg/apache/spark/sql/DataFrame;)Lorg/apache/spark/sql/DataFrame;"
  df' <- callObjectMethod env cvModel mth [JObject df]

  helper <- findClass env "Helper"
  fromDF <- getStaticMethodID env helper "fromDF" "(Lorg/apache/spark/sql/DataFrame;Ljava/lang/String;Ljava/lang/String;)Lorg/apache/spark/api/java/JavaRDD;"
  fromRows <- getStaticMethodID env helper "fromRows" "(Lorg/apache/spark/api/java/JavaRDD;)Lorg/apache/spark/api/java/JavaPairRDD;"
  jcol1 <- reflect env col1
  jcol2 <- reflect env col2
  rdd <- callStaticObjectMethod env helper fromDF [JObject df', JObject jcol1, JObject jcol2]
  callStaticObjectMethod env helper fromRows [JObject rdd]

type LDA = JObject

newLDA :: JNIEnv
       -> Double                               -- ^ fraction of documents
       -> Int32                                -- ^ number of topics
       -> Int32                                -- ^ maximum number of iterations
       -> IO LDA
newLDA env frac numTopics maxIterations = do
  cls <- findClass env "org/apache/spark/mllib/clustering/LDA"
  lda <- newObject env cls "()V" []

  opti_cls <- findClass env "org/apache/spark/mllib/clustering/OnlineLDAOptimizer"
  opti <- newObject env opti_cls "()V" []
  setMiniBatch <- getMethodID env opti_cls "setMiniBatchFraction" "(D)Lorg/apache/spark/mllib/clustering/OnlineLDAOptimizer;"
  opti' <- callObjectMethod env opti setMiniBatch [JDouble frac]

  setOpti <- getMethodID env cls "setOptimizer" "(Lorg/apache/spark/mllib/clustering/LDAOptimizer;)Lorg/apache/spark/mllib/clustering/LDA;"
  lda' <- callObjectMethod env lda setOpti [JObject opti']

  setK <- getMethodID env cls "setK" "(I)Lorg/apache/spark/mllib/clustering/LDA;"
  lda'' <- callObjectMethod env lda' setK [JInt numTopics]

  setMaxIter <- getMethodID env cls "setMaxIterations" "(I)Lorg/apache/spark/mllib/clustering/LDA;"
  lda''' <- callObjectMethod env lda'' setMaxIter [JInt maxIterations]

  setDocConc <- getMethodID env cls "setDocConcentration" "(D)Lorg/apache/spark/mllib/clustering/LDA;"
  lda'''' <- callObjectMethod env lda''' setDocConc [JDouble $ negate 1]

  setTopicConc <- getMethodID env cls "setTopicConcentration" "(D)Lorg/apache/spark/mllib/clustering/LDA;"
  lda''''' <- callObjectMethod env lda'''' setTopicConc [JDouble $ negate 1]

  return lda'''''

type LDAModel = JObject

runLDA :: JNIEnv -> LDA -> PairRDD CLong SparkVector -> IO LDAModel
runLDA env lda rdd = do
  cls <- findClass env "Helper"
  run <- getStaticMethodID env cls "runLDA" "(Lorg/apache/spark/mllib/clustering/LDA;Lorg/apache/spark/api/java/JavaPairRDD;)Lorg/apache/spark/mllib/clustering/LDAModel;"
  callStaticObjectMethod env cls run [JObject lda, JObject rdd]

describeResults :: JNIEnv -> LDAModel -> CountVectorizerModel -> Int32 -> IO ()
describeResults env lm cvm maxTerms = do
  cls <- findClass env "Helper"
  mth <- getStaticMethodID env cls "describeResults" "(Lorg/apache/spark/mllib/clustering/LDAModel;Lorg/apache/spark/ml/feature/CountVectorizerModel;I)V"
  callStaticVoidMethod env cls mth [JObject lm, JObject cvm, JInt maxTerms]

selectDF :: JNIEnv -> DataFrame -> [Text] -> IO DataFrame
selectDF _ _ [] = error "selectDF: not enough arguments."
selectDF env df (col:cols) = do
  cls <- findClass env "org/apache/spark/sql/DataFrame"
  mth <- getMethodID env cls "select" "(Ljava/lang/String;[Ljava/lang/String;)Lorg/apache/spark/sql/DataFrame;"
  jcol <- reflect env col
  jcols <- reflect env cols
  callObjectMethod env df mth [JObject jcol, JObject jcols]

debugDF :: JNIEnv -> DataFrame -> IO ()
debugDF env df = do
  cls <- findClass env "org/apache/spark/sql/DataFrame"
  mth <- getMethodID env cls "show" "()V"
  callVoidMethod env df mth []
