{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StaticPointers #-}

module Main where

import Control.Distributed.Closure
import Control.Distributed.Spark as RDD
import qualified Data.Text as Text
import Data.Text (Text)

f1 :: Text -> Bool
f1 s = "a" `Text.isInfixOf` s

f2 :: Text -> Bool
f2 s = "b" `Text.isInfixOf` s

main :: IO ()
main = do
    conf <- newSparkConf "Hello sparkle!"
    confSet conf "spark.hadoop.fs.s3a.aws.credentials.provider"
                 "org.apache.hadoop.fs.s3a.AnonymousAWSCredentialsProvider"
    sc   <- getOrCreateSparkContext conf
    -- This S3 bucket is located in US East.
    rdd  <- textFile sc "s3a://tweag-sparkle/lorem-ipsum.txt"
    xs   <- RDD.filter (closure (static f1)) rdd
    ys   <- RDD.filter (closure (static f2)) rdd
    numAs <- RDD.count xs
    numBs <- RDD.count ys
    putStrLn $ show numAs ++ " lines with a, "
            ++ show numBs ++ " lines with b."
