{-# LANGUAGE LambdaCase #-}
module Sparkle (main) where

import Paths_sparkle
import Sparkle_run (doPackage)
import System.Environment (getArgs)
import System.FilePath ((</>))

-- | If you would like to specify path to the sparkle JAR instead of
-- letting cabal look it up, please use @Sparkle_run.hs@ instead.
main :: IO ()
main = getArgs >>= \case
  ["package", cmd] -> do
    jarPath <- (</> "sparkle.jar") <$> getDataDir
    doPackage jarPath cmd
   _ -> fail "Usage: sparkle package <command>"
