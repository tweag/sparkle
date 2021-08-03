{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE UndecidableInstances #-}

module Control.Distributed.Spark.Safe.ML.Feature.StopWordsRemover where

import Control.Distributed.Spark.SQL.Dataset
import Data.Text (Text)
import Language.Java

newtype StopWordsRemover = StopWordsRemover (J ('Class "org.apache.spark.ml.feature.StopWordsRemover"))
  deriving Coercible

newStopWordsRemover :: [Text] -> Text -> Text -> IO StopWordsRemover
newStopWordsRemover stopwords icol ocol = do
  jstopwords <- reflect stopwords
  jicol <- reflect icol
  jocol <- reflect ocol
  swr0 :: StopWordsRemover <- new
  swr1 :: StopWordsRemover <- call swr0 "setStopWords" jstopwords
  swr2 :: StopWordsRemover <- call swr1 "setCaseSensitive" False
  swr3 :: StopWordsRemover <- call swr2 "setInputCol" jicol
  call swr3 "setOutputCol" jocol

removeStopWords :: StopWordsRemover -> DataFrame -> IO DataFrame
removeStopWords sw = call sw "transform"
