{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE UndecidableInstances #-}

module Control.Distributed.Spark.ML.Feature.CountVectorizer where

import Control.Distributed.Spark.RDD (RDD)
import Control.Distributed.Spark.PairRDD
import Control.Distributed.Spark.SQL.Dataset
import Data.Int
import Data.Text (Text)
import Foreign.C.Types
import Language.Java

newtype CountVectorizer = CountVectorizer (J ('Class "org.apache.spark.ml.feature.CountVectorizer"))
  deriving Coercible

newCountVectorizer :: Int32 -> Text -> Text -> IO CountVectorizer
newCountVectorizer vocSize icol ocol = do
  jfiltered <- reflect icol
  jfeatures <- reflect ocol
  cv :: CountVectorizer <- new
  cv' :: CountVectorizer <- call cv "setInputCol" jfiltered
  cv'' :: CountVectorizer <- call cv' "setOutputCol" jfeatures
  call cv'' "setVocabSize" vocSize

newtype CountVectorizerModel = CountVectorizerModel (J ('Class "org.apache.spark.ml.feature.CountVectorizerModel"))
  deriving Coercible

fitCV :: CountVectorizer -> DataFrame -> IO CountVectorizerModel
fitCV cv df = call cv "fit" df

newtype SparkVector = SparkVector (J ('Class "org.apache.spark.mllib.linalg.Vector"))
  deriving (Coercible, Interpretation, Reify, Reflect)

toTokenCounts :: CountVectorizerModel -> DataFrame -> Text -> Text -> IO (PairRDD CLong SparkVector)
toTokenCounts cvModel df col1 col2 = do
  jcol1 <- reflect col1
  jcol2 <- reflect col2
  df' :: DataFrame <- call cvModel "transform" df
  rdd :: RDD a <- callStatic "Helper" "fromDF" df' jcol1 jcol2
  callStatic "Helper" "fromRows" rdd
