{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StaticPointers #-}

module Main where

import Control.Distributed.Closure
import Control.Distributed.Spark as RDD
import Data.Monoid
import qualified Data.Text as Text

main :: IO ()
main = do
    conf <- newSparkConf "RDD operations demo"
    sc   <- newSparkContext conf
    rdd  <- parallelize sc $ Text.words "The quick brown fox jumps over the lazy dog"
    print =<< collect rdd
    print =<< RDD.reduce (closure $ static (\a b -> b <> " " <> a)) rdd
    print =<< collect =<< RDD.map (closure $ static Text.reverse) rdd
    print =<< RDD.take rdd 3
    print =<< collect =<< RDD.distinct rdd
    print =<< RDD.fold (closure $ static (||)) False
          =<< RDD.map (closure $ static (=="dog")) rdd
