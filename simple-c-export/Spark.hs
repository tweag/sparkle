{-# LANGUAGE CPP #-}
{-# LANGUAGE ForeignFunctionInterface #-}
-- | Preliminary Spark module, which offers
--   helper functions for invoking serialized
--   functions.
module Spark where

import Control.Distributed.Closure
import Data.Binary
import Foreign.C.String

import qualified Data.ByteString      as BS
import qualified Data.ByteString.Lazy as LBS

-- | Read back a serialized @Closure (ByteString -> ByteString)@
--   as a @ByteString -> ByteString@ function.
decodeClosure :: BS.ByteString -> (BS.ByteString -> BS.ByteString)
decodeClosure = unclosure . decode . LBS.fromStrict

-- | Apply a serialized closure to 1+ serialized argument(s), returning
--   a serialized result.
invoke :: BS.ByteString -- ^ serialized closure
       -> BS.ByteString -- ^ serialized argument(s)
       -> BS.ByteString -- ^ serialized result
invoke clos arg = decodeClosure clos arg

foreign export ccall invokeC :: CString -> CString -> IO CString

-- | C-friendly version of 'invoke'.
invokeC :: CString
        -> CString
        -> IO CString
invokeC clos arg = do
    clos' <- BS.packCString clos
    arg'  <- BS.packCString arg
    BS.useAsCString (invoke clos' arg') return

wrap1 :: (Serializable a, Serializable b)
      => (a -> b)
      -> (BS.ByteString -> BS.ByteString)
wrap1 f = LBS.toStrict . encode . f . decode . LBS.fromStrict

