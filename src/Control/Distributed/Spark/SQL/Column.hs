-- | Bindings for
-- <https://spark.apache.org/docs/latest/api/java/org/apache/spark/sql/Column.html org.apache.spark.sql.Column>.
--
-- This module is intended to be imported qualified.

{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module Control.Distributed.Spark.SQL.Column where

import Control.Monad (foldM)
import qualified Data.Coerce
import Data.Text (Text)
import qualified Foreign.JNI.String
import Language.Java
import Prelude hiding (min, max, mod, and, or, otherwise)

newtype Column = Column (J ('Class "org.apache.spark.sql.Column"))
  deriving (Coercible, Interpretation, Reflect, Reify)

newtype GroupedData =
    GroupedData (J ('Class "org.apache.spark.sql.RelationalGroupedDataset"))
  deriving (Coercible, Interpretation, Reflect, Reify)

alias :: Column -> Text -> IO Column
alias c n = do
  colName <- reflect n
  call c "alias" colName

callStaticSqlFun
  :: (Coercible a, VariadicIO f a) => Foreign.JNI.String.String -> f
callStaticSqlFun = callStatic "org.apache.spark.sql.functions"

lit :: Reflect a => a -> IO Column
lit x =  do
  c <- upcast <$> reflect x  -- @upcast@ needed to land in java Object
  callStaticSqlFun "lit" c

plus :: Column -> Column -> IO Column
plus col1 (Column col2) = call col1 "plus" (upcast col2)

minus :: Column -> Column -> IO Column
minus col1 (Column col2) = call col1 "minus" (upcast col2)

multiply :: Column -> Column -> IO Column
multiply col1 (Column col2) = call col1 "multiply" (upcast col2)

divide :: Column -> Column -> IO Column
divide col1 (Column col2) = call col1 "divide" (upcast col2)

mod :: Column -> Column -> IO Column
mod col1 (Column col2) = call col1 "mod" (upcast col2)

equalTo :: Column -> Column -> IO Column
equalTo col1 (Column col2) = call col1 "equalTo" (upcast col2)

notEqual :: Column -> Column -> IO Column
notEqual col1 (Column col2) = call col1 "notEqual" (upcast col2)

leq :: Column -> Column -> IO Column
leq col1 (Column col2) = call col1 "leq" (upcast col2)

lt :: Column -> Column -> IO Column
lt col1 (Column col2) = call col1 "lt" (upcast col2)

geq :: Column -> Column -> IO Column
geq col1 (Column col2) = call col1 "geq" (upcast col2)

gt :: Column -> Column -> IO Column
gt col1 (Column col2) = call col1 "gt" (upcast col2)

and :: Column -> Column -> IO Column
and col1 (Column col2) = call col1 "and" col2

or :: Column -> Column -> IO Column
or col1 = call col1 "or"

min :: Column -> IO Column
min = callStaticSqlFun "min"

mean :: Column -> IO Column
mean = callStaticSqlFun "mean"

max :: Column -> IO Column
max = callStaticSqlFun "max"

not :: Column -> IO Column
not = callStaticSqlFun "not"

negate :: Column -> IO Column
negate = callStaticSqlFun "negate"

signum :: Column -> IO Column
signum = callStaticSqlFun "signum"

abs :: Column -> IO Column
abs = callStaticSqlFun "abs"

sqrt :: Column -> IO Column
sqrt = callStaticSqlFun "sqrt"

floor :: Column -> IO Column
floor = callStaticSqlFun "floor"

ceil :: Column -> IO Column
ceil = callStaticSqlFun "ceil"

round :: Column -> IO Column
round = callStaticSqlFun "round"

second :: Column -> IO Column
second = callStaticSqlFun "second"

minute :: Column -> IO Column
minute = callStaticSqlFun "minute"

hour :: Column -> IO Column
hour = callStaticSqlFun "hour"

dayofmonth :: Column -> IO Column
dayofmonth = callStaticSqlFun "dayofmonth"

month :: Column -> IO Column
month = callStaticSqlFun "month"

year :: Column -> IO Column
year = callStaticSqlFun "year"

current_timestamp :: IO Column
current_timestamp = callStaticSqlFun "current_timestamp"

current_date :: IO Column
current_date = callStaticSqlFun "current_date"

pow :: Column -> Column -> IO Column
pow = callStaticSqlFun "pow"

exp :: Column -> IO Column
exp = callStaticSqlFun "exp"

expm1 :: Column -> IO Column
expm1 = callStaticSqlFun "expm1"

log :: Column -> IO Column
log = callStaticSqlFun "log"

log1p :: Column -> IO Column
log1p = callStaticSqlFun "log1p"

isnull :: Column -> IO Column
isnull = callStaticSqlFun "isnull"

coalesce :: [Column] -> IO Column
coalesce colexprs = do
  jcols <- toArray (Data.Coerce.coerce colexprs
             :: [J ('Class "org.apache.spark.sql.Column")])
  callStaticSqlFun "coalesce" jcols

array :: [Column] -> IO Column
array colexprs = do
  jcols <- toArray (Data.Coerce.coerce colexprs
             :: [J ('Class "org.apache.spark.sql.Column")])
  callStaticSqlFun "array" jcols

expr :: Text -> IO Column
expr e = do
  jexpr <- reflect e
  callStaticSqlFun "expr" jexpr

-- | From the Spark docs:
--
-- Casts the column to a different data type, using the
-- canonical string representation of the type.
--
-- The supported types are: string, boolean, byte, short,
-- int, long, float, double, decimal, date, timestamp.
cast :: Column -> Text -> IO Column
cast col destType = do
  jdestType <- reflect destType
  call col "cast" jdestType

-- | 'when', 'orWhen' and 'otherwise' are designed to be used
-- together to make if-then-else and more generally mutli-way if branches:
-- start with 'when', use as many extra 'orWhen' as needed and finish
-- with an 'otherwise'.
--
-- NULL values are produced if none of the conditions hold and a
-- value is not specified with 'otherwise'.
when :: Column -> Column -> IO Column
when cond (Column val) =
  callStaticSqlFun "when" cond (upcast val)

orWhen :: Column -> Column -> Column -> IO Column
orWhen chain cond (Column val) =
  call chain "when" cond (upcast val)

otherwise :: Column -> Column -> IO Column
otherwise chain (Column val) =
  call chain "otherwise" (upcast val)

-- | @if c then e1 else e2@
--
-- This is just a combination of 'when' and 'otherwise'.
ifThenElse :: Column -> Column -> Column -> IO Column
ifThenElse c e1 e2 = when c e1 >>= (`otherwise` e2)

-- | @if c1 then e1 elseif c2 then e2 ... else def@
--
-- This is just a combination of 'when', 'orWhen' and 'otherwise'.
multiwayIf :: [(Column, Column)] -> Column -> IO Column
multiwayIf [] def = return def
multiwayIf ((c1, e1):cases0) def =
      when c1 e1
  >>= flip (foldM (uncurry . orWhen)) cases0
  >>= (`otherwise` def)
