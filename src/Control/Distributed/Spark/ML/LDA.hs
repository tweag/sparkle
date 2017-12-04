{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Control.Distributed.Spark.ML.LDA where

import Control.Distributed.Spark.ML.Feature.CountVectorizer
import Control.Distributed.Spark.PairRDD
import Data.Int
import Foreign.C.Types
import Language.Java

newtype LDA = LDA (J ('Class "org.apache.spark.mllib.clustering.LDA"))
instance Coercible LDA ('Class "org.apache.spark.mllib.clustering.LDA")

newtype OnlineLDAOptimizer = OnlineLDAOptimizer (J ('Class "org.apache.spark.mllib.clustering.OnlineLDAOptimizer"))
instance Coercible OnlineLDAOptimizer ('Class "org.apache.spark.mllib.clustering.OnlineLDAOptimizer")

newLDA :: Double                               -- ^ fraction of documents
       -> Int32                                -- ^ number of topics
       -> Int32                                -- ^ maximum number of iterations
       -> IO LDA
newLDA frac numTopics maxIterations = do
  lda :: LDA <- new []
  opti :: OnlineLDAOptimizer <- new []
  OnlineLDAOptimizer opti' <- call opti "setMiniBatchFraction" [JDouble frac]
  lda' :: LDA <- call lda "setOptimizer" [coerce (unsafeCast opti' :: J ('Iface "org.apache.spark.mllib.clustering.LDAOptimizer"))]
  lda'' :: LDA <- call lda' "setK" [JInt numTopics]
  lda''' :: LDA <- call lda'' "setMaxIterations" [JInt maxIterations]
  lda'''' :: LDA <- call lda''' "setDocConcentration" [JDouble $ negate 1]
  call lda'''' "setTopicConcentration" [JDouble $ negate 1]

newtype LDAModel = LDAModel (J ('Class "org.apache.spark.mllib.clustering.LDAModel"))
instance Coercible LDAModel ('Class "org.apache.spark.mllib.clustering.LDAModel")

runLDA :: LDA -> PairRDD CLong SparkVector -> IO LDAModel
runLDA lda rdd = callStatic "Helper" "runLDA" [coerce lda, coerce rdd]

describeResults :: LDAModel -> CountVectorizerModel -> Int32 -> IO ()
describeResults lm cvm maxTerms =
    callStatic
      "Helper"
      "describeResults"
      [coerce lm, coerce cvm, JInt maxTerms]
