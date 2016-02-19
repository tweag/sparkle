{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StaticPointers #-}

module HelloSpark where

import Control.Distributed.Closure
import Control.Distributed.Spark as RDD
import Foreign.Java
import qualified Data.Text as Text
import Data.Text (Text)

f1 :: Text -> Bool
f1 s = "a" `Text.isInfixOf` s

f2 :: Text -> Bool
f2 s = "b" `Text.isInfixOf` s

sparkMain :: JNIEnv -> JClass -> IO ()
sparkMain _ _ = do
    conf <- newSparkConf "Hello sparkle!"
    sc   <- newSparkContext conf
    rdd  <- textFile sc "stack.yaml"
    as   <- RDD.filter (closure (static f1)) rdd
    bs   <- RDD.filter (closure (static f2)) rdd
    numAs <- RDD.count as
    numBs <- RDD.count bs
    putStrLn $ show numAs ++ " lines with a, "
            ++ show numBs ++ " lines with b."

foreign export ccall "Java_io_tweag_sparkle_Sparkle_sparkMain" sparkMain
  :: JNIEnv
  -> JClass
  -> IO ()
