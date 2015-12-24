{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}
module Spark where

import qualified Data.ByteString as BS
import           Data.ByteString (ByteString)
import           Data.Monoid     ((<>))
import           Foreign.C.String (withCString)
import           JNI
import qualified Language.C.Inline as C

C.context (C.baseCtx <> jniCtx)

C.include "<Spark.h>"

-- withCString :: String -> (CString -> IO a) -> IO a

newSparkConf :: String -> IO JObject
newSparkConf name =
    withCString name $ \nameptr -> do
      [C.block| jobject {
           newSparkConf($(char *nameptr));
      } |]

newSparkContext :: JObject -> IO JObject
newSparkContext conf =
    [C.block| jobject {
         newSparkContext($(jobject conf));
    } |]

sparkMain :: IO ()
sparkMain = do
    conf <- newSparkConf "Hello sparkle!"
    print =<< newSparkContext conf

foreign export ccall sparkMain :: IO ()
