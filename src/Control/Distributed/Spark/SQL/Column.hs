-- | Bindings for
-- <https://spark.apache.org/docs/latest/api/java/org/apache/spark/sql/Column.html org.apache.spark.sql.Column>.
--
-- This module is intended to be imported qualified.

{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}

module Control.Distributed.Spark.SQL.Column where

import Control.Monad (foldM)
import qualified Data.Coerce
import Data.Text (Text)
import qualified Foreign.JNI.String
import Language.Java
import Prelude hiding (min, max, mod, and, or, otherwise)

newtype Column = Column (J ('Class "org.apache.spark.sql.Column"))
instance Coercible Column ('Class "org.apache.spark.sql.Column")

type instance Interp Column = 'Class "org.apache.spark.sql.Column"

newtype GroupedData = GroupedData (J ('Class "org.apache.spark.sql.GroupedData"))
instance Coercible GroupedData ('Class "org.apache.spark.sql.GroupedData")

alias :: Column -> Text -> IO Column
alias c n = do
  colName <- reflect n
  call c "alias" [coerce colName]

callStaticSqlFun :: Coercible a ty
                 => Foreign.JNI.String.String -> [JValue] -> IO a
callStaticSqlFun = callStatic "org.apache.spark.sql.functions"

lit :: Reflect a => a -> IO Column
lit a = reflect a >>= litCoercible

litCoercible :: (Coercible a ty, IsReferenceType ty) => a -> IO Column
litCoercible a = case coerce a of
    JObject j -> callStaticSqlFun "lit" [JObject (upcast j)]
    _ -> error "unexpected argument"

plus :: Column -> Column -> IO Column
plus col1 (Column col2) = call col1 "plus" [coerce $ upcast col2]

minus :: Column -> Column -> IO Column
minus col1 (Column col2) = call col1 "minus" [coerce $ upcast col2]

multiply :: Column -> Column -> IO Column
multiply col1 (Column col2) = call col1 "multiply" [coerce $ upcast col2]

divide :: Column -> Column -> IO Column
divide col1 (Column col2) = call col1 "divide" [coerce $ upcast col2]

mod :: Column -> Column -> IO Column
mod col1 (Column col2) = call col1 "mod" [coerce $ upcast col2]

equalTo :: Column -> Column -> IO Column
equalTo col1 (Column col2) = call col1 "equalTo" [coerce $ upcast col2]

notEqual :: Column -> Column -> IO Column
notEqual col1 (Column col2) = call col1 "notEqual" [coerce $ upcast col2]

leq :: Column -> Column -> IO Column
leq col1 (Column col2) = call col1 "leq" [coerce $ upcast col2]

lt :: Column -> Column -> IO Column
lt col1 (Column col2) = call col1 "lt" [coerce $ upcast col2]

geq :: Column -> Column -> IO Column
geq col1 (Column col2) = call col1 "geq" [coerce $ upcast col2]

gt :: Column -> Column -> IO Column
gt col1 (Column col2) = call col1 "gt" [coerce $ upcast col2]

and :: Column -> Column -> IO Column
and col1 (Column col2) = call col1 "and" [coerce col2]

or :: Column -> Column -> IO Column
or col1 (Column col2) = call col1 "or" [coerce col2]

min :: Column -> IO Column
min c = callStaticSqlFun "min" [coerce c]

mean :: Column -> IO Column
mean c = callStaticSqlFun "mean" [coerce c]

max :: Column -> IO Column
max c = callStaticSqlFun "max" [coerce c]

not :: Column -> IO Column
not col = callStaticSqlFun "not" [coerce col]

negate :: Column -> IO Column
negate col = callStaticSqlFun "negate" [coerce col]

signum :: Column -> IO Column
signum col = callStaticSqlFun "signum" [coerce col]

abs :: Column -> IO Column
abs col = callStaticSqlFun "abs" [coerce col]

sqrt :: Column -> IO Column
sqrt col = callStaticSqlFun "sqrt" [coerce col]

floor :: Column -> IO Column
floor col = callStaticSqlFun "floor" [coerce col]

ceil :: Column -> IO Column
ceil col = callStaticSqlFun "ceil" [coerce col]

round :: Column -> IO Column
round col = callStaticSqlFun "round" [coerce col]

second :: Column -> IO Column
second col = callStaticSqlFun "second" [coerce col]

minute :: Column -> IO Column
minute col = callStaticSqlFun "minute" [coerce col]

hour :: Column -> IO Column
hour col = callStaticSqlFun "hour" [coerce col]

dayofmonth :: Column -> IO Column
dayofmonth col = callStaticSqlFun "dayofmonth" [coerce col]

month :: Column -> IO Column
month col = callStaticSqlFun "month" [coerce col]

year :: Column -> IO Column
year col = callStaticSqlFun "year" [coerce col]

current_timestamp :: IO Column
current_timestamp = callStaticSqlFun "current_timestamp" []

current_date :: IO Column
current_date = callStaticSqlFun "current_date" []

pow :: Column -> Column -> IO Column
pow col1 col2 = callStaticSqlFun "pow" [coerce col1, coerce col2]

exp :: Column -> IO Column
exp col1 = callStaticSqlFun "exp" [coerce col1]

expm1 :: Column -> IO Column
expm1 col = callStaticSqlFun "expm1" [coerce col]

log :: Column -> IO Column
log col = callStaticSqlFun "log" [coerce col]

log1p :: Column -> IO Column
log1p col = callStaticSqlFun "log1p" [coerce col]

isnull :: Column -> IO Column
isnull col = callStaticSqlFun "isnull" [coerce col]

coalesce :: [Column] -> IO Column
coalesce colexprs = do
  jcols <- toArray (Data.Coerce.coerce colexprs
             :: [J ('Class "org.apache.spark.sql.Column")])
  callStaticSqlFun "coalesce" [coerce jcols]

array :: [Column] -> IO Column
array colexprs = do
  jcols <- toArray (Data.Coerce.coerce colexprs
             :: [J ('Class "org.apache.spark.sql.Column")])
  callStaticSqlFun "array" [coerce jcols]

expr :: Text -> IO Column
expr e = do
  jexpr <- reflect e
  callStaticSqlFun "expr" [coerce jexpr]

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
  call col "cast" [coerce jdestType]

-- | 'when', 'orWhen' and 'otherwise' are designed to be used
-- together to make if-then-else and more generally mutli-way if branches:
-- start with 'when', use as many extra 'orWhen' as needed and finish
-- with an 'otherwise'.
--
-- NULL values are produced if none of the conditions hold and a
-- value is not specified with 'otherwise'.
when :: Column -> Column -> IO Column
when cond (Column val) =
  callStaticSqlFun "when" [coerce cond, coerce (upcast val)]

orWhen :: Column -> Column -> Column -> IO Column
orWhen chain cond (Column val) =
  call chain "when" [coerce cond, coerce (upcast val)]

otherwise :: Column -> Column -> IO Column
otherwise chain (Column val) =
  call chain "otherwise" [coerce (upcast val)]

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
