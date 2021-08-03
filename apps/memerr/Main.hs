{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE StaticPointers #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedLabels #-}

module Main where

import Control.Distributed.Spark as RDD
import Control.Monad
-- import qualified Data.ByteString as B
import qualified Data.Text as T
import Data.Choice 
import Data.Foldable
-- import Data.Int
import Foreign.JNI
import Foreign.JNI.Types
import Options.Applicative as Opt

-- Parser for the command line options

data Options = Options
  { deleteRefs  :: Choice "deleteRefs"
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

deleteRefsHelp :: String
deleteRefsHelp = "If this flag is present, deletes unused references to old RDDS during program execution"

argsParser :: Parser Options
argsParser = Options 
                 <$> flag (Don't #deleteRefs) (Do #deleteRefs) (Opt.long "delete-refs" <> help deleteRefsHelp)
                 <*> option auto (value 600 <> Opt.short 'n' <> metavar "N" <> help nHelp)
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
    -- Try other type of contents
    -- rdd  <- parallelize sc $ replicate inputLength $ B.replicate inputWidth (toEnum 0)
    rdd <- parallelize sc $ replicate inputLength $ T.replicate inputWidth (T.singleton '0')
    -- rdd  <- parallelize sc $ replicate inputLength $ (0 :: Int32)
    -- Perform the main loop, optionally retaining the references to the rdd
    -- look at marshalling of bytestrings and collect
    rdd' <- if toBool deleteRefs 
      then foldrM (\_ rdd' -> collect rdd' >>= \elts -> parallelize sc elts <* deleteLocalRef rdd') rdd [0..numRefs]
      else foldrM (\_ -> (parallelize sc <=< collect)) rdd [0..numRefs]
    --
    n <- count rdd'
    putStrLn $ "RDD size: " ++ show n
