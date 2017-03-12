-- | Bindings for
-- <https://spark.apache.org/docs/latest/api/java/org/apache/spark/api/java/JavaSparkContext.html org.apache.spark.api.java.JavaSparkContext>.
--
-- Please refer to that documentation for the meaning of each binding.

{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Control.Distributed.Spark.Context
  ( -- * Spark configurations
    SparkConf(..)
  , newSparkConf
  , confSet
    -- * Spark contexts
  , SparkContext(..)
  , newSparkContext
  , getOrCreateSparkContext
  , addFile
  , getFile
  , master
  -- * RDD creation
  , parallelize
  , binaryRecords
  , textFile
  ) where

import Data.Int (Int32)
import Data.ByteString (ByteString)
import qualified Data.Text as Text
import Data.Text (Text)
import Control.Distributed.Spark.RDD
import Language.Java

newtype SparkConf = SparkConf (J ('Class "org.apache.spark.SparkConf"))
instance Coercible SparkConf ('Class "org.apache.spark.SparkConf")

newSparkConf :: Text -> IO SparkConf
newSparkConf appname = do
  jname <- reflect appname
  cnf :: SparkConf <- new []
  call cnf "setAppName" [coerce jname]

confSet :: SparkConf -> Text -> Text -> IO ()
confSet conf key value = do
  jkey <- reflect key
  jval <- reflect value
  _ :: SparkConf <- call conf "set" [coerce jkey, coerce jval]
  return ()

newtype SparkContext = SparkContext (J ('Class "org.apache.spark.api.java.JavaSparkContext"))
instance Coercible SparkContext ('Class "org.apache.spark.api.java.JavaSparkContext")

newSparkContext :: SparkConf -> IO SparkContext
newSparkContext conf = new [coerce conf]

getOrCreateSparkContext :: SparkConf -> IO SparkContext
getOrCreateSparkContext cnf = do
  scalaCtx :: J ('Class "org.apache.spark.SparkContext") <-
    callStatic (sing :: Sing "org.apache.spark.SparkContext") "getOrCreate" [coerce cnf]

  callStatic (sing :: Sing "org.apache.spark.api.java.JavaSparkContext") "fromSparkContext" [coerce scalaCtx]

-- | Adds the given file to the pool of files to be downloaded
--   on every worker node. Use 'getFile' on those nodes to
--   get the (local) file path of that file in order to read it.
addFile :: SparkContext -> FilePath -> IO ()
addFile sc fp = do
  jfp <- reflect (Text.pack fp)
  call sc "addFile" [coerce jfp]

-- | Returns the local filepath of the given filename that
--   was "registered" using 'addFile'.
getFile :: FilePath -> IO FilePath
getFile filename = do
  jfilename <- reflect (Text.pack filename)
  fmap Text.unpack . reify =<< callStatic (sing :: Sing "org.apache.spark.SparkFiles") "get" [coerce jfilename]

master :: SparkContext -> IO Text
master sc = do
  res <- call sc "master" []
  reify res

-- | See Note [Reading Files] ("Control.Distributed.Spark.RDD#reading_files").
textFile :: SparkContext -> FilePath -> IO (RDD Text)
textFile sc path = do
  jpath <- reflect (Text.pack path)
  call sc "textFile" [coerce jpath]

-- | The record length must be provided in bytes.
--
-- See Note [Reading Files] ("Control.Distributed.Spark.RDD#reading_files").
binaryRecords :: SparkContext -> FilePath -> Int32 -> IO (RDD ByteString)
binaryRecords sc fp recordLength = do
  jpath <- reflect (Text.pack fp)
  call sc "binaryRecords" [coerce jpath, coerce recordLength]

parallelize
  :: Reflect a ty
  => SparkContext
  -> [a]
  -> IO (RDD a)
parallelize sc xs = do
    jxs :: J ('Iface "java.util.List") <- arrayToList =<< reflect xs
    call sc "parallelize" [coerce jxs]
  where
    arrayToList jxs =
        callStatic
          (sing :: Sing "java.util.Arrays")
          "asList"
          [coerce (unsafeCast jxs :: JObjectArray)]
