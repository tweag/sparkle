import Data.Binary.Serialise.CBOR (serialise)
import Simple (fSerialized)
import System.Environment

import qualified Data.ByteString.Lazy as LBS

main :: IO ()
main = getArgs >>= \as -> case as of
    [filename, arg] -> do
        LBS.writeFile filename fSerialized
        LBS.writeFile ("arg_" ++ filename) (serialise (read arg :: Int))
    _               -> error "You must provide a filename"
