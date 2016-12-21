module Main where

import System.Environment (getArgs, getProgName)
import Data.List (intercalate)

main :: IO ()
main = do
    putStrLn "Sparkle passes command line arguments correctly: "
    args <- getArgs
    progName <- getProgName
    putStrLn $ "Program name: " ++ progName
    putStrLn $ "Number of args: " ++ show (length args)
    putStrLn $ "Args: " ++ intercalate " " args
