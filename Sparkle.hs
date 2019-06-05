module Main where

import Codec.Archive.Zip
import Data.Text (pack, strip, unpack)
import Data.List (isInfixOf)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as LBS
import Paths_sparkle
import System.Environment (getArgs)
import System.Exit (ExitCode(..))
import System.FilePath ((</>), (<.>), takeBaseName, takeFileName)
import System.Info (os)
import System.IO (hPutStrLn, stderr)
import System.IO.Temp (withSystemTempDirectory)
import System.Posix.Files (createSymbolicLink)
import System.Process
  ( CreateProcess(..)
  , proc
  , readProcess
  , waitForProcess
  , withCreateProcess
  )
import Text.Regex.TDFA

doPackage :: FilePath -> IO ()
doPackage cmd = do
    dir <- getDataDir
    jarbytes <- LBS.readFile (dir </> "build/libs/sparkle.jar")
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
    libentries0 <- mapM mkEntry libs
    libentries <-
      if os == "darwin" then return libentries0
      else do
        libhsapp <- makeHsTopLibrary cmdpath libs
        return $ toEntry "libhsapp.so" 0 libhsapp : libentries0
    cmdentry <- toEntry "hsapp" 0 <$> LBS.readFile cmdpath
    let appzip =
          toEntry "sparkle-app.zip" 0 $
          fromArchive $
          foldr addEntryToArchive emptyArchive (cmdentry : libentries)
        newjarbytes = fromArchive $ addEntryToArchive appzip (toArchive jarbytes)
    LBS.writeFile ("." </> takeBaseName cmd <.> "jar") newjarbytes
  where
    mkEntry file = toEntry (takeFileName file) 0 <$> LBS.readFile file

-- We make a library which depends on all the libraries that go into the jar.
-- This removes the need to fiddle with the rpaths of the various libraries
-- and the application executable.
makeHsTopLibrary :: FilePath -> [FilePath] -> IO LBS.ByteString
makeHsTopLibrary hsapp libs = withSystemTempDirectory "libhsapp" $ \d -> do
    let f = d </> "libhsapp.so"
    createSymbolicLink hsapp (d </> "hsapp")
    -- Changing the directory is necessary for gcc to link hsapp with a
    -- relative path. "-L d -l:hsapp" doesn't work in centos 6 where the
    -- path to hsapp in the output library ends up being absolute.
    --
    -- --no-as-needed is necessary for linking in some systems. Otherwise
    -- the output binary would be missing DT_NEEDED entries. See #149.
    callProcessCwd d "gcc" $
      [ "-shared", "-Wl,-z,origin", "-Wl,-rpath=$ORIGIN", "-Wl,--no-as-needed"
      , "hsapp"
      , "-o", f] ++ libs
    LBS.fromStrict <$> BS.readFile f

-- This is a variant of 'callProcess' which takes a working directory.
callProcessCwd :: FilePath -> FilePath -> [String] -> IO ()
callProcessCwd wd cmd args = do
    exit_code <- withCreateProcess
                   (proc cmd args)
                     { delegate_ctlc = True
                     , cwd = Just wd
                     } $ \_ _ _ p ->
                   waitForProcess p
    case exit_code of
      ExitSuccess   -> return ()
      ExitFailure r -> error $ "callProcessCwd: " ++ show (cmd, args, r)

main :: IO ()
main = do
    argv <- getArgs
    case argv of
      ["package", cmd] -> doPackage cmd
      _ -> fail "Usage: sparkle package <command>"
