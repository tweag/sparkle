{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StaticPointers #-}

module Main where

import Control.Concurrent
import Control.Exception
import Control.Distributed.Closure
import Control.Distributed.Spark as RDD


runOS :: forall a. IO a -> IO a
runOS m = do
    mv <- newEmptyMVar :: IO (MVar (Either SomeException a))
    forkOS (try m >>= putMVar mv)
    takeMVar mv >>= either throw return

main :: IO ()
main = runOS $ do
    conf <- newSparkConf "osthreads sparkle"
    sc   <- getOrCreateSparkContext conf
    rdd  <- RDD.parallelize sc [1..10:: Double]
    d  <- RDD.reduce (closure $ static (+)) rdd
    putStrLn $ "total sum: " ++ show d
