{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE UndecidableInstances #-}

module Control.Distributed.Spark.Safe.SQL.StructType where

import Control.Distributed.Spark.SQL.StructField
import Control.Monad (forM)
import qualified Data.Coerce
import Foreign.JNI
import Language.Java as Java

newtype StructType = StructType (J ('Class "org.apache.spark.sql.types.StructType"))
  deriving Coercible

new :: [StructField] -> IO StructType
new fs =
    toArray (Data.Coerce.coerce fs
              :: [J ('Class "org.apache.spark.sql.types.StructField")])
      >>= Java.new

add :: StructField -> StructType -> IO StructType
add sf st = call st "add" sf

fields :: StructType -> IO [StructField]
fields st = do
    jfields <- call st "fields"
    n <- getArrayLength
      (jfields :: J ('Array ('Class "org.apache.spark.sql.types.StructField")))
    forM [0 .. n - 1] $ \i ->
      StructField <$> getObjectArrayElement jfields i
