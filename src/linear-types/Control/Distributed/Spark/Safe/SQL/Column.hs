-- | Bindings for
-- <https://spark.apache.org/docs/latest/api/java/org/apache/spark/sql/Column.html org.apache.spark.sql.Column>.
--
-- This module is intended to be imported qualified.

{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LinearTypes #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module Control.Distributed.Spark.Safe.SQL.Column where

import Prelude.Linear hiding (IO, min, max, mod, and, or, otherwise)
import System.IO.Linear as LIO
import Control.Functor.Linear as Linear
import Control.Monad.IO.Class.Linear
--
import Data.Int (Int32)
import Data.Text (Text)
import qualified Foreign.JNI.String
import Language.Java.Safe
import qualified Language.Java
import Foreign.JNI.Safe

-- QUESTION: Do we actually need interp, reflect, reify instances? 
newtype Column = Column (J ('Class "org.apache.spark.sql.Column"))
  deriving (Coercible)
  -- deriving (Coercible, Interpretation, Reflect, Reify)

-- Project out reference
unColumn :: Column %1 -> J ('Class "org.apache.spark.sql.Column")
unColumn (Column j) = j

newtype GroupedData =
    GroupedData (J ('Class "org.apache.spark.sql.RelationalGroupedDataset"))
  deriving (Coercible)
  -- deriving (Coercible, Interpretation, Reflect, Reify)

alias :: Column %1 -> Text -> IO Column
alias c n = Linear.do
  colName <- reflect n
  call c "alias" colName End

callStaticSqlFun
  :: (Coercible a, MonadIO m, Variadic f (m a)) => Foreign.JNI.String.String -> f
callStaticSqlFun = callStatic "org.apache.spark.sql.functions"

manyToOne :: Foreign.JNI.String.String -> [Column] %1 -> IO Column
manyToOne fname colexprs =
  toArray (map unColumn colexprs :: [J ('Class "org.apache.spark.sql.Column")])
      >>= \(refs, arr) -> foldM (\() -> deleteLocalRef) () refs 
        >> callStaticSqlFun fname arr End

lit :: Reflect a => a -> IO Column
lit x =  -- @upcast@ needed to land in java Object
  (upcast <$> reflect x) >>= \jx -> callStaticSqlFun "lit" jx End

plus :: Column %1 -> Column %1 -> IO Column
plus col1 (Column col2) = call col1 "plus" (upcast col2) End

minus :: Column %1 -> Column %1 -> IO Column
minus col1 (Column col2) = call col1 "minus" (upcast col2) End

multiply :: Column %1 -> Column %1 -> IO Column
multiply col1 (Column col2) = call col1 "multiply" (upcast col2) End

divide :: Column %1 -> Column %1 -> IO Column
divide col1 (Column col2) = call col1 "divide" (upcast col2) End

mod :: Column %1 -> Column %1 -> IO Column
mod col1 (Column col2) = call col1 "mod" (upcast col2) End

equalTo :: Column %1 -> Column %1 -> IO Column
equalTo col1 (Column col2) = call col1 "equalTo" (upcast col2) End

notEqual :: Column %1 -> Column %1 -> IO Column
notEqual col1 (Column col2) = call col1 "notEqual" (upcast col2) End

leq :: Column %1 -> Column %1 -> IO Column
leq col1 (Column col2) = call col1 "leq" (upcast col2) End

lt :: Column %1 -> Column %1 -> IO Column
lt col1 (Column col2) = call col1 "lt" (upcast col2) End

geq :: Column %1 -> Column %1 -> IO Column
geq col1 (Column col2) = call col1 "geq" (upcast col2) End

gt :: Column %1 -> Column %1 -> IO Column
gt col1 (Column col2) = call col1 "gt" (upcast col2) End

and :: Column %1 -> Column %1 -> IO Column
and col1 (Column col2) = call col1 "and" col2 End

or :: Column %1 -> Column %1 -> IO Column
or col1 (Column col2) = call col1 "or" col2 End

approx_count_distinct :: Column %1 -> IO Column
approx_count_distinct col = callStaticSqlFun "approx_count_distinct" col End

count :: Column %1 -> IO Column
count col = callStaticSqlFun "count" col End

countDistinct :: Column %1 -> IO Column
countDistinct col = callStaticSqlFun "countDistinct" col End

min :: Column %1 -> IO Column
min col = callStaticSqlFun "min" col End

mean :: Column %1 -> IO Column
mean col = callStaticSqlFun "mean" col End

variance :: Column %1 -> IO Column
variance col = callStaticSqlFun "variance" col End

var_pop :: Column %1 -> IO Column
var_pop col = callStaticSqlFun "var_pop" col End

var_samp :: Column %1 -> IO Column
var_samp col = callStaticSqlFun "var_samp" col End

corr :: Column %1 -> Column %1 -> IO Column
corr col1 col2 = callStaticSqlFun "corr" col1 col2 End

covar_pop :: Column %1 -> Column %1 -> IO Column
covar_pop col1 col2 = callStaticSqlFun "covar_pop" col1 col2 End

covar_samp :: Column %1 -> Column %1 -> IO Column
covar_samp col1 col2 = callStaticSqlFun "covar_samp" col1 col2 End

max :: Column %1 -> IO Column
max col = callStaticSqlFun "max" col End

not :: Column %1 -> IO Column
not col = callStaticSqlFun "not" col End

negate :: Column %1 -> IO Column
negate col = callStaticSqlFun "negate" col End

signum :: Column %1 -> IO Column
signum col = callStaticSqlFun "signum" col End

kurtosis :: Column %1 -> IO Column
kurtosis col = callStaticSqlFun "kurtosis" col End

skewness :: Column %1 -> IO Column
skewness col = callStaticSqlFun "skewness" col End

abs :: Column %1 -> IO Column
abs col = callStaticSqlFun "abs" col End

sqrt :: Column %1 -> IO Column
sqrt col = callStaticSqlFun "sqrt" col End

floor :: Column %1 -> IO Column
floor col = callStaticSqlFun "floor" col End

ceil :: Column %1 -> IO Column
ceil col = callStaticSqlFun "ceil" col End

round :: Column %1 -> IO Column
round col = callStaticSqlFun "round" col End

add_months :: Column %1 -> Int32 -> IO Column
add_months startDate months = 
  reflect months >>= \jmonths ->
    callStaticSqlFun "add_months" startDate jmonths End

current_timestamp :: IO Column
current_timestamp = callStaticSqlFun "current_timestamp" End

date_add :: Column %1 -> Int32 -> IO Column
date_add start days = 
  reflect days >>= \jdays ->
    callStaticSqlFun "date_add" start jdays End

datediff :: Column %1 -> Column %1 -> IO Column
datediff start end = callStaticSqlFun "datediff" start end End

date_format :: Column %1 -> Text -> IO Column
date_format col format =
  reflect format >>= \jformat -> callStaticSqlFun "date_format" col jformat End

date_sub :: Column %1 -> Int32 -> IO Column
date_sub start days = 
  reflect days >>= \jdays ->
    callStaticSqlFun "date_sub" start jdays End

second :: Column %1 -> IO Column
second col = callStaticSqlFun "second" col End

minute :: Column %1 -> IO Column
minute col = callStaticSqlFun "minute" col End

hour :: Column %1 -> IO Column
hour col = callStaticSqlFun "hour" col End

dayofmonth :: Column %1 -> IO Column
dayofmonth col = callStaticSqlFun "dayofmonth" col End

dayofyear :: Column %1 -> IO Column
dayofyear col = callStaticSqlFun "dayofyear" col End

last_day :: Column %1 -> IO Column
last_day col = callStaticSqlFun "last_day" col End

month :: Column %1 -> IO Column
month col = callStaticSqlFun "month" col End

year :: Column %1 -> IO Column
year col = callStaticSqlFun "year" col End

months_between :: Column %1 -> Column %1 -> IO Column
months_between end start = callStaticSqlFun "months_between" end start End

next_day :: Column %1 -> Text -> IO Column
next_day col dayOfWeek =
  reflect dayOfWeek >>= \jday -> callStaticSqlFun "next_day" col jday End

quarter :: Column %1 -> IO Column
quarter col = callStaticSqlFun "quarter" col End

to_date :: Column %1 -> IO Column
to_date col = callStaticSqlFun "to_date" col End

from_unixtime :: Column %1 -> Text -> IO Column
from_unixtime col format =
  reflect format >>= \jformat -> callStaticSqlFun "from_unixtime" col jformat End

from_utc_timestamp :: Column %1 -> Text -> IO Column
from_utc_timestamp col tz =
  reflect tz >>= \jtz -> callStaticSqlFun "from_utc_timestamp" col jtz End

to_utc_timestamp :: Column %1 -> Text -> IO Column
to_utc_timestamp col tz =
  reflect tz >>= \jtz -> callStaticSqlFun "to_utc_timestamp" col jtz End

trunc :: Column %1 -> Text -> IO Column
trunc col res =
  reflect res >>= \jres -> callStaticSqlFun "trunc" col jres End

unix_timestamp :: Column %1 -> Maybe Text -> IO Column
unix_timestamp col (Just format) =
  reflect format >>= \jformat -> callStaticSqlFun "unix_timestamp" col jformat End
unix_timestamp col Nothing =
    callStaticSqlFun "unix_timestamp" col End

weekofyear :: Column %1 -> IO Column
weekofyear col = callStaticSqlFun "weekofyear" col End

current_date :: IO Column
current_date = callStaticSqlFun "current_date" End

atan :: Column %1 -> IO Column
atan col = callStaticSqlFun "atan" col End

asin :: Column %1 -> IO Column
asin col = callStaticSqlFun "asin" col End

acos :: Column %1 -> IO Column
acos col = callStaticSqlFun "acos" col End

cbrt :: Column %1 -> IO Column
cbrt col = callStaticSqlFun "cbrt" col End

cos :: Column %1 -> IO Column
cos col = callStaticSqlFun "cos" col End

cosh :: Column %1 -> IO Column
cosh col = callStaticSqlFun "cosh" col End

degrees :: Column %1 -> IO Column
degrees col = callStaticSqlFun "degrees" col End

pow :: Column %1 -> Column %1 -> IO Column
pow col1 col2 = callStaticSqlFun "pow" col1 col2 End

exp :: Column %1 -> IO Column
exp col = callStaticSqlFun "exp" col End

expm1 :: Column %1 -> IO Column
expm1 col = callStaticSqlFun "expm1" col End

hypot :: Column %1 -> IO Column
hypot col = callStaticSqlFun "hypot" col End

log :: Column %1 -> IO Column
log col = callStaticSqlFun "log" col End

log10 :: Column %1 -> IO Column
log10 col = callStaticSqlFun "log10" col End

log1p :: Column %1 -> IO Column
log1p col = callStaticSqlFun "log1p" col End

isnull :: Column %1 -> IO Column
isnull col = callStaticSqlFun "isnull" col End

radians :: Column %1 -> IO Column
radians col = callStaticSqlFun "radians" col End

sin :: Column %1 -> IO Column
sin col = callStaticSqlFun "sin" col End

sinh :: Column %1 -> IO Column
sinh col = callStaticSqlFun "sinh" col End

tan :: Column %1 -> IO Column
tan col = callStaticSqlFun "tan" col End

tanh :: Column %1 -> IO Column
tanh col = callStaticSqlFun "tanh" col End

coalesce :: [Column] %1 -> IO Column
coalesce = manyToOne "coalesce"

array :: [Column] %1 -> IO Column
array = manyToOne "array"

expr :: Text -> IO Column
expr e = reflect e >>= \je -> callStaticSqlFun "expr" je End

greatest :: [Column] %1 -> IO Column
greatest = manyToOne "greatest"

least :: [Column] %1 -> IO Column
least = manyToOne "least"

-- | From the Spark docs:
--
-- Casts the column to a different data type, using the
-- canonical string representation of the type.
--
-- The supported types are: string, boolean, byte, short,
-- int, long, float, double, decimal, date, timestamp.
cast :: Column %1 -> Text -> IO Column
cast col destType = reflect destType >>= \jdestty -> call col "cast" jdestty End

-- | 'when', 'orWhen' and 'otherwise' are designed to be used
-- together to make if-then-else and more generally mutli-way if branches:
-- start with 'when', use as many extra 'orWhen' as needed and finish
-- with an 'otherwise'.
--
-- NULL values are produced if none of the conditions hold and a
-- value is not specified with 'otherwise'.
when :: Column %1 -> Column %1 -> IO Column
when cond (Column val) =
  callStaticSqlFun "when" cond (upcast val) End

orWhen :: Column %1 -> Column %1 -> Column %1 -> IO Column
orWhen chain cond (Column val) =
  call chain "when" cond (upcast val) End

otherwise :: Column %1 -> Column %1 -> IO Column
otherwise chain (Column val) =
  call chain "otherwise" (upcast val) End

-- | @if c then e1 else e2@
--
-- This is just a combination of 'when' and 'otherwise'.
ifThenElse :: Column %1 -> Column %1 -> Column %1 -> IO Column
ifThenElse c e1 e2 = when c e1 >>= (`otherwise` e2)

-- | @if c1 then e1 elseif c2 then e2 ... else def@
--
-- This is just a combination of 'when', 'orWhen' and 'otherwise'.
multiwayIf :: [(Column, Column)] %1 -> Column %1 -> IO Column
multiwayIf [] def = return def
multiwayIf ((c1, e1):cases0) def =
      when c1 e1
  >>= flip (foldM (uncurry . orWhen)) cases0
  >>= (`otherwise` def)

-- String functions

ascii :: Column %1 -> IO Column
ascii col = callStaticSqlFun "ascii" col End

concat :: [Column] %1 -> IO Column
concat = manyToOne "concat"

concat_ws :: Text -> [Column] %1 -> IO Column
concat_ws sep colexprs =
    reflect sep >>= \jSep ->
      toArray (map unColumn colexprs :: [J ('Class "org.apache.spark.sql.Column")])
        >>= \(refs, arr) -> foldM (\() -> deleteLocalRef) () refs
          >> callStaticSqlFun "concat_ws" jSep arr End

format_string :: Text -> [Column] %1 -> IO Column
format_string format arguments =
    reflect format >>= \jFormat ->
      toArray (map unColumn arguments :: [J ('Class "org.apache.spark.sql.Column")])
        >>= \(refs, arr) -> foldM (\() -> deleteLocalRef) () refs
          >> callStaticSqlFun "format_string" jFormat arr End

initcap :: Column %1 -> IO Column
initcap col = callStaticSqlFun "initcap" col End

instr :: Column %1 -> Text -> IO Column
instr col substr = reflect substr >>= \jSubstr -> callStaticSqlFun "instr" col jSubstr End

length :: Column %1 -> IO Column
length col = callStaticSqlFun "length" col End

levenshtein :: Column %1 -> Column %1 -> IO Column
levenshtein col1 col2 = callStaticSqlFun "levenshtein" col1 col2 End

locate :: Text -> Column %1 -> Maybe Int32 -> IO Column
locate substr str maybePos =
    reflect substr >>= \jSubstr ->
    case maybePos of
      Nothing  -> callStaticSqlFun "locate" jSubstr str End
      Just pos -> reflect pos >>= \jpos -> callStaticSqlFun "locate" jSubstr str jpos End

lower :: Column %1 -> IO Column
lower col = callStaticSqlFun "lower" col End

lpad :: Column %1 -> Int32 -> Text -> IO Column
lpad str len pad =
  reflect pad >>= \jpad -> 
    reflect len >>= \jlen ->
      callStaticSqlFun "lpad" str jlen jpad End

ltrim :: Column %1 -> IO Column
ltrim col = callStaticSqlFun "ltrim" col End

repeat :: Column %1 -> Int32 -> IO Column
repeat str n = 
  reflect n >>= \jn ->
    callStaticSqlFun "repeat" str jn End

reverse :: Column %1 -> IO Column
reverse col = callStaticSqlFun "reverse" col End

rpadCol :: Column %1 -> Int32 -> Text -> IO Column
rpadCol str len pad = 
  reflect pad >>= \jpad -> 
    reflect len >>= \jlen ->
      callStaticSqlFun "rpad" str jlen jpad End

rtrim :: Column %1 -> IO Column
rtrim col = callStaticSqlFun "rtrim" col End

substring :: Column %1 -> Int32 -> Int32 -> IO Column
substring str pos len = 
  reflect pos >>= \jpos ->
    reflect len >>= \jlen ->
      callStaticSqlFun "substring" str jpos jlen End

substring_index :: Column %1 -> Text -> Int32 -> IO Column
substring_index str delim count_c =
    reflect delim >>= \jDelim ->
      reflect count_c >>= \jcount ->
        callStaticSqlFun "substring_index" str jDelim jcount End

translate :: Column %1 -> Text -> Text -> IO Column
translate str from to =
    reflect from >>= \jFrom ->
      reflect to >>= \jTo -> callStaticSqlFun "translate" str jFrom jTo End

trim :: Column %1 -> IO Column
trim col = callStaticSqlFun "trim" col End

upper :: Column %1 -> IO Column
upper col = callStaticSqlFun "upper" col End

soundex :: Column %1 -> IO Column
soundex col = callStaticSqlFun "soundex" col End

regexp_extract :: Column %1 -> Text -> Int32 -> IO Column
regexp_extract str pat group =
    reflect pat >>= \p ->
      reflect group >>= \jgroup ->
        callStaticSqlFun "regexp_extract" str p jgroup End

regexp_replace :: Column %1 -> Text -> Text -> IO Column
regexp_replace str pat replace =
    reflect pat >>= \p ->
      reflect replace >>= \jr -> callStaticSqlFun "regexp_replace" str p jr End

-- Window functions

last :: Column %1 -> IO Column
last col = callStaticSqlFun "last" col End

first :: Column %1 -> IO Column
first col = callStaticSqlFun "first" col End

lead :: Column %1 -> Int32 -> IO Column
lead e offset = 
  reflect offset >>= \joffset ->
    callStaticSqlFun "lead" e joffset End

lag :: Column %1 -> Int32 -> IO Column
lag e offset = 
  reflect offset >>= \joffset ->
    callStaticSqlFun "lag" e joffset End
