{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

module Control.Distributed.Spark.SQL.StructType where

import Control.Distributed.Spark.SQL.StructField
import Language.Java as Java

newtype StructType =
    StructType (J ('Class "org.apache.spark.sql.types.StructType"))
instance Coercible StructType ('Class "org.apache.spark.sql.types.StructType")

new :: [StructField] -> IO StructType
new fs = do
    jfs <- reflect [ j | StructField j <- fs ]
    Java.new [ coerce jfs ]

add :: StructField -> StructType -> IO StructType
add sf st = call st "add" [coerce sf]

fields :: StructType -> IO [StructField]
fields st = do
    jfields <- call st "fields" []
    Prelude.map StructField <$>
      reify (jfields ::
              J ('Array ('Class "org.apache.spark.sql.types.StructField")))
