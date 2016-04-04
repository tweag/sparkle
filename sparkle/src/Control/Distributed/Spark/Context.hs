{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
module Control.Distributed.Spark.Context where

import Data.Coerce
import Data.Text (Text, pack, unpack)
import Foreign.JNI
import Language.Java

newtype SparkConf = SparkConf (J ('Class "org.apache.spark.SparkConf"))

newSparkConf :: Text -> IO SparkConf
newSparkConf appname = do
  cls <- findClass "org/apache/spark/SparkConf"
  setAppName <- getMethodID cls "setAppName" "(Ljava/lang/String;)Lorg/apache/spark/SparkConf;"
  cnf <- fmap unsafeCast $ newObject cls "()V" []
  jname <- reflect appname
  _ <- callObjectMethod cnf setAppName [JObject jname]
  return (coerce cnf)

confSet :: SparkConf -> Text -> Text -> IO ()
confSet conf key value = do
  cls <- findClass "org/apache/spark/SparkConf"
  set <- getMethodID cls "set" "(Ljava/lang/String;Ljava/lang/String;)Lorg/apache/spark/SparkConf;"
  jkey <- reflect key
  jval <- reflect value
  _    <- callObjectMethod conf set [JObject jkey, JObject jval]
  return ()

newtype SparkContext = SparkContext (J ('Class "org.apache.spark.api.java.JavaSparkContext"))

newSparkContext :: SparkConf -> IO SparkContext
newSparkContext conf = do
  cls <- findClass "org/apache/spark/api/java/JavaSparkContext"
  coerce . unsafeCast <$> newObject cls "(Lorg/apache/spark/SparkConf;)V" [JObject conf]

-- | Adds the given file to the pool of files to be downloaded
--   on every worker node. Use 'getFile' on those nodes to
--   get the (local) file path of that file in order to read it.
addFile :: SparkContext -> FilePath -> IO ()
addFile sc fp = do
  jfp <- reflect (pack fp)
  cls <- findClass "org/apache/spark/api/java/JavaSparkContext"
  method <- getMethodID cls "addFile" "(Ljava/lang/String;)V"
  callVoidMethod sc method [JObject jfp]

-- | Returns the local filepath of the given filename that
--   was "registered" using 'addFile'.
getFile :: FilePath -> IO FilePath
getFile filename = do
  jfilename <- reflect (pack filename)
  cls <- findClass "org/apache/spark/SparkFiles"
  method <- getStaticMethodID cls "get" "(Ljava/lang/String;)Ljava/lang/String;"
  res <- callStaticObjectMethod cls method [JObject jfilename]
  fmap unpack $ reify (unsafeCast res)

master :: SparkContext -> IO Text
master sc = do
  cls <- findClass "org/apache/spark/api/java/JavaSparkContext"
  method <- getMethodID cls "master" "()Ljava/lang/String;"
  res <- fmap unsafeCast $ callObjectMethod sc method []
  reify res
