-- | Bindings for
-- <https://spark.apache.org/docs/latest/api/java/org/apache/spark/api/java/JavaSparkContext.html org.apache.spark.api.java.JavaSparkContext>.
--
-- Please refer to that documentation for the meaning of each binding.

{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE UndecidableInstances #-}

{-# OPTIONS_GHC -fplugin=Language.Java.Inline.Plugin #-}

module Control.Distributed.Spark.Context
  ( -- * Spark configurations
    SparkConf(..)
  , newSparkConf
  , confGet
  , confSet
  , setLocalProperty
    -- * Spark contexts
  , SparkContext(..)
  , newSparkContext
  , getOrCreateSparkContext
  , addFile
  , getFile
  , master
  , setJobGroup
  , cancelJobGroup
  , context
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
import Language.Java.Inline

imports "org.apache.spark.api.java.JavaSparkContext"


newtype SparkConf = SparkConf (J ('Class "org.apache.spark.SparkConf"))
  deriving Coercible

newSparkConf :: Text -> IO SparkConf
newSparkConf appname = do
  jname <- reflect appname
  conf :: SparkConf <- new
  [java| $conf.setAppName($jname) |]

confSet :: SparkConf -> Text -> Text -> IO ()
confSet conf key value = do
  jkey <- reflect key
  jval <- reflect value
  _ :: SparkConf <- [java| $conf.set($jkey, $jval) |]
  return ()

confGet :: SparkConf -> Text -> Text -> IO Text
confGet conf key def =
  reflect key `withLocalRef` \jkey ->
  reflect def `withLocalRef` \jdef ->
  call conf "get" jkey jdef `withLocalRef` reify

setLocalProperty :: SparkContext -> Text -> Text -> IO ()
setLocalProperty sc key value =
  withLocalRef (reflect key) $ \jkey ->
  withLocalRef (reflect value) $ \jval ->
  call sc "setLocalProperty" jkey jval

newtype SparkContext = SparkContext (J ('Class "org.apache.spark.api.java.JavaSparkContext"))
  deriving Coercible

newSparkContext :: SparkConf -> IO SparkContext
newSparkContext = new

getOrCreateSparkContext :: SparkConf -> IO SparkContext
getOrCreateSparkContext conf = do
  scalaCtx :: J ('Class "org.apache.spark.SparkContext") <-
    [java| org.apache.spark.SparkContext.getOrCreate($conf) |]
  [java| org.apache.spark.api.java.JavaSparkContext.fromSparkContext($scalaCtx) |]

-- | Adds the given file to the pool of files to be downloaded
--   on every worker node. Use 'getFile' on those nodes to
--   get the (local) file path of that file in order to read it.
addFile :: SparkContext -> FilePath -> IO ()
addFile sc fp = do
  jfp <- reflect (Text.pack fp)
  -- XXX workaround for inline-java-0.6 not supporting void return types.
  _ :: JObject <- [java| { $sc.addFile($jfp); return null; } |]
  return ()

-- | Returns the local filepath of the given filename that
--   was "registered" using 'addFile'.
getFile :: FilePath -> IO FilePath
getFile filename = do
  jfilename <- reflect (Text.pack filename)
  fmap Text.unpack . reify =<<
    [java| org.apache.spark.SparkFiles.get($jfilename) |]

master :: SparkContext -> IO Text
master sc = reify =<< [java| $sc.master() |]

-- | See Note [Reading Files] ("Control.Distributed.Spark.RDD#reading_files").
textFile :: SparkContext -> FilePath -> IO (RDD Text)
textFile sc path = do
  jpath <- reflect (Text.pack path)
  [java| $sc.textFile($jpath) |]

-- | The record length must be provided in bytes.
--
-- See Note [Reading Files] ("Control.Distributed.Spark.RDD#reading_files").
binaryRecords :: SparkContext -> FilePath -> Int32 -> IO (RDD ByteString)
binaryRecords sc fp recordLength = do
  jpath <- reflect (Text.pack fp)
  [java| $sc.binaryRecords($jpath, $recordLength) |]

parallelize
  :: Reflect a
  => SparkContext
  -> [a]
  -> IO (RDD a)
parallelize sc xs =
  withLocalRef (unsafeCast <$> reflect xs) $ \(jxs :: J ('Array ('Class "java.lang.Object"))) ->
  withLocalRef [java| java.util.Arrays.asList($jxs) |] $ \(jlist :: J ('Iface "java.util.List")) ->
  [java| $sc.parallelize($jlist) |]

setJobGroup :: Text -> Text -> Bool -> SparkContext -> IO ()
setJobGroup jobId description interruptOnCancel sc =
    reflect jobId `withLocalRef` \jjobId ->
    reflect description `withLocalRef` \jdescription ->
    call sc "setJobGroup" jjobId jdescription interruptOnCancel

cancelJobGroup :: Text -> SparkContext -> IO ()
cancelJobGroup jobId sc = reflect jobId `withLocalRef` call sc "cancelJobGroup"

context :: RDD a -> IO SparkContext
context rdd = [java| JavaSparkContext.fromSparkContext($rdd.context()) |]
