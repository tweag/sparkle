{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

module Control.Distributed.Spark.SQL.Metadata where

import Language.Java

newtype Metadata = Metadata (J ('Class "org.apache.spark.sql.types.Metadata"))
instance Coercible Metadata ('Class "org.apache.spark.sql.types.Metadata")

empty :: IO Metadata
empty = callStatic "org.apache.spark.sql.types.Metadata" "empty" []
