{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Distributed.Spark
import qualified Control.Distributed.Spark.SQL.Dataset as Dataset
import qualified Control.Distributed.Spark.SQL.DataType as DataType
import qualified Control.Distributed.Spark.SQL.Metadata as Metadata
import qualified Control.Distributed.Spark.SQL.StructField as StructField
import qualified Control.Distributed.Spark.SQL.StructType as StructType

main :: IO ()
main = do
    conf <- newSparkConf "Spark Online Latent Dirichlet Allocation in Haskell!"
    confSet conf "spark.hadoop.fs.s3n.awsAccessKeyId" "AKIAIKSKH5DRWT5OPMSA"
    confSet conf "spark.hadoop.fs.s3n.awsSecretAccessKey" "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"
    ss <- builder >>= (`config` conf) >>= getOrCreate
    sc <- sparkContext ss
    -- This S3 bucket is located in US East.
    stopwords <- textFile sc "s3n://tweag-sparkle/stopwords.txt" >>= collect
    docs <- wholeTextFiles sc "s3n://tweag-sparkle/nyt/"
        >>= justValues
        >>= zipWithIndex
    docsRows <- toRows docs

    e <- Metadata.empty
    longType <- DataType.longType
    stringType <- DataType.stringType
    sf0 <- StructField.new "docId" longType True e
    sf1 <- StructField.new "text" stringType True e
    st <- StructType.new [sf0, sf1]
    docsDF <- Dataset.createDataFrame ss docsRows st
    tok  <- newTokenizer "text" "words"
    tokenizedDF <- tokenize tok docsDF
    swr  <- newStopWordsRemover stopwords "words" "filtered"
    filteredDF <- removeStopWords swr tokenizedDF
    cv   <- newCountVectorizer vocabSize "filtered" "features"
    cvModel <- fitCV cv filteredDF
    countVectors <- toTokenCounts cvModel filteredDF "docId" "features"
    lda  <- newLDA miniBatchFraction numTopics maxIterations
    ldamodel  <- runLDA lda countVectors
    describeResults ldamodel cvModel maxTermsPerTopic

    where numTopics         = 10
          miniBatchFraction = 1
          vocabSize         = 600
          maxTermsPerTopic  = 10
          maxIterations     = 50
