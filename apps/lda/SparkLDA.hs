{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Distributed.Spark
import qualified Data.Text as Text
import qualified Data.Text.IO as Text
import Data.Text (Text)

main :: IO ()
main = do
    stopwords <- getStopwords
    conf <- newSparkConf "Spark Online Latent Dirichlet Allocation in Haskell!"
    sc   <- newSparkContext conf
    sqlc <- newSQLContext sc
    docs <- wholeTextFiles sc "nyt/"
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

getStopwords :: IO [Text]
getStopwords = fmap Text.lines (Text.readFile "stopwords.txt")
