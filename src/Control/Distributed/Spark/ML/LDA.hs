{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE UndecidableInstances #-}

module Control.Distributed.Spark.ML.LDA where

import Control.Distributed.Spark.ML.Feature.CountVectorizer
import Control.Distributed.Spark.PairRDD
import Data.Int
import Foreign.C.Types
import Language.Java
import Language.Java.Inline

imports "org.apache.spark.mllib.clustering.LDA"
imports "org.apache.spark.mllib.clustering.OnlineLDAOptimizer"


newtype LDA = LDA (J ('Class "org.apache.spark.mllib.clustering.LDA"))
  deriving Coercible

newtype OnlineLDAOptimizer = OnlineLDAOptimizer (J ('Class "org.apache.spark.mllib.clustering.OnlineLDAOptimizer"))
  deriving Coercible

newLDA :: Double                               -- ^ fraction of documents
       -> Int32                                -- ^ number of topics
       -> Int32                                -- ^ maximum number of iterations
       -> IO LDA
newLDA frac numTopics maxIterations =
  [java|
     new LDA().setOptimizer(new OnlineLDAOptimizer().setMiniBatchFraction($frac))
              .setK($numTopics)
              .setMaxIterations($maxIterations)
              .setDocConcentration(-1)
              .setTopicConcentration(-1)
   |]

newtype LDAModel = LDAModel (J ('Class "org.apache.spark.mllib.clustering.LDAModel"))
  deriving Coercible

runLDA :: LDA -> PairRDD CLong SparkVector -> IO LDAModel
runLDA l docs = [java| $l.run($docs) |]

describeResults :: LDAModel -> CountVectorizerModel -> Int32 -> IO ()
describeResults lm cvm maxTermsPerTopic =
    [java| {
        scala.Tuple2<int[], double[]>[] topics = $lm.describeTopics($maxTermsPerTopic);
        String[] vocabArray = $cvm.vocabulary();
        System.out.println(">>> Vocabulary");
        for(String w : vocabArray)
            System.out.println("\t " + w);
        for(int i = 0; i < topics.length; i++) {
            System.out.println(">>> Topic #" + i);
            scala.Tuple2<int[], double[]> topic = topics[i];
            int numTerms = topic._1().length;
            for(int j = 0; j < numTerms; j++) {
                String term = vocabArray[topic._1()[j]];
                double weight = topic._2()[j];
                System.out.println("\t" + term + " -> " + weight);
            }
            System.out.println("-----");
        }
    } |]
