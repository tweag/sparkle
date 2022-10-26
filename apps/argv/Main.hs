module Main where

import System.Environment (getArgs, getProgName)
import Control.Distributed.Spark (forwardUnhandledExceptionsToSpark)
import Data.List (intercalate)

main :: IO ()
main = forwardUnhandledExceptionsToSpark $ do
    putStrLn "Sparkle passes command line arguments correctly: "
    args <- getArgs
    progName <- getProgName
    putStrLn $ "Program name: " ++ progName
    putStrLn $ "Number of args: " ++ show (length args)
    putStrLn $ "Args: " ++ intercalate " " args
