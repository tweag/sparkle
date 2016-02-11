{-# LANGUAGE StaticPointers #-}

module HelloSpark where

import Control.Distributed.Closure
import Control.Distributed.Spark as RDD
import Control.Distributed.Spark.Closure
import Control.Distributed.Spark.JNI
import Data.List (isInfixOf)

f1 :: String -> Bool
f1 s = "a" `isInfixOf` s

f2 :: String -> Bool
f2 s = "b" `isInfixOf` s

sparkMain :: JVM -> IO ()
sparkMain jvm = do
    env  <- jniEnv jvm
    conf <- newSparkConf env "Hello sparkle!"
    sc   <- newSparkContext env conf
    rdd  <- textFile env sc "stack.yaml"
    as   <- RDD.filter env (closure $ static f1) rdd
    bs   <- RDD.filter env (closure $ static f2) rdd
    numAs <- RDD.count env as
    numBs <- RDD.count env bs
    putStrLn $ show numAs ++ " lines with a, "
            ++ show numBs ++ " lines with b."

foreign export ccall sparkMain :: JVM -> IO ()
