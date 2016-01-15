{-# LANGUAGE ForeignFunctionInterface #-}
module Closure
  ( clos2bs
  , bs2clos
  , bs2func
  , unclosure
  , invoke
  , invokeC
  ) where

import Control.Distributed.Closure
import Data.Binary (encode, decode)
import Data.ByteString (ByteString)
import Data.ByteString.Unsafe (unsafePackCStringLen)
import Foreign.C.Types
import Foreign.Ptr

import qualified Data.ByteString.Lazy as LBS

clos2bs :: Closure (Int -> Int)
        -> ByteString
clos2bs = LBS.toStrict . encode

bs2clos :: ByteString
	-> Closure (Int -> Int)
bs2clos = decode . LBS.fromStrict

bs2func :: ByteString -> (Int -> Int)
bs2func = unclosure . bs2clos

-- | Apply a serialized closure to 1+ serialized argument(s), returning
--   a serialized result.
invoke :: ByteString -- ^ serialized closure
       -> CInt       -- ^ serialized argument(s)
       -> CInt       -- ^ serialized result
invoke clos x = fromIntegral $ bs2func clos (fromIntegral x)

foreign export ccall invokeC :: Ptr CChar
                             -> CLong
                             -> CInt
                             -> IO CInt

-- | C-friendly version of 'invoke', the one we actually
--   export to C.
invokeC :: Ptr CChar       -- ^ serialized closure buffer
        -> CLong           -- ^ size (in bytes) of serialized closure
        -> CInt            -- ^ argument
        -> IO CInt
invokeC clos closSize arg = do
    clos' <- unsafePackCStringLen (clos, fromIntegral closSize)
    return $ invoke clos' arg