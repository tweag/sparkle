{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE StaticPointers #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedLabels #-}

module Main where

import Control.Distributed.Spark as RDD
import Control.Monad
import Data.Choice 
import qualified Data.ByteString as B
import Options.Applicative as Opt

-- Parser for the command line options

data Options = Options
  { retainRefs  :: Choice "retainRefs"
  , numRefs     :: Int
  , inputLength :: Int
  , inputWidth  :: Int
  }

nHelp :: String
nHelp = "How many copies of the input to create (default: 1500)"

lHelp :: String
lHelp = "Length (number of lines) of input text (default: 370)"

wHelp :: String 
wHelp = "Width of each line of input text (default: 1000)"

noRetainHelp :: String
noRetainHelp = unwords ["if the --no-retain flag is present, we will still perform the specified"
                       ,"number of RDD operations, but the Haskell side will not retain any references"
                       ,"to the resulting RDDs"]

argsParser :: Parser Options
argsParser = Options 
                 <$> flag (Do #retainRefs) (Don't #retainRefs) (Opt.long "no-retain" <> help noRetainHelp)
                 <*> option auto (value 1500 <> Opt.short 'n' <> metavar "N" <> help nHelp)
                 <*> option auto (value 370 <> Opt.short 'l' <> metavar "L" <> help lHelp)
                 <*> option auto (value 1000 <> Opt.short 'w' <> metavar "W" <> help wHelp)

main :: IO ()
main = forwardUnhandledExceptionsToSpark $ do
    conf <- newSparkConf "Memory memery"
    -- NOTE: it would be ideal if we could just set the driver memory here
    -- by dynamically modifying the spark config, but when run in local mode,
    -- you have to set it through the `spark-submit` CLI
    sc   <- getOrCreateSparkContext conf
    Options{..} <- execParser (info (helper <*> argsParser) fullDesc)
    putStrLn $ "# of references to be created: " ++ show numRefs
    putStrLn $ "Input length: " ++ show inputLength
    putStrLn $ "Input width: " ++ show inputWidth
    rdd  <- parallelize sc $ replicate inputLength $ B.replicate inputWidth (toEnum 0)
    -- Perform the main loop, optionally retaining the references to the rdd
    refs <- if toBool retainRefs 
      then replicateM numRefs $ collect rdd
      else (replicateM_ numRefs $ collect rdd) *> pure [[]]
    --
    putStrLn $ "Ref list length: " ++ show (Prelude.length refs)
    putStrLn $ "Total # elements: " ++ show (sum (fmap Prelude.length refs))
