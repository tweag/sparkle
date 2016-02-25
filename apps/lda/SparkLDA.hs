{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Distributed.Spark

main :: IO ()
main = do
    conf <- newSparkConf "Spark Online Latent Dirichlet Allocation in Haskell!"
    sc   <- newSparkContext conf
    sqlc <- newSQLContext sc
    stopwords <- textFile sc "s3://tweag-sparkle/stopwords.txt" >>= collect
    docs <- wholeTextFiles sc "s3://tweag-sparkle/nyt/"
        >>= justValues
        >>= zipWithIndex
    docsRows <- toRows docs
    docsDF <- toDF sqlc docsRows "docId" "text"
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
