{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LinearTypes #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

{-# OPTIONS_GHC -fno-warn-orphans -Wno-redundant-constraints #-}
{-# OPTIONS_GHC -fplugin=Language.Java.Inline.Plugin #-}

module Control.Distributed.Spark.Safe.SQL.Encoder
  ( long
  , string
  , int
  , short
  , boolean
  , float
  , double
  , tuple2
  , javaSerialization
  , kryo
  , coerceEncoder
  , getRowEncoder
  , Encoder(..)
  , HasEncoder(..)
  ) where

import Prelude.Linear hiding (IO, min, max, mod, and, or, otherwise)
import System.IO.Linear as LIO
import Control.Functor.Linear as Linear
import qualified Unsafe.Linear as Unsafe

import Control.Distributed.Spark.Safe.SQL.Row
import Control.Distributed.Spark.Safe.SQL.StructType

import qualified Data.Coerce
import Data.Constraint (Dict(Dict))
import Data.Int
import Data.Singletons (SingI)
import Data.Text (Text)

import Language.Java.Safe
import Language.Java.Inline.Safe
import Language.Scala.Tuple
import Foreign.JNI.Safe

newtype Encoder a = Encoder (J ('Iface "org.apache.spark.sql.Encoder"))
  deriving (Coercible)

long :: IO (Encoder Int64)
long = [java| org.apache.spark.sql.Encoders.LONG() |]

string :: IO (Encoder Text)
string = [java| org.apache.spark.sql.Encoders.STRING() |]

int :: IO (Encoder Int32)
int = [java| org.apache.spark.sql.Encoders.INT() |]

short :: IO (Encoder Int16)
short = [java| org.apache.spark.sql.Encoders.SHORT() |]

boolean :: IO (Encoder Bool)
boolean = [java| org.apache.spark.sql.Encoders.BOOLEAN() |]

float :: IO (Encoder Float)
float = [java| org.apache.spark.sql.Encoders.FLOAT() |]

double :: IO (Encoder Double)
double = [java| org.apache.spark.sql.Encoders.DOUBLE() |]

tuple2 :: Encoder a %1 -> Encoder b %1 -> IO (Encoder (Tuple2 a b))
tuple2 ea eb = [java| org.apache.spark.sql.Encoders.tuple($ea, $eb) |]

javaSerialization :: forall a ty. (Interp a ~ ty, SingI ty, IsReferenceType ty)
                  => IO (Encoder a)
javaSerialization = Linear.do
    cls <- findClass (referenceTypeName (sing :: Sing ty))
    [java| org.apache.spark.sql.Encoders.javaSerialization($cls) |]

kryo :: forall a ty. (Interp a ~ ty, SingI ty, IsReferenceType ty)
     => IO (Encoder a)
kryo = Linear.do
    cls <- findClass (referenceTypeName (sing :: Sing ty))
    [java| org.apache.spark.sql.Encoders.kryo($cls) |]

coerceEncoder :: forall a b . Interp a ~ Interp b => Encoder a %1 -> Encoder b
coerceEncoder = Unsafe.toLinear Data.Coerce.coerce
  where
    _ = Dict @(Interp a ~ Interp b)

getRowEncoder :: StructType %1 -> IO (Encoder Row)
getRowEncoder st =
    [java| org.apache.spark.sql.catalyst.encoders.RowEncoder.apply($st) |]

-- | Class of types which have encoders
class HasEncoder a where
  encoder :: IO (Encoder a)

instance HasEncoder Int64 where
  encoder = long

instance HasEncoder Text where
  encoder = string

instance HasEncoder Float where
  encoder = float

instance HasEncoder Double where
  encoder = double

instance HasEncoder Int32 where
  encoder = int

instance HasEncoder Int16 where
  encoder = short

instance HasEncoder Bool where
  encoder = boolean

instance (HasEncoder a, HasEncoder b) => HasEncoder (Tuple2 a b) where
  encoder = Linear.do
      a <- encoder
      b <- encoder
      tuple2 a b
