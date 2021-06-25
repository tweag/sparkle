{-# LANGUAGE ForeignFunctionInterface #-}

module FFIWrapper where

import qualified Main

foreign export ccall ioTweagSparkleMain :: IO ()

ioTweagSparkleMain :: IO ()
ioTweagSparkleMain = Main.main
