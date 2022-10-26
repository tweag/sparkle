{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LinearTypes #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE UndecidableInstances #-}

module Control.Distributed.Spark.Safe.SQL.StructField where

import Prelude.Linear hiding (IO)
import System.IO.Linear as LIO
import Control.Functor.Linear as Linear

import Control.Distributed.Spark.Safe.SQL.DataType
import Control.Distributed.Spark.Safe.SQL.Metadata
import Data.Text (Text)
import Language.Java.Safe as Java
import Language.Java.Inline.Safe

newtype StructField = StructField (J ('Class "org.apache.spark.sql.types.StructField"))
  deriving Coercible

new :: Text -> DataType %1 -> Bool -> Metadata %1 -> IO StructField
new sname dt n md = Linear.do
    jname <- reflect sname
    [java| new org.apache.spark.sql.types.StructField($jname, $dt, $n, $md) |]

-- TODO: test this bc it may not work
name :: StructField %1 -> IO (Ur Text)
name sf = call sf "name" End >>= reify_

nullable :: StructField %1 -> IO (Ur Bool)
nullable sf = call sf "nullable" End

dataType :: StructField %1 -> IO DataType
dataType sf = call sf "dataType" End
