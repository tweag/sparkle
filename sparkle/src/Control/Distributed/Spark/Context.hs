{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Control.Distributed.Spark.Context where

import Data.Text (Text, pack, unpack)
import Data.Singletons (Sing, sing)
import Foreign.JNI
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

-- | Adds the given file to the pool of files to be downloaded
--   on every worker node. Use 'getFile' on those nodes to
--   get the (local) file path of that file in order to read it.
addFile :: SparkContext -> FilePath -> IO ()
addFile sc fp = do
  jfp <- reflect (pack fp)
  cls <- findClass "org/apache/spark/api/java/JavaSparkContext"
  method <- getMethodID cls "addFile" "(Ljava/lang/String;)V"
  callVoidMethod sc method [coerce jfp]

-- | Returns the local filepath of the given filename that
--   was "registered" using 'addFile'.
getFile :: FilePath -> IO FilePath
getFile filename = do
  jfilename <- reflect (pack filename)
  fmap unpack . reify =<< callStatic (sing :: Sing "org.apache.spark.SparkFiles") "get" [coerce jfilename]

master :: SparkContext -> IO Text
master sc = do
  res <- call sc "master" []
  reify res
