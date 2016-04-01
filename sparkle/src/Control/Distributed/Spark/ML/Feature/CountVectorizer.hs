{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}
module Control.Distributed.Spark.ML.Feature.CountVectorizer where

import Control.Distributed.Spark.PairRDD
import Control.Distributed.Spark.SQL.DataFrame
import Data.Coerce
import Data.Int
import Data.Text (Text)
import Foreign.C.Types
import Foreign.JNI
import Language.Java

newtype CountVectorizer = CountVectorizer (J ('Class "org.apache.spark.ml.feature.CountVectorizer"))

newCountVectorizer :: Int32 -> Text -> Text -> IO CountVectorizer
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
  coerce . unsafeCast <$> callObjectMethod cv'' setVocSize [JInt vocSize]

newtype CountVectorizerModel = CountVectorizerModel (J ('Class "org.apache.spark.ml.feature.CountVectorizerModel"))

fitCV :: CountVectorizer -> DataFrame -> IO CountVectorizerModel
fitCV cv df = do
  cls <- findClass "org/apache/spark/ml/feature/CountVectorizer"
  mth <- getMethodID cls "fit" "(Lorg/apache/spark/sql/DataFrame;)Lorg/apache/spark/ml/feature/CountVectorizerModel;"
  coerce . unsafeCast <$> callObjectMethod cv mth [JObject df]

newtype SparkVector = SparkVector (J ('Class "org.apache.spark.mllib.linalg.Vector"))

toTokenCounts :: CountVectorizerModel -> DataFrame -> Text -> Text -> IO (PairRDD CLong SparkVector)
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
  coerce . unsafeCast <$> callStaticObjectMethod helper fromRows [JObject rdd]

