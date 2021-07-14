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
import Data.Text (Text)
import Options.Applicative as Opt

-- Parser for the command line options
--
-- the -n option controls how many references to create 
-- NOTE: 200,000 is about the number we need to crash the JVM with the 
-- driver memory set to 512M
--
-- and if the --no-retain flag is present, we will hold on to the created
-- references, ensuring that the GHC RTS doesn't GC any of the references
argsParser :: Parser (Int, Choice "retainRefs")
argsParser = (,) <$> option auto (value 100 <> Opt.short 'n' <> metavar "N")
                 <*> flag (Do #retainRefs) (Don't #retainRefs) (Opt.long "no-retain")

main :: IO ()
main = forwardUnhandledExceptionsToSpark $ do
    conf <- newSparkConf "Memory memery"
    -- NOTE: it would be ideal if we could just set the driver memory here
    -- by dynamically modifying the spark config, but when run in local mode,
    -- you have to set it through the `spark-submit` CLI
    sc   <- getOrCreateSparkContext conf
    (numRefs, retainRefs) <- execParser (info argsParser fullDesc)
    putStrLn $ "# of references to be created: " ++ show numRefs
    rdd  <- parallelize sc ["yes", "no", "maybe"]
    -- Perform the main loop, optionally retaining the references to the rdd
    refs <- if toBool retainRefs 
      then replicateM numRefs $ RDD.map (closure $ static (id @Text)) rdd
      else (replicateM_ numRefs $ RDD.map (closure $ static (id @Text)) rdd) *> pure []
    --
    putStrLn $ "ref list length: " ++ show (Prelude.length refs)
