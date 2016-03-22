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

data SparkConf

newSparkConf :: Text -> IO (J SparkConf)
newSparkConf appname = do
  cls <- findClass "org/apache/spark/SparkConf"
  setAppName <- getMethodID cls "setAppName" "(Ljava/lang/String;)Lorg/apache/spark/SparkConf;"
  cnf <- fmap unsafeCast $ newObject cls "()V" []
  jname <- reflect appname
  _ <- callObjectMethod cnf setAppName [JObject jname]
  return cnf

confSet :: J SparkConf -> Text -> Text -> IO ()
confSet conf key value = do
  cls <- findClass "org/apache/spark/SparkConf"
  set <- getMethodID cls "set" "(Ljava/lang/String;Ljava/lang/String;)Lorg/apache/spark/SparkConf;"
  jkey <- reflect key
  jval <- reflect value
  _    <- callObjectMethod conf set [JObject jkey, JObject jval]
  return ()

data SparkContext

newSparkContext :: J SparkConf -> IO (J SparkContext)
newSparkContext conf = do
  cls <- findClass "org/apache/spark/api/java/JavaSparkContext"
  fmap unsafeCast $ newObject cls "(Lorg/apache/spark/SparkConf;)V" [JObject conf]

data RDD a

parallelize
  :: Reflect [a] a'
  => J SparkContext
  -> [a]
  -> IO (J (RDD a))
parallelize sc xs = do
    klass <- findClass "org/apache/spark/api/java/JavaSparkContext"
    method <- getMethodID klass "parallelize" "(Ljava/util/List;)Lorg/apache/spark/api/java/JavaRDD;"
    jxs <- arrayToList =<< reflect xs
    fmap unsafeCast $ callObjectMethod sc method [JObject jxs]
  where
    -- arrayToList :: J [a] -> IO (J Object)
    arrayToList jxs = do
      klass <- findClass "java/util/Arrays"
      method <- getStaticMethodID klass "asList" "([Ljava/lang/Object;)Ljava/util/List;"
      callStaticObjectMethod klass method [JObject jxs]


