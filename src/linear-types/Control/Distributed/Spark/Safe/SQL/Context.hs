{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LinearTypes #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE UndecidableInstances #-}

module Control.Distributed.Spark.Safe.SQL.Context where

import System.IO.Linear as LIO
import Control.Functor.Linear as Linear
--
import Control.Distributed.Spark.Safe.Context
import Language.Java.Safe

newtype SQLContext = SQLContext (J ('Class "org.apache.spark.sql.SQLContext"))
  deriving Coercible

newSQLContext :: SparkContext %1 -> IO SQLContext
newSQLContext sc = new sc End

-- TODO: make sure that the class name we put actually works
getOrCreateSQLContext :: SparkContext %1 -> IO SQLContext
getOrCreateSQLContext jsc = Linear.do
  sc :: J ('Class "org.apache.spark.SparkContext") <- call jsc "sc" End
  callStatic "org.apache.spark.sql.SQLContext" -- (classOf (undefined :: SQLContext))
             "getOrCreate"
             sc
             End
