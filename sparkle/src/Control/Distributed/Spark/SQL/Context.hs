{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

module Control.Distributed.Spark.SQL.Context where

import Control.Distributed.Spark.Context
import Foreign.JNI
import Language.Java

newtype SQLContext = SQLContext (J ('Class "org.apache.spark.sql.SQLContext"))
instance Coercible SQLContext ('Class "org.apache.spark.sql.SQLContext")

newSQLContext :: SparkContext -> IO SQLContext
newSQLContext sc = new [coerce sc]
