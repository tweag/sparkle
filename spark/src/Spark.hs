{-# LANGUAGE ForeignFunctionInterface #-}
module Spark where

sparkMain :: IO ()
sparkMain = putStrLn "Hello from Haskell"

foreign export ccall sparkMain :: IO ()
