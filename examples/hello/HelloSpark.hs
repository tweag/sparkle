{-# LANGUAGE StaticPointers #-}

module HelloSpark where

import Control.Distributed.Closure
import Control.Distributed.Spark
import Foreign.C.Types

f :: CInt -> CInt
f x = x * 2

-- the 'Closure' type and the 'closure' function are provided by
-- the distributed-closure package, while 'static' is provided
-- by the StaticPointers extension
wrapped_f :: Closure (CInt -> CInt)
wrapped_f = closure (static f)

sparkMain :: JVM -> IO ()
sparkMain jvm = do
    env  <- jniEnv jvm
    conf <- newSparkConf env "Hello sparkle!"
    sc   <- newSparkContext env conf
    rdd  <- textFile env sc "stack.yml"
    -- rdd' <- rddmap env wrapped_f rdd
    -- res  <- collect env rdd'
    putStrLn "done"

foreign export ccall sparkMain :: JVM -> IO ()
