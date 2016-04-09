{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

module Control.Distributed.Spark.ML.LDA where

import Control.Distributed.Spark.ML.Feature.CountVectorizer
import Control.Distributed.Spark.PairRDD
import Data.Int
import Foreign.C.Types
import Foreign.JNI
import Language.Java

newtype LDA = LDA (J ('Class "org.apache.spark.mllib.clustering.LDA"))
instance Coercible LDA ('Class "org.apache.spark.mllib.clustering.LDA")

newLDA :: Double                               -- ^ fraction of documents
       -> Int32                                -- ^ number of topics
       -> Int32                                -- ^ maximum number of iterations
       -> IO LDA
newLDA frac numTopics maxIterations = do
  cls <- findClass "org/apache/spark/mllib/clustering/LDA"
  lda <- newObject cls "()V" []

  opti_cls <- findClass "org/apache/spark/mllib/clustering/OnlineLDAOptimizer"
  opti <- newObject opti_cls "()V" []
  setMiniBatch <- getMethodID opti_cls "setMiniBatchFraction" "(D)Lorg/apache/spark/mllib/clustering/OnlineLDAOptimizer;"
  opti' <- callObjectMethod opti setMiniBatch [JDouble frac]

  setOpti <- getMethodID cls "setOptimizer" "(Lorg/apache/spark/mllib/clustering/LDAOptimizer;)Lorg/apache/spark/mllib/clustering/LDA;"
  lda' <- callObjectMethod lda setOpti [coerce opti']

  setK <- getMethodID cls "setK" "(I)Lorg/apache/spark/mllib/clustering/LDA;"
  lda'' <- callObjectMethod lda' setK [JInt numTopics]

  setMaxIter <- getMethodID cls "setMaxIterations" "(I)Lorg/apache/spark/mllib/clustering/LDA;"
  lda''' <- callObjectMethod lda'' setMaxIter [JInt maxIterations]

  setDocConc <- getMethodID cls "setDocConcentration" "(D)Lorg/apache/spark/mllib/clustering/LDA;"
  lda'''' <- callObjectMethod lda''' setDocConc [JDouble $ negate 1]

  setTopicConc <- getMethodID cls "setTopicConcentration" "(D)Lorg/apache/spark/mllib/clustering/LDA;"
  lda''''' <- unsafeUncoerce . coerce <$> callObjectMethod lda'''' setTopicConc [JDouble $ negate 1]

  return lda'''''

newtype LDAModel = LDAModel (J ('Class "org.apache.spark.mllib.clustering.LDAModel"))
instance Coercible LDAModel ('Class "org.apache.spark.mllib.clustering.LDAModel")

runLDA :: LDA -> PairRDD CLong SparkVector -> IO LDAModel
runLDA lda rdd = do
  cls <- findClass "Helper"
  run <- getStaticMethodID cls "runLDA" "(Lorg/apache/spark/mllib/clustering/LDA;Lorg/apache/spark/api/java/JavaPairRDD;)Lorg/apache/spark/mllib/clustering/LDAModel;"
  unsafeUncoerce . coerce <$>
    callStaticObjectMethod cls run [coerce lda, coerce rdd]

describeResults :: LDAModel -> CountVectorizerModel -> Int32 -> IO ()
describeResults lm cvm maxTerms = do
  cls <- findClass "Helper"
  mth <- getStaticMethodID cls "describeResults" "(Lorg/apache/spark/mllib/clustering/LDAModel;Lorg/apache/spark/ml/feature/CountVectorizerModel;I)V"
  callStaticVoidMethod cls mth [coerce lm, coerce cvm, JInt maxTerms]
