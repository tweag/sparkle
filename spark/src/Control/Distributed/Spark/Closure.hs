{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE ForeignFunctionInterface #-}
module Control.Distributed.Spark.Closure where

import Control.Distributed.Closure
import Control.Distributed.Spark.JNI
import Data.Binary (encode, decode)
import Data.ByteString (ByteString)
import Data.ByteString.Unsafe (unsafePackCStringLen)
import Foreign.C.String
import Foreign.C.Types
import Foreign.Ptr

import qualified Data.ByteString.Lazy as LBS

class ToJObject a where
  toJObject :: JNIEnv -> a -> IO JObject

instance ToJObject JObject where
  toJObject _ = return

instance ToJObject Bool where
  toJObject env b = do
    cls <- findClass env "java/lang/Boolean"
    newObject env cls "(Z)V" [JBoolean b']

    where b' = if b then 1 else 0

class FromJObject a where
  fromJObject :: JNIEnv -> JObject -> IO a

instance FromJObject JObject where
  fromJObject _ = return

instance FromJObject String where
  fromJObject = fromJString

wrap :: (FromJObject a, ToJObject b)
     => (a -> b)
     -> JNIEnv
     -> JObject
     -> IO JObject
wrap f env jarg = do
  arg <- fromJObject env jarg
  toJObject env (f arg)

--clos2bs :: Closure (JNIEnv -> JObject -> IO JObject)
--        -> ByteString
clos2bs :: Closure (String -> Bool) -> ByteString
clos2bs = LBS.toStrict . encode

--bs2clos :: ByteString
--        -> Closure (JNIEnv -> JObject -> IO JObject)
bs2clos :: ByteString -> Closure (String -> Bool)
bs2clos = decode . LBS.fromStrict

--bs2func :: ByteString -> (JNIEnv -> JObject -> IO JObject)
bs2func :: ByteString -> String -> Bool
bs2func = unclosure . bs2clos

-- | Apply a serialized closure to 1+ serialized argument(s), returning
--   a serialized result.
--invoke :: ByteString -- ^ serialized closure
--       -> JNIEnv
--       -> JObject    -- ^ argument
--       -> IO JObject -- ^ result
invoke :: ByteString -> String -> Bool
invoke clos x = bs2func clos x

foreign export ccall invokeC :: Ptr CChar
                             -> CLong
                             -> Ptr CChar
                             -> CLong
                             -> IO Bool

-- | C-friendly version of 'invoke', the one we actually
--   export to C.
invokeC :: Ptr CChar       -- ^ serialized closure buffer
        -> CLong           -- ^ size (in bytes) of serialized closure
        -> Ptr CChar
        -> CLong
        -> IO Bool
invokeC clos closSize arg argSize = do
    clos' <- unsafePackCStringLen (clos, fromIntegral closSize)
    arg' <- peekCStringLen (arg, fromIntegral argSize)
    putStrLn $ "Calling invokeC on: " ++ arg'
    return $ invoke clos' arg'
