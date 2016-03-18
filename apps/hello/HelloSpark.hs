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
    confSet conf "spark.hadoop.fs.s3n.awsAccessKeyId" "AKIAIKSKH5DRWT5OPMSA"
    confSet conf "spark.hadoop.fs.s3n.awsSecretAccessKey" "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"
    sc   <- newSparkContext conf
    rdd  <- textFile sc "s3n://tweag-sparkle/lorem-ipsum.txt"
    as   <- RDD.filter (closure (static f1)) rdd
    bs   <- RDD.filter (closure (static f2)) rdd
    numAs <- RDD.count as
    numBs <- RDD.count bs
    putStrLn $ show numAs ++ " lines with a, "
            ++ show numBs ++ " lines with b."
