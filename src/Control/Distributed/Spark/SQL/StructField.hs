{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE UndecidableInstances #-}

module Control.Distributed.Spark.SQL.StructField where

import Control.Distributed.Spark.SQL.DataType
import Control.Distributed.Spark.SQL.Metadata
import Data.Text (Text)
import Language.Java as Java

newtype StructField = StructField (J ('Class "org.apache.spark.sql.types.StructField"))
  deriving Coercible

new :: Text -> DataType -> Bool -> Metadata -> IO StructField
new sname dt n md = do
    jname <- reflect sname
    Java.new [coerce jname, coerce dt, coerce n, coerce md]

name :: StructField -> IO Text
name sf = call sf "name" [] >>= reify

nullable :: StructField -> IO Bool
nullable sf = call sf "nullable" []

dataType :: StructField -> IO DataType
dataType sf = call sf "dataType" []
