{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StaticPointers #-}
{-# LANGUAGE TypeApplications #-}

module Main where

import Control.Distributed.Closure
import Control.Distributed.Spark as RDD
import Foreign.JNI
import Foreign.JNI.Types
import Data.Text (Text)

main :: IO ()
main = forwardUnhandledExceptionsToSpark $ do
    conf <- newSparkConf "Use after free"
    sc   <- getOrCreateSparkContext conf
    rdd   <- parallelize sc ["yes", "no", "maybe"]
    rdd'  <- RDD.map (closure $ static (id @Text)) rdd
    deleteLocalRef rdd'
    rdd'' <- RDD.map (closure $ static id) rdd
    n     <- RDD.count rdd'
    m     <- RDD.count rdd''
    putStrLn $ "new ref length: " ++ show m
    putStrLn $ "old ref length: " ++ show n
