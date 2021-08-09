{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE StaticPointers #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedLabels #-}
{-# LANGUAGE LinearTypes #-}
{-# LANGUAGE QualifiedDo #-}

module Main where

import qualified Control.Distributed.Spark as Spark
import Control.Distributed.Spark.Safe.RDD
import Control.Distributed.Spark.Safe.Context
import Control.Distributed.Spark.Safe.Closure

import qualified Prelude 
import Prelude.Linear as PL
import Control.Functor.Linear
import qualified Data.Functor.Linear as D
import qualified Unsafe.Linear as Unsafe
-- import System.IO.Linear (fromSystemIO)
import Data.Unrestricted.Linear ()
import Control.Monad.IO.Class.Linear
import qualified System.IO.Linear as LIO

-- import qualified Data.ByteString as B
import qualified Data.Text as T
import Data.Choice 
import Data.Foldable
-- import Data.Int
import qualified Options.Applicative as Opt
import Options.Applicative (helper, help, info, fullDesc, Parser, flag, optional, auto, value, metavar)

import Foreign.JNI.Safe as S
import Foreign.JNI.Types.Safe as S
{-
import Language.Java.Safe
import Language.Java.Inline.Safe
import qualified Language.Java.Unsafe as JUnsafe
-}

toLIO = LIO.fromSystemIOU

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
main = Spark.forwardUnhandledExceptionsToSpark $ do
  LIO.withLinearIO $ Control.Functor.Linear.do
    conf <- newSparkConf "Memory memery"
    -- NOTE: it would be ideal if we could just set the driver memory here
    -- by dynamically modifying the spark config, but when run in local mode,
    -- you have to set it through the `spark-submit` CLI
    Ur sc   <- Unsafe.toLinear Ur <$> getOrCreateSparkContext conf
    Ur Options{..} <- toLIO $ Opt.execParser (info (helper Opt.<*> argsParser) fullDesc)
    Ur _ <- toLIO $ putStrLn $ "# of references to be created: " ++ show numRefs
    Ur _ <- toLIO $ putStrLn $ "Input length: " ++ show inputLength
    Ur _ <- toLIO $ putStrLn $ "Input width: " ++ show inputWidth
    -- Try other type of contents
    -- rdd  <- parallelize sc $ replicate inputLength $ B.replicate inputWidth (toEnum 0)
    rdd <- parallelize sc $ replicate inputLength $ T.replicate inputWidth (T.singleton '0')
    -- rdd  <- parallelize sc $ replicate inputLength $ (0 :: Int32)
    -- Perform the main loop, optionally retaining the references to the rdd
    -- look at marshalling of bytestrings and collect
    rdd' <- if toBool deleteRefs 
      then foldM (\rdd' (Ur _) -> collect rdd' >>= \(Ur elts) -> parallelize sc elts) rdd (Prelude.fmap Ur [0..numRefs])
      else pure rdd
      -- else foldM (\rdd' _ -> collect rdd' >>= \(Ur elts) -> parallelize sc elts) rdd [0..numRefs]
    --
    Ur n <- count rdd'
    toLIO $ putStrLn $ "RDD size: " ++ show n
