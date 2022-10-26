{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LinearTypes #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE UndecidableInstances #-}

module Control.Distributed.Spark.Safe.SQL.Context where

import System.IO.Linear as LIO
--
import Control.Distributed.Spark.Safe.Context
import Language.Java.Safe
import Language.Java.Inline.Safe

newtype SQLContext = SQLContext (J ('Class "org.apache.spark.sql.SQLContext"))
  deriving Coercible

newSQLContext :: SparkContext %1 -> IO SQLContext
newSQLContext sc = new sc End

getOrCreateSQLContext :: SparkContext %1 -> IO SQLContext
getOrCreateSQLContext jsc = 
  [java| org.apache.spark.sql.SQLContext.getOrCreate($jsc.sc()) |]
