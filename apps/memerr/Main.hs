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
import Data.Text (Text)
import Options.Applicative as Opt

-- Parser for the command line options
--
-- the -n option controls how many references to create 
-- NOTE: 200,000 is about the number we need to crash the JVM with the 
-- driver memory set to 512M
--
-- and if the --no-io-ref flag is present, we will not store references in an
-- ioref, so the GHC garbage collecter will have a chance to collect them
argsParser :: Parser (Int, Choice "useIORef")
argsParser = (,) <$> option auto (value 100 <> Opt.short 'n' <> metavar "N")
                 <*> flag (Do #useIORef) (Don't #useIORef) (Opt.long "no-io-ref")

main :: IO ()
main = forwardUnhandledExceptionsToSpark $ do
    conf <- newSparkConf "Memory memery"
    -- NOTE: it would be ideal if we could just set the driver memory here
    -- by dynamically modifying the spark config, but when run in local mode,
    -- you have to set it through the `spark-submit` CLI
    sc   <- getOrCreateSparkContext conf
    (numRefs, useIORef) <- execParser (info argsParser fullDesc)
    putStrLn $ "# of references to be created: " ++ show numRefs
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
