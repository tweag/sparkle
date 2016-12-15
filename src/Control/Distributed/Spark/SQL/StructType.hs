{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

module Control.Distributed.Spark.SQL.StructType where

import Data.Text (Text)
import Language.Java

newtype StructType =
    StructType (J ('Class "org.apache.spark.sql.types.StructType"))
instance Coercible StructType ('Class "org.apache.spark.sql.types.StructType")

newtype StructField =
    StructField (J ('Class "org.apache.spark.sql.types.StructField"))
instance Coercible StructField
                   ('Class "org.apache.spark.sql.types.StructField")

fields :: StructType -> IO [StructField]
fields st = do
    jfields <- call st "fields" []
    Prelude.map StructField <$>
      reify (jfields ::
              J ('Array ('Class "org.apache.spark.sql.types.StructField")))

name :: StructField -> IO Text
name sf = call sf "name" [] >>= reify

nullable :: StructField -> IO Bool
nullable sf = call sf "nullable" []

newtype DataType = DataType (J ('Class "org.apache.spark.sql.types.DataType"))
  deriving Eq
instance Coercible DataType ('Class "org.apache.spark.sql.types.DataType")

dataType :: StructField -> IO DataType
dataType sf = call sf "dataType" []

typeName :: DataType -> IO Text
typeName dt = call dt "typeName" [] >>= reify
