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
sparkMain env _ = do
    attach env
    conf <- newSparkConf env "Hello sparkle!"
    sc   <- newSparkContext env conf
    rdd  <- textFile env sc "stack.yaml"
    as   <- RDD.filter env (closure (static f1)) rdd
    bs   <- RDD.filter env (closure (static f2)) rdd
    numAs <- RDD.count env as
    numBs <- RDD.count env bs
    putStrLn $ show numAs ++ " lines with a, "
            ++ show numBs ++ " lines with b."

foreign export ccall "Java_io_tweag_sparkle_Sparkle_sparkMain" sparkMain
  :: JNIEnv
  -> JClass
  -> IO ()
