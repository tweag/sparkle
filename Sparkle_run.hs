{-# LANGUAGE LambdaCase #-}
module Sparkle_run (main, doPackage) where

import Codec.Archive.Zip
import Data.Text (pack, strip, unpack)
import Data.List (isInfixOf)
import qualified Data.ByteString.Lazy as BS
import System.Environment (getArgs)
import System.FilePath ((</>), (<.>), takeBaseName, takeFileName)
import System.Info (os)
import System.IO (hPutStrLn, stderr)
import System.Process (readProcess)
import Text.Regex.TDFA

doPackage :: FilePath -- ^ Path to sparkle jar
          -> FilePath -- ^ Command to run
          -> IO ()
doPackage sparklePath cmd = do
    jarbytes <- BS.readFile sparklePath
    cmdpath <- unpack . strip . pack <$> readProcess "which" [cmd] ""
    ldd <- case os of
      "darwin" -> do
        hPutStrLn
          stderr
          "WARNING: JAR not self contained on OS X (shared libraries not copied)."
        return ""
      _ -> readProcess "ldd" [cmdpath] ""
    let libs =
          filter (\x -> not $ any (`isInfixOf` x) ["libc.so", "libpthread.so"]) $
          map (!! 1) (ldd =~ " => ([[:graph:]]+) " :: [[String]])
    libentries <- mapM mkEntry libs
    cmdentry <- toEntry "hsapp" 0 <$> BS.readFile cmdpath
    let appzip =
          toEntry "sparkle-app.zip" 0 $
          fromArchive $
          foldr addEntryToArchive emptyArchive (cmdentry : libentries)
        newjarbytes = fromArchive $ addEntryToArchive appzip (toArchive jarbytes)
    BS.writeFile ("." </> takeBaseName cmd <.> "jar") newjarbytes
  where
    mkEntry file = toEntry (takeFileName file) 0 <$> BS.readFile file

-- | This is a main entry point that does not use @Paths_@ to
-- determine the path of the sparkle jar. If you would like that, you
-- should be compiling and using @Sparkle.hs@ instead which is the
-- cabal default.
main :: IO ()
main = getArgs >>= \case
  ["--sparkle-jar", jar, "package", cmd] -> doPackage jar cmd
  _ -> fail "Usage: sparkle --sparkle-jar JARPATH package <command>"
