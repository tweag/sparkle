{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StaticPointers #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedLabels #-}
{-# LANGUAGE PatternSynonyms #-}

module Main where

import Control.Distributed.Closure
import Control.Distributed.Spark as RDD
import Control.Monad
import Data.Choice 
import Data.IORef
-- import qualified Data.Text as Text
import Data.Text (Text)
import Options.Applicative as Opt

argsParser :: Parser (Int, Choice "useIORef")
argsParser = (,) <$> option auto (value 100 <> Opt.short 'n' <> metavar "N")
                 <*> flag (Do #useIORef) (Don't #useIORef) (Opt.long "no-io-ref")

main :: IO ()
main = forwardUnhandledExceptionsToSpark $ do
    conf <- newSparkConf "Memory memery"
    {-
    confSet conf "spark.hadoop.fs.s3a.aws.credentials.provider"
                 "org.apache.hadoop.fs.s3a.AnonymousAWSCredentialsProvider"
                 -}
    -- NOTE: it would be ideal if we could just set the driver memory here
    -- by dynamically modifying the spark config, but when run in local mode,
    -- you have to set it through the `spark-submit` CLI
    sc   <- getOrCreateSparkContext conf
    -- Figure out how many references we want to create and whether to use
    -- iorefs
    -- NOTE: 200,000 is about the amount the we need to get the program to crash
    (numRefs, useIORef) <- execParser (info argsParser fullDesc)
    -- numRefs <- fromMaybe 100 . (readMaybe <=< listToMaybe) <$> getArgs
    print numRefs
    rdd  <- parallelize sc ["yes", "no", "maybe"]
    -- Create an ioref to hold on to all the references we create
    ior <- newIORef []
    -- Perform the main loop, optionally using ioref to store refs to rdd
    forM_ [0 .. numRefs :: Int] $ \_ -> do
      rdd' <- RDD.map (closure $ static (id @Text)) rdd
      Control.Monad.when (toBool useIORef) $ modifyIORef ior (rdd' :)
    --
    refs <- readIORef ior
    putStrLn $ "ref list length: " ++ show (Prelude.length refs)
