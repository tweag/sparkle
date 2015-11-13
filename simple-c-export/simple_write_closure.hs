import Data.Binary
import Simple
import System.Environment

import qualified Data.ByteString.Lazy as LBS


fSerialized :: LBS.ByteString
fSerialized = encode fClosure

main :: IO ()
main = getArgs >>= \as -> case as of
    [filename, arg] -> do
        LBS.writeFile filename fSerialized
        LBS.writeFile ("arg_" ++ filename) (encode (read arg :: Int))
    _               -> error "You must provide a filename"
