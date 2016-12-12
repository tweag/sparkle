{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}

module Control.Distributed.Spark.SQL.DataFrame where

import Control.Distributed.Spark.RDD
import Control.Distributed.Spark.SQL.Context
import Control.Distributed.Spark.SQL.Row
import Data.Text (Text)
import Language.Java

newtype DataFrame = DataFrame (J ('Class "org.apache.spark.sql.DataFrame"))
instance Coercible DataFrame ('Class "org.apache.spark.sql.DataFrame")

toDF :: SQLContext -> RDD Row -> Text -> Text -> IO DataFrame
toDF sqlc rdd s1 s2 = do
  col1 <- reflect s1
  col2 <- reflect s2
  callStatic (sing :: Sing "Helper") "toDF" [coerce sqlc, coerce rdd, coerce col1, coerce col2]

selectDF :: DataFrame -> [Text] -> IO DataFrame
selectDF _ [] = error "selectDF: not enough arguments."
selectDF df (col:cols) = do
  jcol <- reflect col
  jcols <- reflect cols
  call df "select" [coerce jcol, coerce jcols]

debugDF :: DataFrame -> IO ()
debugDF df = call df "show" []

join :: DataFrame -> DataFrame -> IO DataFrame
join d1 d2 = call d1 "join" [coerce d2]

newtype DataFrameReader =
    DataFrameReader (J ('Class "org.apache.spark.sql.DataFrameReader"))
instance Coercible DataFrameReader
                   ('Class "org.apache.spark.sql.DataFrameReader")

newtype DataFrameWriter =
    DataFrameWriter (J ('Class "org.apache.spark.sql.DataFrameWriter"))
instance Coercible DataFrameWriter
                   ('Class "org.apache.spark.sql.DataFrameWriter")

read :: SQLContext -> IO DataFrameReader
read sc = call sc "read" []

write :: DataFrame -> IO DataFrameWriter
write df = call df "write" []

readParquet :: [Text] -> DataFrameReader -> IO DataFrame
readParquet fps dfr = do
    jfps <- reflect fps
    call dfr "parquet" [coerce jfps]

writeParquet :: Text -> DataFrameWriter -> IO ()
writeParquet fp dfw = do
    jfp <- reflect fp
    call dfw "parquet" [coerce jfp]

newtype StructType =
    StructType (J ('Class "org.apache.spark.sql.types.StructType"))
instance Coercible StructType
                   ('Class "org.apache.spark.sql.types.StructType")

type JStructFieldClass = 'Class "org.apache.spark.sql.types.StructField"

newtype StructField = StructField (J JStructFieldClass)
instance Coercible StructField
                   ('Class "org.apache.spark.sql.types.StructField")

schema :: DataFrame -> IO StructType
schema df = call df "schema" []

fields :: StructType -> IO [StructField]
fields st = do
    jfields <- call st "fields" []
    Prelude.map StructField <$>
      reify (jfields :: J ('Array JStructFieldClass))

name :: StructField -> IO Text
name sf = call sf "name" [] >>= reify

nullable :: StructField -> IO Bool
nullable sf = call sf "nullable" []

newtype DataType = DataType (J ('Class "org.apache.spark.sql.types.DataType"))
instance Coercible DataType
                   ('Class "org.apache.spark.sql.types.DataType")

dataType :: StructField -> IO DataType
dataType sf = call sf "dataType" []

typeName :: DataType -> IO Text
typeName dt = call dt "typeName" [] >>= reify

newtype Column = Column (J ('Class "org.apache.spark.sql.Column"))
instance Coercible Column ('Class "org.apache.spark.sql.Column")

type instance Interp Column = 'Class "org.apache.spark.sql.Column"
instance Reflect Column ('Class "org.apache.spark.sql.Column") where
  reflect (Column jcol) = return jcol

select :: DataFrame -> [Column] -> IO DataFrame
select d1 colexprs = do
  jcols <- reflect colexprs
  call d1 "select" [coerce jcols]

filterDF :: DataFrame -> Column -> IO DataFrame
filterDF d1 colexpr = call d1 "where" [coerce colexpr]

joinOn :: DataFrame -> DataFrame -> Column -> IO DataFrame
joinOn d1 d2 colexpr = call d1 "join" [coerce d2, coerce colexpr]

unionAll :: DataFrame -> DataFrame -> IO DataFrame
unionAll d1 d2 = call d1 "unionAll" [coerce d2]

col :: DataFrame -> Text -> IO Column
col d1 t = do
  colName <- reflect t
  call d1 "col" [coerce colName]

lit :: Reflect a ty => a -> IO Column
lit a =  do
  col <- upcast <$> reflect a  -- @upcast@ needed to land in java Object
  callStatic (sing :: Sing "org.apache.spark.sql.functions") "lit" [coerce col]

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

andCol :: Column -> Column -> IO Column
andCol col1 (Column col2) = call col1 "and" [coerce col2]

orCol :: Column -> Column -> IO Column
orCol col1 (Column col2) = call col1 "or" [coerce col2]
