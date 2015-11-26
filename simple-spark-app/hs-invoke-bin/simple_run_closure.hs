import Control.Distributed.Closure
import Data.Binary
import GHC.StaticPtr
import Spark (invoke)
import System.Environment

import qualified Data.ByteString      as BS
import qualified Data.ByteString.Lazy as LBS

main :: IO ()
main = getArgs >>= \as -> case as of
    [closFilename, argFilename] -> run closFilename argFilename
    _               		    -> usage

usage :: IO ()
usage = error "Usage:\t simple_run_closure <path to serialized closure> <path to serialized argument>"

decodeInt :: BS.ByteString -> Int
decodeInt = decode . LBS.fromStrict

run :: FilePath -> FilePath -> IO ()
run closureFile argFile = do
    serializedClosure <- BS.readFile closureFile
    serializedArg     <- BS.readFile argFile

    print . decodeInt $ invoke serializedClosure serializedArg
