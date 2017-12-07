{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE UndecidableInstances #-}

module Control.Distributed.Spark.SQL.Metadata where

import Language.Java

newtype Metadata = Metadata (J ('Class "org.apache.spark.sql.types.Metadata"))
  deriving Coercible

empty :: IO Metadata
empty = callStatic "org.apache.spark.sql.types.Metadata" "empty" []
