{-# LANGUAGE CPP #-}
{-# LANGUAGE ForeignFunctionInterface #-}
-- | Preliminary Spark module, which offers
--   helper functions for invoking serialized
--   functions.
module Spark where

import Control.Distributed.Closure
import Data.Binary
import Data.ByteString.Unsafe (unsafeUseAsCStringLen, unsafePackCStringLen)
import Data.Maybe (catMaybes)
import Foreign.Ptr (Ptr)
import Foreign.Storable (poke)
import Foreign.Marshal.Utils
import Foreign.Marshal.Alloc (mallocBytes)
import Foreign.C.Types
import Foreign.C.String (CStringLen)
import GHC.StaticPtr

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

foreign export ccall invokeC :: Ptr CChar
						     -> CLong
						     -> Ptr CChar
						     -> CLong
						     -> Ptr (Ptr CChar)
						     -> Ptr CSize
						     -> IO ()

-- | C-friendly version of 'invoke', the one we actually
--   export to C.
invokeC :: Ptr CChar       -- ^ serialized closure buffer
        -> CLong           -- ^ size (in bytes) of serialized closure
        -> Ptr CChar       -- ^ serialized argument buffer
        -> CLong           -- ^ size (in bytes) of serialized argument
        -> Ptr (Ptr CChar) -- ^ (output) buffer to store serialized result
        -> Ptr CSize       -- ^ (output) size of result, in bytes
        -> IO ()
invokeC clos closSize arg argSize outPtr outSize = do
    clos' <- unsafePackCStringLen (clos, fromIntegral closSize)
    arg'  <- unsafePackCStringLen (arg, fromIntegral argSize)
    -- debugStaticPtrs
    unsafeUseAsCStringLen (invoke clos' arg') $ \(p, n) -> do
        outval <- mallocBytes n
        moveBytes outval p n
        poke outPtr outval
        poke outSize (fromIntegral n)

-- For debug use only: print the static pointer information
-- for every static key we know about.
debugStaticPtrs :: IO ()
debugStaticPtrs = do
  ks <- staticPtrKeys
  ptrs <- fmap catMaybes $ mapM unsafeLookupStaticPtr ks
  mapM_ printInfo ptrs

  where printInfo :: StaticPtr () -> IO ()
        printInfo = print . staticPtrInfo

wrap1 :: (Serializable a, Serializable b)
      => (a -> b)
      -> (BS.ByteString -> BS.ByteString)
wrap1 f = LBS.toStrict . encode . f . decode . LBS.fromStrict

