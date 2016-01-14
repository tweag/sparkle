{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}
module Spark where

import           Control.Distributed.Closure
-- import           Data.Binary.Serialise.CBOR
import qualified Data.ByteString as BS
import           Data.ByteString (ByteString)
import           Data.Monoid     ((<>))
import           Data.Vector     (Vector, fromList)
import           Foreign.C.String (withCString)
import           Foreign.C.Types
import           Foreign.Marshal.Array (withArrayLen)
import           JNI
import qualified Language.C.Inline as C

C.context (C.baseCtx <> jniCtx)

C.include "../SparkClasses.h"

-- TODO:
-- eventually turn all the 'type's into 'newtype's.

-- withCString :: String -> (CString -> IO a) -> IO a

type SparkConf = JObject

newSparkConf :: String -> IO SparkConf
newSparkConf name =
    withCString name $ \nameptr -> do
      [C.block| jobject {
           newSparkConf($(char *nameptr));
      } |]

type SparkContext = JObject

newSparkContext :: SparkConf -> IO SparkContext
newSparkContext conf =
    [C.block| jobject {
         newSparkContext($(jobject conf));
    } |]

type RDD = JObject

parallelize :: SparkContext -> [CInt] -> IO RDD
parallelize sc vec = withArrayLen vec $ \vecLen vecBuf ->
  let vecLen' = fromIntegral vecLen in
  [C.block| jobject {
      parallelize($(jobject sc), $(int* vecBuf), $(size_t vecLen'));
  } |]

rddmap :: Closure (Int -> Int)
       -> RDD
       -> IO RDD
rddmap = undefined

collect :: RDD -> IO (Vector Int)
collect = undefined

sparkMain :: IO ()
sparkMain = do
    conf <- newSparkConf "Hello sparkle!"
    sc   <- newSparkContext conf
    rdd  <- parallelize sc [1..10]
    -- rdd' <- rddmap f rdd'
    -- res  <- collect rdd'
    -- print res
    return ()

foreign export ccall sparkMain :: IO ()
