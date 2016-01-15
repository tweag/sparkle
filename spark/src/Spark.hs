{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE StaticPointers #-}
module Spark where

import           Closure
import           Control.Distributed.Closure
-- import           Data.Binary.Serialise.CBOR
import qualified Data.ByteString as BS
import           Data.ByteString (ByteString)
import           Data.ByteString.Unsafe (unsafeUseAsCStringLen)
import           Data.Monoid     ((<>))
import           Data.Vector     (Vector, fromList)
import           Foreign.C.String (withCString)
import           Foreign.C.Types
import           Foreign.Marshal.Array (withArrayLen, peekArray)
import           Foreign.Marshal.Alloc (alloca)
import           Foreign.Storable (peek)
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

parallelize :: SparkContext -> [Int] -> IO RDD
parallelize sc vec = withArrayLen (map fromIntegral vec) $ \vecLen vecBuf ->
  let vecLen' = fromIntegral vecLen in
  [C.block| jobject {
      parallelize($(jobject sc), $(int* vecBuf), $(size_t vecLen'));
  } |]

rddmap :: Closure (Int -> Int)
       -> RDD
       -> IO RDD
rddmap clos rdd =
  unsafeUseAsCStringLen closBS $ \(closBuf, closSize) ->
  let closSize' = fromIntegral closSize in
  [C.block| jobject {
      rddmap($(jobject rdd), $(char* closBuf), $(long closSize'));
  } |]

  where closBS = clos2bs clos

collect :: RDD -> IO [Int]
collect rdd = fmap (map fromIntegral) $
  alloca $ \buf ->
  alloca $ \size -> do
    [C.block| void {
      collect($(jobject rdd), $(int** buf), $(size_t* size));
    } |]
    sz <- peek size
    b  <- peek buf
    peekArray (fromIntegral sz) b

f :: Int -> Int
f x = x * 2

wrapped_f :: Closure (Int -> Int)
wrapped_f = closure (static f)

sparkMain :: IO ()
sparkMain = do
    conf <- newSparkConf "Hello sparkle!"
    sc   <- newSparkContext conf
    rdd  <- parallelize sc [1..10]
    rdd' <- rddmap wrapped_f rdd
    res  <- collect rdd'
    print res

foreign export ccall sparkMain :: IO ()
