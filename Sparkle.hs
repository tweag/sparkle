module Main where

import Codec.Archive.Zip
import Data.Text (pack, strip, unpack)
import Data.List (isInfixOf)
import qualified Data.ByteString.Lazy as BS
import Paths_sparkle
import System.Environment (getArgs)
import System.FilePath ((</>), (<.>), takeBaseName, takeFileName)
import System.Info (os)
import System.IO (hPutStrLn, stderr)
import System.Process (readProcess)
import Text.Regex.TDFA

doPackage :: FilePath -> IO ()
doPackage cmd = do
    dir <- getDataDir
    jarbytes <- BS.readFile (dir </> "sparkle.jar")
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

main :: IO ()
main = do
    argv <- getArgs
    case argv of
      ["package", cmd] -> doPackage cmd
      _ -> fail "Usage: sparkle package <command>"
