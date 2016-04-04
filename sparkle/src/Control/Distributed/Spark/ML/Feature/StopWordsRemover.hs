{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}
module Control.Distributed.Spark.ML.Feature.StopWordsRemover where

import Control.Distributed.Spark.SQL.DataFrame
import Data.Coerce
import Data.Text (Text)
import Foreign.JNI
import Language.Java

newtype StopWordsRemover = StopWordsRemover (J ('Class "org.apache.spark.ml.feature.StopWordsRemover"))

newStopWordsRemover :: [Text] -> Text -> Text -> IO StopWordsRemover
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
  coerce . unsafeCast <$>
    callObjectMethod swr3 setocol [JObject jocol]


removeStopWords :: StopWordsRemover -> DataFrame -> IO DataFrame
removeStopWords sw df = do
  cls <- findClass "org/apache/spark/ml/feature/StopWordsRemover"
  mth <- getMethodID cls "transform" "(Lorg/apache/spark/sql/DataFrame;)Lorg/apache/spark/sql/DataFrame;"
  coerce . unsafeCast <$> callObjectMethod sw mth [JObject df]
