{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

{-# OPTIONS_GHC -fno-warn-orphans -Wno-redundant-constraints #-}
{-# OPTIONS_GHC -fplugin=Language.Java.Inline.Plugin #-}

module Control.Distributed.Spark.SQL.Encoder
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

import Control.Distributed.Spark.SQL.Row
import Control.Distributed.Spark.SQL.StructType

import qualified Data.Coerce
import Data.Constraint (Dict(Dict))
import Data.Int
import Data.Singletons (SingI)
import Data.Text (Text)

import Language.Java
import Language.Java.Inline (java)
import Language.Scala.Tuple
import Foreign.JNI
import System.IO.Unsafe (unsafePerformIO)

newtype Encoder a = Encoder (J ('Iface "org.apache.spark.sql.Encoder"))
  deriving (Coercible, Interpretation)

{-# NOINLINE long #-}
long :: Encoder Int64
long = unsafePerformIO $
    withLocalRef [java| org.apache.spark.sql.Encoders.LONG() |]
                 newGlobalRefNonFinalized

{-# NOINLINE string #-}
string :: Encoder Text
string = unsafePerformIO $
    withLocalRef [java| org.apache.spark.sql.Encoders.STRING() |]
                 newGlobalRefNonFinalized

{-# NOINLINE int #-}
int :: Encoder Int32
int = unsafePerformIO $
    withLocalRef [java| org.apache.spark.sql.Encoders.INT() |]
                 newGlobalRefNonFinalized

{-# NOINLINE short #-}
short :: Encoder Int16
short = unsafePerformIO $
    withLocalRef [java| org.apache.spark.sql.Encoders.SHORT() |]
                 newGlobalRefNonFinalized

{-# NOINLINE boolean #-}
boolean :: Encoder Bool
boolean = unsafePerformIO $
    withLocalRef [java| org.apache.spark.sql.Encoders.BOOLEAN() |]
                  newGlobalRefNonFinalized

{-# NOINLINE float #-}
float :: Encoder Float
float = unsafePerformIO $
    withLocalRef [java| org.apache.spark.sql.Encoders.FLOAT() |]
                 newGlobalRefNonFinalized

{-# NOINLINE double #-}
double :: Encoder Double
double = unsafePerformIO $
    withLocalRef [java| org.apache.spark.sql.Encoders.DOUBLE() |]
                newGlobalRefNonFinalized

tuple2 :: Encoder a -> Encoder b -> IO (Encoder (Tuple2 a b))
tuple2 ea eb = [java| org.apache.spark.sql.Encoders.tuple($ea, $eb) |]

javaSerialization :: forall a ty. (Interp a ~ ty, SingI ty, IsReferenceType ty)
                  => IO (Encoder a)
javaSerialization = do
    cls <- findClass (referenceTypeName (sing :: Sing ty))
    [java| org.apache.spark.sql.Encoders.javaSerialization($cls) |]

kryo :: forall a ty. (Interp a ~ ty, SingI ty, IsReferenceType ty)
     => IO (Encoder a)
kryo = do
    cls <- findClass (referenceTypeName (sing :: Sing ty))
    [java| org.apache.spark.sql.Encoders.kryo($cls) |]

coerceEncoder :: forall a b . Interp a ~ Interp b => Encoder a -> Encoder b
coerceEncoder = Data.Coerce.coerce
  where
    _ = Dict @(Interp a ~ Interp b)

getRowEncoder :: StructType -> IO (Encoder Row)
getRowEncoder st =
    [java| org.apache.spark.sql.catalyst.encoders.RowEncoder.apply($st) |]

-- | Class of types which have encoders
class HasEncoder a where
  encoder :: IO (Encoder a)

instance HasEncoder Int64 where
  encoder = newLocalRef long

instance HasEncoder Text where
  encoder = newLocalRef string

instance HasEncoder Float where
  encoder = newLocalRef float

instance HasEncoder Double where
  encoder = newLocalRef double

instance HasEncoder Int32 where
  encoder = newLocalRef int

instance HasEncoder Int16 where
  encoder = newLocalRef short

instance HasEncoder Bool where
  encoder = newLocalRef boolean

instance (HasEncoder a, HasEncoder b) => HasEncoder (Tuple2 a b) where
  encoder = do
      a <- encoder
      b <- encoder
      tuple2 a b
