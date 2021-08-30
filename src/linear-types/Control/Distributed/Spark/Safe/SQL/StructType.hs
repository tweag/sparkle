{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
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

module Control.Distributed.Spark.Safe.SQL.StructType where

import qualified Prelude as P
import Prelude.Linear hiding (IO)
-- import qualified Prelude.Linear as PL
import System.IO.Linear as LIO
import Control.Monad.IO.Class.Linear
import Control.Functor.Linear as Linear
-- import Data.Functor.Linear (forM)

import Control.Distributed.Spark.Safe.SQL.StructField
-- import Control.Monad (forM)
import qualified Data.Coerce as Coerce
import qualified Foreign.JNI.Types
import Foreign.JNI.Types.Safe
import Foreign.JNI.Safe
import Language.Java.Safe as Java
import Language.Java.Inline.Safe

newtype StructType = StructType (J ('Class "org.apache.spark.sql.types.StructType"))
  deriving Coercible

deleteLocalRefs :: (MonadIO m, Coerce.Coercible o (J ty)) => [o] %1-> m ()
deleteLocalRefs = foldM (\() -> deleteLocalRef) ()

new :: [StructField] %1 -> IO StructType
new fs =
  toArray (map unStructField fs :: [J ('Class "org.apache.spark.sql.types.StructField")])
           >>= \(jfields, arr) -> deleteLocalRefs jfields
             >> [java| new org.apache.spark.sql.types.StructType($arr) |]
  where
    unStructField :: StructField %1 -> J ('Class "org.apache.spark.sql.types.StructField")
    unStructField (StructField j) = j

add :: StructField %1 -> StructType %1 -> IO StructType
add sf st = call st "add" sf End

fields :: StructType %1 -> IO [StructField]
fields st = Linear.do
    jfields <- call st "fields" End
    (jfields', Ur n) <- getArrayLength
      (jfields :: J ('Array ('Class "org.apache.spark.sql.types.StructField")))
    (jfields'', fieldsList) <- foldM 
                                (\(arr, acc) i -> second ((: acc) . StructField) <$> getObjectArrayElement arr i) 
                                (jfields', []) 
                                [0 .. n P.- 1]
    deleteLocalRef jfields''
    pure fieldsList
  where
    second :: (n %1 -> o) %1 -> (m, n) %1 -> (m, o)
    second g (a, b) = (a, g b)
