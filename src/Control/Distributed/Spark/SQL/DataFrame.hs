{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

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
