{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StaticPointers #-}

module Main where

import Control.Distributed.Closure
import Control.Distributed.Spark as RDD
import qualified Data.Text as Text

main :: IO ()
main = forwardUnhandledExceptionsToSpark $ do
    conf <- newSparkConf "RDD operations demo"
    sc   <- getOrCreateSparkContext conf
    rdd  <- parallelize sc $ Text.words "The quick brown fox jumps over the lazy dog"
    print =<< collect rdd
    print =<< RDD.reduce (closure $ static (\a b -> b <> " " <> a)) rdd
    print =<< collect =<< RDD.map (closure $ static Text.reverse) rdd
    print =<< RDD.take 3 rdd
    print =<< collect =<< RDD.distinct rdd
    print =<< RDD.fold (closure $ static (||)) False
          =<< RDD.map (closure $ static (=="dog")) rdd
