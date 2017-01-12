{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}

module Control.Distributed.Spark.SQL.Column where

import Data.Text (Text)
import Language.Java
import Prelude hiding (min, max, and, or)

newtype Column = Column (J ('Class "org.apache.spark.sql.Column"))
instance Coercible Column ('Class "org.apache.spark.sql.Column")

type instance Interp Column = 'Class "org.apache.spark.sql.Column"

newtype GroupedData = GroupedData (J ('Class "org.apache.spark.sql.GroupedData"))
instance Coercible GroupedData ('Class "org.apache.spark.sql.GroupedData")

alias :: Column -> Text -> IO Column
alias c n = do
  colName <- reflect n
  call c "alias" [coerce colName]

lit :: Reflect a ty => a -> IO Column
lit a =  do
  c <- upcast <$> reflect a  -- @upcast@ needed to land in java Object
  callStatic (sing :: Sing "org.apache.spark.sql.functions") "lit" [coerce c]

plus :: Column -> Column -> IO Column
plus col1 (Column col2) = call col1 "plus" [coerce $ upcast col2]

minus :: Column -> Column -> IO Column
minus col1 (Column col2) = call col1 "minus" [coerce $ upcast col2]

multiply :: Column -> Column -> IO Column
multiply col1 (Column col2) = call col1 "multiply" [coerce $ upcast col2]

divide :: Column -> Column -> IO Column
divide col1 (Column col2) = call col1 "divide" [coerce $ upcast col2]

modCol :: Column -> Column -> IO Column
modCol col1 (Column col2) = call col1 "mod" [coerce $ upcast col2]

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
min c =
  callStatic (sing :: Sing "org.apache.spark.sql.functions") "min" [coerce c]

mean :: Column -> IO Column
mean c =
  callStatic (sing :: Sing "org.apache.spark.sql.functions") "mean" [coerce c]

max :: Column -> IO Column
max c =
  callStatic (sing :: Sing "org.apache.spark.sql.functions") "max" [coerce c]
