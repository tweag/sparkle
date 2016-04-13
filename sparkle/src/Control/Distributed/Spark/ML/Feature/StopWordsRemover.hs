{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Control.Distributed.Spark.ML.Feature.StopWordsRemover where

import Control.Distributed.Spark.SQL.DataFrame
import Data.Text (Text)
import Foreign.JNI
import Language.Java

newtype StopWordsRemover = StopWordsRemover (J ('Class "org.apache.spark.ml.feature.StopWordsRemover"))
instance Coercible StopWordsRemover ('Class "org.apache.spark.ml.feature.StopWordsRemover")

newStopWordsRemover :: [Text] -> Text -> Text -> IO StopWordsRemover
newStopWordsRemover stopwords icol ocol = do
  jstopwords <- reflect stopwords
  jicol <- reflect icol
  jocol <- reflect ocol
  swr0 :: StopWordsRemover <- new []
  swr1 :: StopWordsRemover <- call swr0 "setStopWords" [coerce jstopwords]
  swr2 :: StopWordsRemover <- call swr1 "setCaseSensitive" [JBoolean 0]
  swr3 :: StopWordsRemover <- call swr2 "setInputCol" [coerce jicol]
  call swr3 "setOutputCol" [coerce jocol]

removeStopWords :: StopWordsRemover -> DataFrame -> IO DataFrame
removeStopWords sw df = call sw "transform" [coerce df]
