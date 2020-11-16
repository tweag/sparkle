{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE UndecidableInstances #-}

module Control.Distributed.Spark.ML.LDA where

import Control.Distributed.Spark.ML.Feature.CountVectorizer
import Control.Distributed.Spark.PairRDD
import Data.Int
import Foreign.C.Types
import Language.Java

newtype LDA = LDA (J ('Class "org.apache.spark.mllib.clustering.LDA"))
  deriving Coercible

newtype OnlineLDAOptimizer = OnlineLDAOptimizer (J ('Class "org.apache.spark.mllib.clustering.OnlineLDAOptimizer"))
  deriving Coercible

newLDA :: Double                               -- ^ fraction of documents
       -> Int32                                -- ^ number of topics
       -> Int32                                -- ^ maximum number of iterations
       -> IO LDA
newLDA frac numTopics maxIterations = do
  lda :: LDA <- new
  opti :: OnlineLDAOptimizer <- new
  OnlineLDAOptimizer opti' <- call opti "setMiniBatchFraction" frac
  lda' :: LDA <- call lda "setOptimizer" (unsafeCast opti' :: J ('Iface "org.apache.spark.mllib.clustering.LDAOptimizer"))
  lda'' :: LDA <- call lda' "setK" numTopics
  lda''' :: LDA <- call lda'' "setMaxIterations" maxIterations
  lda'''' :: LDA <- call lda''' "setDocConcentration" (negate 1 :: Double)
  call lda'''' "setTopicConcentration" (negate 1 :: Double)

newtype LDAModel = LDAModel (J ('Class "org.apache.spark.mllib.clustering.LDAModel"))
  deriving Coercible

runLDA :: LDA -> PairRDD CLong SparkVector -> IO LDAModel
runLDA = callStatic "Helper" "runLDA"

describeResults :: LDAModel -> CountVectorizerModel -> Int32 -> IO ()
describeResults lm cvm maxTerms =
    callStatic
      "Helper"
      "describeResults"
      lm cvm maxTerms
