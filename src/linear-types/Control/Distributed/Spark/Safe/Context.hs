-- | Bindings for
-- <https://spark.apache.org/docs/latest/api/java/org/apache/spark/api/java/JavaSparkContext.html org.apache.spark.api.java.JavaSparkContext>.
--
-- Please refer to that documentation for the meaning of each binding.
--

{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LinearTypes #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE TypeApplications #-}

{-# OPTIONS_GHC -fplugin=Language.Java.Inline.Plugin #-}

module Control.Distributed.Spark.Safe.Context
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

-- Linear stuff we need
import qualified Prelude ()
import Prelude.Linear hiding (IO, filter, map, subtract, take, zero)
import System.IO.Linear as LIO
import Control.Functor.Linear as Linear
import qualified Data.Functor.Linear as D
import qualified Unsafe.Linear as Unsafe

import Data.Int (Int32)
import Data.ByteString (ByteString)
import qualified Data.Text as Text
import Data.Text (Text)

import Control.Distributed.Spark.Safe.RDD

import qualified Foreign.JNI.Types
import Foreign.JNI.Safe
import Foreign.JNI.Types.Safe
import Language.Java.Safe
import Language.Java.Inline.Safe

imports "org.apache.spark.api.java.JavaSparkContext"


newtype SparkConf = SparkConf (J ('Class "org.apache.spark.SparkConf"))
  deriving Coercible

newSparkConf :: Text -> IO SparkConf
newSparkConf appname = Linear.do
  jname <- reflect appname
  conf :: SparkConf <- new End
  [java| $conf.setAppName($jname) |]

confSet :: SparkConf %1 -> Text -> Text -> IO SparkConf
confSet conf key value = Linear.do
  jkey <- reflect key
  jval <- reflect value
  [java| $conf.set($jkey, $jval) |]

confGet :: SparkConf %1 -> Text -> Text -> IO (SparkConf, Ur Text)
confGet conf key def = Linear.do
  jkey <- reflect key
  jdef <- reflect def
  (conf0, conf1) <- newLocalRef conf
  resText <- call conf0 "get" jkey jdef End >>= reify_
  pure (conf1, resText)

setLocalProperty :: SparkContext %1 -> Text -> Text -> IO SparkContext
setLocalProperty sc key value = Linear.do
  jkey <- reflect key
  jval <- reflect value
  (sc0, sc1) <- newLocalRef sc
  [java| { $sc0.setLocalProperty($jkey, $jval); } |]
  pure sc1

newtype SparkContext = SparkContext (J ('Class "org.apache.spark.api.java.JavaSparkContext"))
  deriving Coercible

newSparkContext :: SparkConf %1 -> IO SparkContext
newSparkContext sc = [java| new JavaSparkContext($sc) |]

getOrCreateSparkContext :: SparkConf %1 -> IO SparkContext
getOrCreateSparkContext conf = Linear.do
  scalaCtx :: J ('Class "org.apache.spark.SparkContext") <-
    [java| org.apache.spark.SparkContext.getOrCreate($conf) |]
  [java| org.apache.spark.api.java.JavaSparkContext.fromSparkContext($scalaCtx) |]

-- | Adds the given file to the pool of files to be downloaded
--   on every worker node. Use 'getFile' on those nodes to
--   get the (local) file path of that file in order to read it.
addFile :: SparkContext %1 -> FilePath -> IO SparkContext
addFile sc fp = Linear.do
  jfp <- reflect (Text.pack fp)
  (sc0, sc1) <- newLocalRef sc
  [java| { $sc0.addFile($jfp); } |]
  pure sc1

-- | Returns the local filepath of the given filename that
--   was "registered" using 'addFile'.
getFile :: FilePath -> IO (Ur FilePath)
getFile filename = Linear.do
  jfilename <- reflect (Text.pack filename)
  jfilepath <- [java| org.apache.spark.SparkFiles.get($jfilename) |]
  D.fmap (Unsafe.toLinear Text.unpack) <$> reify_ jfilepath

master :: SparkContext %1 -> IO (Ur Text)
master sc = [java| $sc.master() |] >>= reify_

-- | See Note [Reading Files] ("Control.Distributed.Spark.RDD#reading_files").
textFile :: SparkContext %1 -> FilePath -> IO (RDD Text)
textFile sc path = Linear.do
  jpath <- reflect (Text.pack path)
  [java| $sc.textFile($jpath) |]

-- | The record length must be provided in bytes.
--
-- See Note [Reading Files] ("Control.Distributed.Spark.RDD#reading_files").
binaryRecords :: SparkContext %1 -> FilePath -> Int32 -> IO (RDD ByteString)
binaryRecords sc fp recordLength = Linear.do
  jpath <- reflect (Text.pack fp)
  [java| $sc.binaryRecords($jpath, $recordLength) |]

parallelize
  :: Reflect a
     => SparkContext
  %1 -> [a]
     -> IO (RDD a)
parallelize sc xs = Linear.do
  jxs :: J ('Array ('Class "java.lang.Object")) <- arrayUpcast <$> reflect xs
  jlist :: J ('Iface "java.util.List") <- [java| java.util.Arrays.asList($jxs) |]
  [java| $sc.parallelize($jlist) |]

setJobGroup :: Text -> Text -> Bool -> SparkContext %1 -> IO ()
setJobGroup jobId description interruptOnCancel sc = Linear.do
  jjobId <- reflect jobId
  jdescription <- reflect description
  [java| { $sc.setJobGroup($jjobId, $jdescription, $interruptOnCancel); } |]

cancelJobGroup :: Text -> SparkContext %1 -> IO ()
cancelJobGroup jobId sc = reflect jobId >>= \jjobId -> call sc "cancelJobGroup" jjobId End

context :: RDD a %1 -> IO SparkContext
context rdd = [java| JavaSparkContext.fromSparkContext($rdd.context()) |]
