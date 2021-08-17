{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE StaticPointers #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedLabels #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE LinearTypes #-}
{-# LANGUAGE QualifiedDo #-}

module Main where

import qualified Control.Distributed.Spark as Spark
import Control.Distributed.Spark.Safe.RDD
import Control.Distributed.Spark.Safe.Context

import qualified Prelude  as P
import Prelude ((<>))
import Prelude.Linear as PL hiding ((<>))
import Control.Functor.Linear
import Data.Unrestricted.Linear ()
import qualified System.IO.Linear as LIO

import qualified Data.Text as T
import qualified Options.Applicative as Opt
import Options.Applicative (helper, help, info, fullDesc, Parser, auto, value, metavar)

import qualified Foreign.JNI.Types
import Foreign.JNI.Types.Safe
import Foreign.JNI.Safe as S

toLIO :: IO a %1 -> LIO.IO a
toLIO = LIO.fromSystemIO

-- Parser for the command line options

data Options = Options
  { numRefs     :: Int
  , inputLength :: Int
  , inputWidth  :: Int
  }

nHelp :: String
nHelp = "How many copies of the input to create (default: 1500)"

lHelp :: String
lHelp = "Length (number of lines) of input text (default: 370)"

wHelp :: String 
wHelp = "Width of each line of input text (default: 1000)"

argsParser :: Parser Options
argsParser = Options 
                 P.<$> Opt.option auto (value 600 <> Opt.short 'n' <> metavar "N" <> help nHelp)
                 P.<*> Opt.option auto (value 370 <> Opt.short 'l' <> metavar "L" <> help lHelp)
                 P.<*> Opt.option auto (value 1000 <> Opt.short 'w' <> metavar "W" <> help wHelp)

main :: IO ()
main = Spark.forwardUnhandledExceptionsToSpark $ do
  LIO.withLinearIO $ Control.Functor.Linear.do
    conf <- newSparkConf "Safe memory memery"
    -- NOTE: it would be ideal if we could just set the driver memory here
    -- by dynamically modifying the spark config, but when run in local mode,
    -- you have to set it through the `spark-submit` CLI
    sc <- getOrCreateSparkContext conf
    Ur Options{..} <- LIO.fromSystemIOU $ Opt.execParser (info (helper P.<*> argsParser) fullDesc)
    toLIO $ putStrLn $ "# of references to be created: " ++ show numRefs
    toLIO $ putStrLn $ "Input length: " ++ show inputLength
    toLIO $ putStrLn $ "Input width: " ++ show inputWidth
    -- Create the initial RDD with specified size
    Ur xs <- pure $ Ur $ P.replicate inputLength $ T.replicate inputWidth (T.singleton '0')
    (sc0, sc1) <- newLocalRef sc
    rdd <- parallelize sc0 xs
    -- Main loop of the program
    (rdd', sc2) <- foldM 
                     (\(rdd', sc') (Ur _) -> collect rdd' >>= 
                        \(Ur elts) -> newLocalRef sc' >>=
                          \(sc2, sc3) -> (,sc3) <$> parallelize sc2 elts) 
                     (rdd, sc1) 
                     (P.fmap Ur [0..numRefs])
    deleteLocalRef sc2
    Ur n <- count rdd'
    LIO.fromSystemIOU $ putStrLn $ "RDD size: " ++ show n
