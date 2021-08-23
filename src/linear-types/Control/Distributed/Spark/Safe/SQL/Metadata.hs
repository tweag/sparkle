{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE UndecidableInstances #-}

module Control.Distributed.Spark.Safe.SQL.Metadata where

import Language.Java.Safe
import System.IO.Linear as LIO

newtype Metadata = Metadata (J ('Class "org.apache.spark.sql.types.Metadata"))
  deriving Coercible

empty :: LIO.IO Metadata
empty = callStatic "org.apache.spark.sql.types.Metadata" "empty" End