filter :: (Reify a a', Typeable a) => Closure (a -> Bool) -> J (RDD a) -> IO (J (RDD a))
filter clos rdd = do
    f <- reflect clos
    klass <- findClass "org/apache/spark/api/java/JavaRDD"
    method <- getMethodID klass "filter" "(Lorg/apache/spark/api/java/function/Function;)Lorg/apache/spark/api/java/JavaRDD;"
    fmap unsafeCast $ callObjectMethod rdd method [JObject f]

count :: J (RDD a) -> IO Int64
count rdd = do
  cls <- findClass "org/apache/spark/api/java/JavaRDD"
  mth <- getMethodID cls "count" "()J"
  callLongMethod rdd mth []

collect :: Reify a a' => J (RDD a) -> IO [a]
collect rdd = do
  klass  <- findClass "org/apache/spark/api/java/JavaRDD"
  method <- getMethodID klass "collect" "()Ljava/util/List;"
  alst   <- callObjectMethod rdd method []
  aklass <- findClass "java/util/ArrayList"
  atoarr <- getMethodID aklass "toArray" "()[Ljava/lang/Object;"
  arr    <- callObjectMethod alst atoarr []
  reify (unsafeCast arr)


data PairRDD a b

zipWithIndex :: J (RDD a) -> IO (J (PairRDD Int64 a))
zipWithIndex rdd = do
  cls <- findClass "org/apache/spark/api/java/JavaRDD"
  method <- getMethodID cls "zipWithIndex" "()Lorg/apache/spark/api/java/JavaPairRDD;"
  fmap unsafeCast $ callObjectMethod rdd method []


textFile :: J SparkContext -> FilePath -> IO (J (RDD Text))
textFile sc path = do
  jpath <- reflect (Text.pack path)
  cls <- findClass "org/apache/spark/api/java/JavaSparkContext"
  method <- getMethodID cls "textFile" "(Ljava/lang/String;)Lorg/apache/spark/api/java/JavaRDD;"
  fmap unsafeCast $ callObjectMethod sc method [JObject jpath]


wholeTextFiles :: J SparkContext -> Text -> IO (J (PairRDD Text Text))
wholeTextFiles sc uri = do
  juri <- reflect uri
  cls <- findClass "org/apache/spark/api/java/JavaSparkContext"
  method <- getMethodID cls "wholeTextFiles" "(Ljava/lang/String;)Lorg/apache/spark/api/java/JavaPairRDD;"
  fmap unsafeCast $ callObjectMethod sc method [JObject juri]


justValues :: J (PairRDD a b) -> IO (J (RDD b))
justValues prdd = do
  cls <- findClass "org/apache/spark/api/java/JavaPairRDD"
  values <- getMethodID cls "values" "()Lorg/apache/spark/api/java/JavaRDD;"
  fmap unsafeCast $ callObjectMethod prdd values []


data SQLContext


newSQLContext :: J SparkContext -> IO (J SQLContext)
newSQLContext sc = do
  cls <- findClass "org/apache/spark/sql/SQLContext"
  fmap unsafeCast $
    newObject cls "(Lorg/apache/spark/api/java/JavaSparkContext;)V" [JObject sc]


data Row
data DataFrame


toRows :: J (PairRDD a b) -> IO (J (RDD Row))
toRows prdd = do
  cls <- findClass "Helper"
  mth <- getStaticMethodID cls "toRows" "(Lorg/apache/spark/api/java/JavaPairRDD;)Lorg/apache/spark/api/java/JavaRDD;"
  fmap unsafeCast $ callStaticObjectMethod cls mth [JObject prdd]


toDF :: J SQLContext -> J (RDD Row) -> Text -> Text -> IO (J DataFrame)
toDF sqlc rdd s1 s2 = do
  cls <- findClass "Helper"
  mth <- getStaticMethodID cls "toDF" "(Lorg/apache/spark/sql/SQLContext;Lorg/apache/spark/api/java/JavaRDD;Ljava/lang/String;Ljava/lang/String;)Lorg/apache/spark/sql/DataFrame;"
  col1 <- reflect s1
  col2 <- reflect s2
  fmap unsafeCast $
    callStaticObjectMethod cls mth [ JObject sqlc
                                   , JObject rdd
                                   , JObject col1
                                   , JObject col2
                                   ]


data RegexTokenizer

newTokenizer :: Text -> Text -> IO (J RegexTokenizer)
newTokenizer icol ocol = do
  cls <- findClass "org/apache/spark/ml/feature/RegexTokenizer"
  tok0 <- newObject cls "()V" []
  let patt = "\\p{L}+" :: Text
  let gaps = False
  let jgaps = if gaps then 1 else 0
  jpatt <- reflect patt
  jicol <- reflect icol
  jocol <- reflect ocol
  helper <- findClass "Helper"
  setuptok <- getStaticMethodID helper "setupTokenizer" "(Lorg/apache/spark/ml/feature/RegexTokenizer;Ljava/lang/String;Ljava/lang/String;ZLjava/lang/String;)Lorg/apache/spark/ml/feature/RegexTokenizer;"
  fmap unsafeCast $
    callStaticObjectMethod helper setuptok [ JObject tok0
                                           , JObject jicol
                                           , JObject jocol
                                           , JBoolean jgaps
                                           , JObject jpatt
                                           ]

tokenize :: J RegexTokenizer -> J DataFrame -> IO (J DataFrame)
tokenize tok df = do
  cls <- findClass "org/apache/spark/ml/feature/RegexTokenizer"
  mth <- getMethodID cls "transform" "(Lorg/apache/spark/sql/DataFrame;)Lorg/apache/spark/sql/DataFrame;"
  fmap unsafeCast $
    callObjectMethod tok mth [JObject df]

data StopWordsRemover

newStopWordsRemover :: [Text] -> Text -> Text -> IO (J StopWordsRemover)
newStopWordsRemover stopwords icol ocol = do
  cls <- findClass "org/apache/spark/ml/feature/StopWordsRemover"
  swr0 <- newObject cls "()V" []
  setSw <- getMethodID cls "setStopWords" "([Ljava/lang/String;)Lorg/apache/spark/ml/feature/StopWordsRemover;"
  jstopwords <- reflect stopwords
  swr1 <- callObjectMethod swr0 setSw [JObject jstopwords]
  setCS <- getMethodID cls "setCaseSensitive" "(Z)Lorg/apache/spark/ml/feature/StopWordsRemover;"
  swr2 <- callObjectMethod swr1 setCS [JBoolean 0]
  seticol <- getMethodID cls "setInputCol" "(Ljava/lang/String;)Lorg/apache/spark/ml/feature/StopWordsRemover;"
  setocol <- getMethodID cls "setOutputCol" "(Ljava/lang/String;)Lorg/apache/spark/ml/feature/StopWordsRemover;"
  jicol <- reflect icol
  jocol <- reflect ocol
  swr3 <- callObjectMethod swr2 seticol [JObject jicol]
  fmap unsafeCast $
    callObjectMethod swr3 setocol [JObject jocol]


removeStopWords :: J StopWordsRemover -> J DataFrame -> IO (J DataFrame)
removeStopWords sw df = do
  cls <- findClass "org/apache/spark/ml/feature/StopWordsRemover"
  mth <- getMethodID cls "transform" "(Lorg/apache/spark/sql/DataFrame;)Lorg/apache/spark/sql/DataFrame;"
  fmap unsafeCast $ callObjectMethod sw mth [JObject df]

data CountVectorizer

newCountVectorizer :: Int32 -> Text -> Text -> IO (J CountVectorizer)
newCountVectorizer vocSize icol ocol = do
  cls <- findClass "org/apache/spark/ml/feature/CountVectorizer"
  cv  <- newObject cls "()V" []
  setInpc <- getMethodID cls "setInputCol" "(Ljava/lang/String;)Lorg/apache/spark/ml/feature/CountVectorizer;"
  jfiltered <- reflect icol
  cv' <- callObjectMethod cv setInpc [JObject jfiltered]
  setOutc <- getMethodID cls "setOutputCol" "(Ljava/lang/String;)Lorg/apache/spark/ml/feature/CountVectorizer;"
  jfeatures <- reflect ocol
  cv'' <- callObjectMethod cv' setOutc [JObject jfeatures]
  setVocSize <- getMethodID cls "setVocabSize" "(I)Lorg/apache/spark/ml/feature/CountVectorizer;"
  fmap unsafeCast $ callObjectMethod cv'' setVocSize [JInt vocSize]


data CountVectorizerModel

fitCV :: J CountVectorizer -> J DataFrame -> IO (J CountVectorizerModel)
fitCV cv df = do
  cls <- findClass "org/apache/spark/ml/feature/CountVectorizer"
  mth <- getMethodID cls "fit" "(Lorg/apache/spark/sql/DataFrame;)Lorg/apache/spark/ml/feature/CountVectorizerModel;"
  fmap unsafeCast $ callObjectMethod cv mth [JObject df]

data SparkVector

toTokenCounts :: J CountVectorizerModel -> J DataFrame -> Text -> Text -> IO (J (PairRDD CLong SparkVector))
toTokenCounts cvModel df col1 col2 = do
  cls <- findClass "org/apache/spark/ml/feature/CountVectorizerModel"
  mth <- getMethodID cls "transform" "(Lorg/apache/spark/sql/DataFrame;)Lorg/apache/spark/sql/DataFrame;"
  df' <- callObjectMethod cvModel mth [JObject df]

  helper <- findClass "Helper"
  fromDF <- getStaticMethodID helper "fromDF" "(Lorg/apache/spark/sql/DataFrame;Ljava/lang/String;Ljava/lang/String;)Lorg/apache/spark/api/java/JavaRDD;"
  fromRows <- getStaticMethodID helper "fromRows" "(Lorg/apache/spark/api/java/JavaRDD;)Lorg/apache/spark/api/java/JavaPairRDD;"
  jcol1 <- reflect col1
  jcol2 <- reflect col2
  rdd <- callStaticObjectMethod helper fromDF [JObject df', JObject jcol1, JObject jcol2]
  fmap unsafeCast $ callStaticObjectMethod helper fromRows [JObject rdd]


data LDA

newLDA :: Double                               -- ^ fraction of documents
       -> Int32                                -- ^ number of topics
       -> Int32                                -- ^ maximum number of iterations
       -> IO (J LDA)
newLDA frac numTopics maxIterations = do
  cls <- findClass "org/apache/spark/mllib/clustering/LDA"
  lda <- newObject cls "()V" []

  opti_cls <- findClass "org/apache/spark/mllib/clustering/OnlineLDAOptimizer"
  opti <- newObject opti_cls "()V" []
  setMiniBatch <- getMethodID opti_cls "setMiniBatchFraction" "(D)Lorg/apache/spark/mllib/clustering/OnlineLDAOptimizer;"
  opti' <- callObjectMethod opti setMiniBatch [JDouble frac]

  setOpti <- getMethodID cls "setOptimizer" "(Lorg/apache/spark/mllib/clustering/LDAOptimizer;)Lorg/apache/spark/mllib/clustering/LDA;"
  lda' <- callObjectMethod lda setOpti [JObject opti']

  setK <- getMethodID cls "setK" "(I)Lorg/apache/spark/mllib/clustering/LDA;"
  lda'' <- callObjectMethod lda' setK [JInt numTopics]

  setMaxIter <- getMethodID cls "setMaxIterations" "(I)Lorg/apache/spark/mllib/clustering/LDA;"
  lda''' <- callObjectMethod lda'' setMaxIter [JInt maxIterations]

  setDocConc <- getMethodID cls "setDocConcentration" "(D)Lorg/apache/spark/mllib/clustering/LDA;"
  lda'''' <- callObjectMethod lda''' setDocConc [JDouble $ negate 1]

  setTopicConc <- getMethodID cls "setTopicConcentration" "(D)Lorg/apache/spark/mllib/clustering/LDA;"
  lda''''' <- callObjectMethod lda'''' setTopicConc [JDouble $ negate 1]

  return (unsafeCast lda''''')



data LDAModel

runLDA :: J LDA -> J (PairRDD CLong SparkVector) -> IO (J LDAModel)
runLDA lda rdd = do
  cls <- findClass "Helper"
  run <- getStaticMethodID cls "runLDA" "(Lorg/apache/spark/mllib/clustering/LDA;Lorg/apache/spark/api/java/JavaPairRDD;)Lorg/apache/spark/mllib/clustering/LDAModel;"
  fmap unsafeCast $
    callStaticObjectMethod cls run [JObject lda, JObject rdd]

describeResults :: J LDAModel -> J CountVectorizerModel -> Int32 -> IO ()
describeResults lm cvm maxTerms = do
  cls <- findClass "Helper"
  mth <- getStaticMethodID cls "describeResults" "(Lorg/apache/spark/mllib/clustering/LDAModel;Lorg/apache/spark/ml/feature/CountVectorizerModel;I)V"
  callStaticVoidMethod cls mth [JObject lm, JObject cvm, JInt maxTerms]


selectDF :: J DataFrame -> [Text] -> IO (J DataFrame)
selectDF _ [] = error "selectDF: not enough arguments."
selectDF df (col:cols) = do
  cls <- findClass "org/apache/spark/sql/DataFrame"
  mth <- getMethodID cls "select" "(Ljava/lang/String;[Ljava/lang/String;)Lorg/apache/spark/sql/DataFrame;"
  jcol <- reflect col
  jcols <- reflect cols
  fmap unsafeCast $
    callObjectMethod df mth [JObject jcol, JObject jcols]

debugDF :: J DataFrame -> IO ()
debugDF df = do
  cls <- findClass "org/apache/spark/sql/DataFrame"
  mth <- getMethodID cls "show" "()V"
  callVoidMethod df mth []
