{-# LANGUAGE OverloadedStrings #-}

module SparkLDA where

import Control.Distributed.Spark
import qualified Data.Text as Text
import qualified Data.Text.IO as Text
import Data.Text (Text)
import Foreign.Java

sparkMain :: JNIEnv -> JClass -> IO ()
sparkMain envi _ = do
    env <- attach envi
    stopwords <- getStopwords
    conf <- newSparkConf env "Spark Online Latent Dirichlet Allocation in Haskell!"
    sc   <- newSparkContext env conf
    sqlc <- newSQLContext env sc
    docs <- wholeTextFiles env sc "nyt/"
        >>= justValues env
        >>= zipWithIndex env
    docsRows <- toRows env docs
    docsDF <- toDF env sqlc docsRows "docId" "text"
    tok  <- newTokenizer env "text" "words"
    tokenizedDF <- tokenize env tok docsDF
    swr  <- newStopWordsRemover env stopwords "words" "filtered"
    filteredDF <- removeStopWords env swr tokenizedDF
    cv   <- newCountVectorizer env vocabSize "filtered" "features"
    cvModel <- fitCV env cv filteredDF
    countVectors <- toTokenCounts env cvModel filteredDF "docId" "features"
    lda  <- newLDA env miniBatchFraction numTopics maxIterations
    ldamodel  <- runLDA env lda countVectors
    describeResults env ldamodel cvModel maxTermsPerTopic

    where numTopics         = 10
          miniBatchFraction = 1
          vocabSize         = 600
          maxTermsPerTopic  = 10
          maxIterations     = 50

getStopwords :: IO [Text]
getStopwords = fmap Text.lines (Text.readFile "stopwords.txt")

foreign export ccall "Java_io_tweag_sparkle_Sparkle_sparkMain" sparkMain
  :: JNIEnv
  -> JClass
  -> IO ()
