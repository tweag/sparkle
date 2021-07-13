{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StaticPointers #-}

module Main where

import Control.Distributed.Closure
import Control.Distributed.Spark as RDD
import Control.Monad
import Data.IORef
import Data.Maybe
-- import qualified Data.Text as Text
-- import Data.Text (Text)
import System.Environment
import Text.Read


main :: IO ()
main = forwardUnhandledExceptionsToSpark $ do
    conf <- newSparkConf "Memory memery"
    confSet conf "spark.hadoop.fs.s3a.aws.credentials.provider"
                 "org.apache.hadoop.fs.s3a.AnonymousAWSCredentialsProvider"
    -- NOTE: it would be ideal if we could just set the driver memory here
    -- by dynamically modifying the spark config, but when run in local mode,
    -- you have to set it through the `spark-submit` CLI
    sc   <- getOrCreateSparkContext conf
    -- Figure out how many references we want to create 
    numRefs <- fromMaybe 100 . (readMaybe <=< listToMaybe) <$> getArgs
    print numRefs
    -- This S3 bucket is located in US East.
    rdd  <- textFile sc "s3a://tweag-sparkle/lorem-ipsum.txt"
    -- Create an ioref to hold on to all the references we create
    ior <- newIORef []
    forM_ [0..numRefs:: Int] $ \_ -> do
      rdd' <- RDD.map (closure $ static (<> "hello")) rdd
      modifyIORef ior (rdd' :)
    --
    len  <- RDD.count rdd 
    putStrLn $ show len ++ " lines total."
    refs <- readIORef ior
    putStrLn $ "ref list length: " ++ show (Prelude.length refs)
