-- | Bindings for
-- <https://spark.apache.org/docs/latest/api/java/org/apache/spark/api/java/JavaSparkContext.html org.apache.spark.api.java.JavaSparkContext>.
--
-- Please refer to that documentation for the meaning of each binding.

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

-- Linear stuff we probably need
import qualified Prelude ()
import Prelude.Linear hiding (IO, filter, map, subtract, take, zero)
-- import qualified Prelude.Linear as PL
import System.IO.Linear as LIO
import Control.Functor.Linear
import qualified Data.Functor.Linear as D
import qualified Unsafe.Linear as Unsafe

import Data.Int (Int32)
import Data.ByteString (ByteString)
import qualified Data.Text as Text
import Data.Text (Text)
import Control.Distributed.Spark.Safe.RDD
-- import Language.Java
-- import Language.Java.Inline

import Foreign.JNI.Safe 
import Foreign.JNI.Types.Safe
import Language.Java.Safe
import Language.Java.Inline.Safe

imports "org.apache.spark.api.java.JavaSparkContext"


newtype SparkConf = SparkConf (J ('Class "org.apache.spark.SparkConf"))
  deriving Coercible

newSparkConf :: Text -> IO SparkConf
newSparkConf appname = Control.Functor.Linear.do
  jname <- reflect appname
  conf :: SparkConf <- new End
  [java| $conf.setAppName($jname) |]

-- TODO: do we want to make sparkconf's linear?
-- pros: we will only be able to have a single SparkContext, as required
-- cons: updating sparkConfig is more annoying now
confSet :: SparkConf -> Text -> Text -> IO ()
confSet conf key value = Control.Functor.Linear.do
  jkey <- reflect key
  jval <- reflect value
  SparkConf scRef <- [java| $conf.set($jkey, $jval) |]
  deleteLocalRef scRef

confGet :: SparkConf -> Text -> Text -> IO (Ur Text)
confGet conf key def =
  reflect key >>= \jkey ->
    reflect def >>= \jdef ->
      call conf "get" jkey jdef End >>= reify_

setLocalProperty :: SparkContext -> Text -> Text -> IO ()
setLocalProperty sc key value =
  reflect key >>= \jkey ->
    reflect value >>= \jval ->
      call sc "setLocalProperty" jkey jval End

newtype SparkContext = SparkContext (J ('Class "org.apache.spark.api.java.JavaSparkContext"))
  deriving Coercible

newSparkContext :: SparkConf %1 -> IO SparkContext
newSparkContext sc = [java| new JavaSparkContext($sc) |]
  -- new sc End

getOrCreateSparkContext :: SparkConf %1 -> IO SparkContext
getOrCreateSparkContext conf = Control.Functor.Linear.do
  scalaCtx :: J ('Class "org.apache.spark.SparkContext") <-
    [java| org.apache.spark.SparkContext.getOrCreate($conf) |]
  [java| org.apache.spark.api.java.JavaSparkContext.fromSparkContext($scalaCtx) |]

-- | Adds the given file to the pool of files to be downloaded
--   on every worker node. Use 'getFile' on those nodes to
--   get the (local) file path of that file in order to read it.
addFile :: SparkContext -> FilePath -> IO ()
addFile sc fp = Control.Functor.Linear.do
  jfp <- reflect (Text.pack fp)
  -- XXX workaround for inline-java-0.6 not supporting void return types.
  nullRef :: JObject <- [java| { $sc.addFile($jfp); return null; } |]
  deleteLocalRef nullRef

-- | Returns the local filepath of the given filename that
--   was "registered" using 'addFile'.
getFile :: FilePath -> IO (Ur FilePath)
getFile filename = Control.Functor.Linear.do
  jfilename <- reflect (Text.pack filename)
  jfilepath <- [java| org.apache.spark.SparkFiles.get($jfilename) |] 
  D.fmap (Unsafe.toLinear Text.unpack) <$> reify_ jfilepath

master :: SparkContext -> IO (Ur Text)
master sc = [java| $sc.master() |] >>= reify_

-- | See Note [Reading Files] ("Control.Distributed.Spark.RDD#reading_files").
textFile :: SparkContext -> FilePath -> IO (RDD Text)
textFile sc path = Control.Functor.Linear.do
  jpath <- reflect (Text.pack path)
  [java| $sc.textFile($jpath) |]

-- | The record length must be provided in bytes.
--
-- See Note [Reading Files] ("Control.Distributed.Spark.RDD#reading_files").
binaryRecords :: SparkContext -> FilePath -> Int32 -> IO (RDD ByteString)
binaryRecords sc fp recordLength = Control.Functor.Linear.do
  jpath <- reflect (Text.pack fp)
  [java| $sc.binaryRecords($jpath, $recordLength) |]

parallelize
  :: Reflect a
  => SparkContext
  -> [a]
  -> IO (RDD a)
parallelize sc xs = Control.Functor.Linear.do
  jxs :: J ('Array ('Class "java.lang.Object")) <- unsafeCast <$> reflect xs
  jlist :: J ('Iface "java.util.List") <- [java| java.util.Arrays.asList($jxs) |]
  [java| $sc.parallelize($jlist) |]

setJobGroup :: Text -> Text -> Bool -> SparkContext -> IO ()
setJobGroup jobId description interruptOnCancel sc = Control.Functor.Linear.do
  jjobId <- reflect jobId
  jdescription <- reflect description
  nullRef :: JObject <- [java| { $sc.setJobGroup($jjobId, $jdescription, $interruptOnCancel); return null; } |]
  deleteLocalRef nullRef
        --call sc "setJobGroup" jjobId jdescription interruptOnCancel End >> pure ()

cancelJobGroup :: Text -> SparkContext -> IO ()
cancelJobGroup jobId sc = reflect jobId >>= \jjobId -> call sc "cancelJobGroup" jjobId End

context :: RDD a %1 -> IO SparkContext
context rdd = [java| JavaSparkContext.fromSparkContext($rdd.context()) |]
