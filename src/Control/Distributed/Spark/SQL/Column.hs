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
import Data.Int (Int32)
import Data.Text (Text)
import Foreign.JNI (deleteLocalRef)
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

manyToOne :: Foreign.JNI.String.String -> [Column] -> IO Column
manyToOne fname colexprs = do
    arr <- toArray (Data.Coerce.coerce colexprs :: [J ('Class "org.apache.spark.sql.Column")])
    callStaticSqlFun fname arr <* deleteLocalRef arr

lit :: Reflect a => a -> IO Column
lit x =  do
  c <- upcast <$> reflect x  -- @upcast@ needed to land in java Object
  callStaticSqlFun "lit" c <* deleteLocalRef c

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

approx_count_distinct :: Column -> IO Column
approx_count_distinct = callStaticSqlFun "approx_count_distinct"

count :: Column -> IO Column
count = callStaticSqlFun "count"

countDistinct :: Column -> IO Column
countDistinct = callStaticSqlFun "countDistinct"

min :: Column -> IO Column
min = callStaticSqlFun "min"

mean :: Column -> IO Column
mean = callStaticSqlFun "mean"

variance :: Column -> IO Column
variance = callStaticSqlFun "variance"

var_pop :: Column -> IO Column
var_pop = callStaticSqlFun "var_pop"

var_samp :: Column -> IO Column
var_samp = callStaticSqlFun "var_samp"

corr :: Column -> Column -> IO Column
corr = callStaticSqlFun "corr"

covar_pop :: Column -> Column -> IO Column
covar_pop = callStaticSqlFun "covar_pop"

covar_samp :: Column -> Column -> IO Column
covar_samp = callStaticSqlFun "covar_samp"

max :: Column -> IO Column
max = callStaticSqlFun "max"

not :: Column -> IO Column
not = callStaticSqlFun "not"

negate :: Column -> IO Column
negate = callStaticSqlFun "negate"

signum :: Column -> IO Column
signum = callStaticSqlFun "signum"

kurtosis :: Column -> IO Column
kurtosis = callStaticSqlFun "kurtosis"

skewness :: Column -> IO Column
skewness = callStaticSqlFun "skewness"

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

add_months :: Column -> Int32 -> IO Column
add_months = callStaticSqlFun "add_months"

current_timestamp :: IO Column
current_timestamp = callStaticSqlFun "current_timestamp"

date_add :: Column -> Int32 -> IO Column
date_add = callStaticSqlFun "date_add"

datediff :: Column -> Column -> IO Column
datediff = callStaticSqlFun "datediff"

date_format :: Column -> Text -> IO Column
date_format col format = do
    jFormat <- reflect format
    callStaticSqlFun "date_format" col jFormat <* deleteLocalRef jFormat

date_sub :: Column -> Int32 -> IO Column
date_sub = callStaticSqlFun "date_sub"

second :: Column -> IO Column
second = callStaticSqlFun "second"

minute :: Column -> IO Column
minute = callStaticSqlFun "minute"

hour :: Column -> IO Column
hour = callStaticSqlFun "hour"

dayofmonth :: Column -> IO Column
dayofmonth = callStaticSqlFun "dayofmonth"

dayofyear :: Column -> IO Column
dayofyear = callStaticSqlFun "dayofyear"

last_day :: Column -> IO Column
last_day = callStaticSqlFun "last_day"

month :: Column -> IO Column
month = callStaticSqlFun "month"

year :: Column -> IO Column
year = callStaticSqlFun "year"

months_between :: Column -> Column -> IO Column
months_between = callStaticSqlFun "months_between"

next_day :: Column -> Text -> IO Column
next_day col dayOfWeek = do
    jDayOfWeek <- reflect dayOfWeek
    callStaticSqlFun "next_day" col jDayOfWeek <* deleteLocalRef jDayOfWeek

quarter :: Column -> IO Column
quarter = callStaticSqlFun "quarter"

to_date :: Column -> IO Column
to_date = callStaticSqlFun "to_date"

from_unixtime :: Column -> Text -> IO Column
from_unixtime col format = do
    jFormat <- reflect format
    callStaticSqlFun "from_unixtime" col jFormat <* deleteLocalRef jFormat

from_utc_timestamp :: Column -> Text -> IO Column
from_utc_timestamp col tz = do
    jTz <- reflect tz
    callStaticSqlFun "from_utc_timestamp" col jTz <* deleteLocalRef jTz

to_utc_timestamp :: Column -> Text -> IO Column
to_utc_timestamp col tz = do
    jTz <- reflect tz
    callStaticSqlFun "to_utc_timestamp" col jTz <* deleteLocalRef jTz

trunc :: Column -> Text -> IO Column
trunc col res = do
    jRes <- reflect res
    callStaticSqlFun "trunc" col jRes <* deleteLocalRef jRes

unix_timestamp :: Column -> Maybe (Text) -> IO Column
unix_timestamp col (Just format) = do
    jFormat <- reflect format
    callStaticSqlFun "unix_timestamp" col jFormat <* deleteLocalRef jFormat
unix_timestamp col Nothing =
    callStaticSqlFun "unix_timestamp" col

weekofyear :: Column -> IO Column
weekofyear = callStaticSqlFun "weekofyear"

current_date :: IO Column
current_date = callStaticSqlFun "current_date"

atan :: Column -> IO Column
atan = callStaticSqlFun "atan"

asin :: Column -> IO Column
asin = callStaticSqlFun "asin"

acos :: Column -> IO Column
acos = callStaticSqlFun "acos"

cbrt :: Column -> IO Column
cbrt = callStaticSqlFun "cbrt"

cos :: Column -> IO Column
cos = callStaticSqlFun "cos"

cosh :: Column -> IO Column
cosh = callStaticSqlFun "cosh"

degrees :: Column -> IO Column
degrees = callStaticSqlFun "degrees"

pow :: Column -> Column -> IO Column
pow = callStaticSqlFun "pow"

exp :: Column -> IO Column
exp = callStaticSqlFun "exp"

expm1 :: Column -> IO Column
expm1 = callStaticSqlFun "expm1"

hypot :: Column -> IO Column
hypot = callStaticSqlFun "hypot"

log :: Column -> IO Column
log = callStaticSqlFun "log"

log10 :: Column -> IO Column
log10 = callStaticSqlFun "log10"

log1p :: Column -> IO Column
log1p = callStaticSqlFun "log1p"

isnull :: Column -> IO Column
isnull = callStaticSqlFun "isnull"

radians :: Column -> IO Column
radians = callStaticSqlFun "radians"

sin :: Column -> IO Column
sin = callStaticSqlFun "sin"

sinh :: Column -> IO Column
sinh = callStaticSqlFun "sinh"

tan :: Column -> IO Column
tan = callStaticSqlFun "tan"

tanh :: Column -> IO Column
tanh = callStaticSqlFun "tanh"

coalesce :: [Column] -> IO Column
coalesce = manyToOne "coalesce"

array :: [Column] -> IO Column
array = manyToOne "array"

expr :: Text -> IO Column
expr e = do
  jexpr <- reflect e
  callStaticSqlFun "expr" jexpr <* deleteLocalRef jexpr

greatest :: [Column] -> IO Column
greatest = manyToOne "greatest"

least :: [Column] -> IO Column
least = manyToOne "least"

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
  call col "cast" jdestType <* deleteLocalRef jdestType

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

-- String functions

ascii :: Column -> IO Column
ascii = callStaticSqlFun "ascii"

concat :: [Column] -> IO Column
concat = manyToOne "concat"

concat_ws :: Text -> [Column] -> IO Column
concat_ws sep colexprs = do
    jSep <- reflect sep
    arrCols <- toArray (Data.Coerce.coerce colexprs :: [J ('Class "org.apache.spark.sql.Column")])
    callStaticSqlFun "concat_ws" jSep arrCols <* deleteLocalRef jSep <* deleteLocalRef arrCols

format_string :: Text -> [Column] -> IO Column
format_string format arguments = do
    jFormat <- reflect format
    arrCols <- toArray (Data.Coerce.coerce arguments :: [J ('Class "org.apache.spark.sql.Column")])
    callStaticSqlFun "format_string" jFormat arrCols <* deleteLocalRef jFormat <* deleteLocalRef arrCols

initcap :: Column -> IO Column
initcap = callStaticSqlFun "initcap"

instr :: Column -> Text -> IO Column
instr col substr = do
    jSubstring <- reflect substr
    callStaticSqlFun "instr" col jSubstring <* deleteLocalRef jSubstring

length :: Column -> IO Column
length = callStaticSqlFun "length"

levenshtein :: Column -> Column -> IO Column
levenshtein = callStaticSqlFun "levenshtein"

locate :: Text -> Column -> Maybe Int32 -> IO Column
locate substr str maybePos = do
    jSubstr <- reflect substr
    case maybePos of
      Nothing  -> callStaticSqlFun "locate" jSubstr str <* deleteLocalRef jSubstr
      Just pos -> callStaticSqlFun "locate" jSubstr str pos <* deleteLocalRef jSubstr

lower :: Column -> IO Column
lower = callStaticSqlFun "lower"

lpad :: Column -> Int32 -> Text -> IO Column
lpad str len pad = do
    jPad <- reflect pad
    callStaticSqlFun "lpad" str len jPad <* deleteLocalRef jPad

ltrim :: Column -> IO Column
ltrim = callStaticSqlFun "ltrim"

repeat :: Column -> Int32 -> IO Column
repeat = callStaticSqlFun "repeat"

reverse :: Column -> IO Column
reverse = callStaticSqlFun "reverse"

rpadCol :: Column -> Int32 -> Text -> IO Column
rpadCol str len pad = do
    jPad <- reflect pad
    callStaticSqlFun "rpad" str len jPad <* deleteLocalRef jPad

rtrim :: Column -> IO Column
rtrim = callStaticSqlFun "rtrim"

substring :: Column -> Int32 -> Int32 -> IO Column
substring = callStaticSqlFun "substring"

substring_index :: Column -> Text -> Int32 -> IO Column
substring_index str delim count_c = do
    jDelim <- reflect delim
    callStaticSqlFun "substring_index" str jDelim count_c <* deleteLocalRef jDelim

translate :: Column -> Text -> Text -> IO Column
translate str from to = do
    jFrom <- reflect from
    jTo <- reflect to
    callStaticSqlFun "translate" str jFrom jTo <* deleteLocalRef jFrom <* deleteLocalRef jTo

trim :: Column -> IO Column
trim = callStaticSqlFun "trim"

upper :: Column -> IO Column
upper = callStaticSqlFun "upper"

soundex :: Column -> IO Column
soundex = callStaticSqlFun "soundex"

regexp_extract :: Column -> Text -> Int32 -> IO Column
regexp_extract str pat group = do
    p <- reflect pat
    callStaticSqlFun "regexp_extract" str p group <* deleteLocalRef p

regexp_replace :: Column -> Text -> Text -> IO Column
regexp_replace str pat replace = do
    p <- reflect pat
    rep <- reflect replace
    callStaticSqlFun "regexp_replace" str p rep <* deleteLocalRef p <* deleteLocalRef rep

-- Window functions

last :: Column -> IO Column
last = callStaticSqlFun "last"

first :: Column -> IO Column
first = callStaticSqlFun "first"

lead :: Column -> Int32 -> IO Column
lead = callStaticSqlFun "lead"

lag :: Column -> Int32 -> IO Column
lag = callStaticSqlFun "lag"
