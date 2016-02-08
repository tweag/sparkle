{-# LANGUAGE ForeignFunctionInterface #-}
module Control.Distributed.Spark.Closure
  ( clos2bs
  , bs2clos
  , bs2func
  , unclosure
  , invoke
  , invokeC
  ) where

import Control.Distributed.Closure
import Control.Distributed.Spark.JNI
import Data.Binary (encode, decode)
import Data.ByteString (ByteString)
import Data.ByteString.Unsafe (unsafePackCStringLen)
import Foreign.C.Types
import Foreign.Ptr

import qualified Data.ByteString.Lazy as LBS

clos2bs :: Closure (JObject -> IO JObject)
        -> ByteString
clos2bs = LBS.toStrict . encode

bs2clos :: ByteString
        -> Closure (JObject -> IO JObject)
bs2clos = decode . LBS.fromStrict

bs2func :: ByteString -> (JObject -> IO JObject)
bs2func = unclosure . bs2clos

-- | Apply a serialized closure to 1+ serialized argument(s), returning
--   a serialized result.
invoke :: ByteString -- ^ serialized closure
       -> JObject    -- ^ argument
       -> IO JObject -- ^ result
invoke clos x = bs2func clos x

foreign export ccall invokeC :: Ptr CChar
                             -> CLong
                             -> JObject
                             -> IO JObject

-- | C-friendly version of 'invoke', the one we actually
--   export to C.
invokeC :: Ptr CChar       -- ^ serialized closure buffer
        -> CLong           -- ^ size (in bytes) of serialized closure
        -> JObject         -- ^ argument
        -> IO JObject
invokeC clos closSize arg = do
    clos' <- unsafePackCStringLen (clos, fromIntegral closSize)
    invoke clos' arg
