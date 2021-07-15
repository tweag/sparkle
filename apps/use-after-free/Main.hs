{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StaticPointers #-}
{-# LANGUAGE TypeApplications #-}

-- | A short program that illustrates the dangers of manual memory management
-- inherent to using inline-java (and by extension, sparkle). In this program,
-- we deallocate a reference to an RDD, allocate a new reference, then try to
-- reference the old one. This will lead to some sort of error (explained more
-- in readme).

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
    -- deallocate reference
    deleteLocalRef rdd'
    -- allocate new reference
    rdd'' <- RDD.map (closure $ static id) rdd
    -- try to do something to rdd referenced by deallocated reference
    n     <- RDD.count rdd'
    m     <- RDD.count rdd''
    putStrLn $ "new ref length: " ++ show m
    putStrLn $ "old ref length: " ++ show n
