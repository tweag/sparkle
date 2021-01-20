{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE UndecidableInstances #-}

module Control.Distributed.Spark.ML.Feature.CountVectorizer where

import Control.Distributed.Spark.PairRDD
import Control.Distributed.Spark.SQL.Dataset
import Data.Int
import Data.Text (Text)
import Foreign.C.Types
import Language.Java
import Language.Java.Inline

imports "org.apache.spark.api.java.function.PairFunction"
imports "org.apache.spark.ml.feature.CountVectorizer"
imports "org.apache.spark.mllib.linalg.SparseVector"
imports "org.apache.spark.mllib.linalg.Vector"
imports "org.apache.spark.sql.Row"


newtype CountVectorizer = CountVectorizer (J ('Class "org.apache.spark.ml.feature.CountVectorizer"))
  deriving Coercible

newCountVectorizer :: Int32 -> Text -> Text -> IO CountVectorizer
newCountVectorizer vocSize icol ocol = do
  jfiltered <- reflect icol
  jfeatures <- reflect ocol
  [java|
    new CountVectorizer().setInputCol($jfiltered).setOutputCol($jfeatures).setVocabSize($vocSize)
    |]

newtype CountVectorizerModel = CountVectorizerModel (J ('Class "org.apache.spark.ml.feature.CountVectorizerModel"))
  deriving Coercible

fitCV :: CountVectorizer -> DataFrame -> IO CountVectorizerModel
fitCV cv df = [java| $cv.fit($df) |]

newtype SparkVector = SparkVector (J ('Class "org.apache.spark.mllib.linalg.Vector"))
  deriving (Coercible, Interpretation, Reify, Reflect)

toTokenCounts :: CountVectorizerModel -> DataFrame -> Text -> Text -> IO (PairRDD CLong SparkVector)
toTokenCounts cvModel df col1 col2 = do
  jcol1 <- reflect col1
  jcol2 <- reflect col2
  [java|
    $cvModel.transform($df).select($jcol1, $jcol2).toJavaRDD().mapToPair(
        new PairFunction<Row, Long, Vector>() {
            public scala.Tuple2<Long, Vector> call(Row r) {
                return new scala.Tuple2<Long, Vector>((Long) r.get(0), SparseVector.fromML((org.apache.spark.ml.linalg.SparseVector) r.get(1)).compressed());
            }
        }).cache()
   |]
