{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StaticPointers #-}
{-# LANGUAGE QualifiedDo #-}

module Main where

import qualified Control.Distributed.Spark as Spark
import Control.Distributed.Spark.Safe.RDD as RDD
import Control.Distributed.Spark.Safe.Context
-- import Control.Distributed.Spark.Closure

import qualified Prelude  as P
import Prelude.Linear as PL hiding ((<>))
import Control.Functor.Linear
import Data.Unrestricted.Linear ()
import qualified System.IO.Linear as LIO

import qualified Foreign.JNI.Types
import Foreign.JNI.Safe
import Foreign.JNI.Types.Safe

import Control.Distributed.Closure
-- import Control.Distributed.Spark as RDD
import qualified Data.Text as Text
import Data.Text (Text)


f1 :: Text -> Bool
f1 s = "a" `Text.isInfixOf` s

f2 :: Text -> Bool
f2 s = "b" `Text.isInfixOf` s

main :: IO ()
main = Spark.forwardUnhandledExceptionsToSpark $ do
  LIO.withLinearIO $ Control.Functor.Linear.do
    conf <- newSparkConf "Hello sparkle!"
    conf' <- confSet conf "spark.hadoop.fs.s3a.aws.credentials.provider"
                 "org.apache.hadoop.fs.s3a.AnonymousAWSCredentialsProvider"
    sc   <- getOrCreateSparkContext conf'
    -- This S3 bucket is located in US East.
    rdd  <- textFile sc "s3a://tweag-sparkle/lorem-ipsum.txt"
    (rdd0, rdd1) <- newLocalRef rdd
    xs   <- RDD.filter (closure (static f1)) rdd0
    ys   <- RDD.filter (closure (static f2)) rdd1
    Ur numAs <- RDD.count xs
    Ur numBs <- RDD.count ys
    LIO.fromSystemIOU $ 
      P.putStrLn $ show numAs ++ " lines with a, "
                ++ show numBs ++ " lines with b."
