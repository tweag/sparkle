{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StaticPointers #-}

module Main where

import Control.Distributed.Closure
import Control.Distributed.Spark as RDD
import qualified Data.Text as Text
import Data.Text (Text)
import System.Environment (getArgs)

f1 :: Text -> Bool
f1 s = "a" `Text.isInfixOf` s

f2 :: Text -> Bool
f2 s = "b" `Text.isInfixOf` s

main :: IO ()
main = do
    inputFile <- getArgs >>= \case
      [f] -> return f
      _ -> error "Must specify an input file on the command line."
    conf <- newSparkConf "Hello sparkle!"
    sc   <- getOrCreateSparkContext conf
    rdd  <- textFile sc inputFile
    xs   <- RDD.filter (closure (static f1)) rdd
    ys   <- RDD.filter (closure (static f2)) rdd
    numAs <- RDD.count xs
    numBs <- RDD.count ys
    putStrLn $ show numAs ++ " lines with a, "
            ++ show numBs ++ " lines with b."
