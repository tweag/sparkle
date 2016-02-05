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

sparkMain :: IO ()
sparkMain = do
    conf <- newSparkConf "Hello sparkle!"
    sc   <- newSparkContext conf
    rdd  <- parallelize sc [1..10]
    rdd' <- rddmap wrapped_f rdd
    res  <- collect rdd'
    print res

foreign export ccall sparkMain :: IO ()
