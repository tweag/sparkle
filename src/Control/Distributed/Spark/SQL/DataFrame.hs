{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}

module Control.Distributed.Spark.SQL.DataFrame where

import Control.Distributed.Spark.RDD
import Control.Distributed.Spark.SQL.Column
import Control.Distributed.Spark.SQL.Context
import Control.Distributed.Spark.SQL.Row
import Control.Distributed.Spark.SQL.StructType
import Data.Int
import Data.Text (Text)
import Language.Java
import Prelude hiding (filter)

newtype DataFrame = DataFrame (J ('Class "org.apache.spark.sql.DataFrame"))
instance Coercible DataFrame ('Class "org.apache.spark.sql.DataFrame")

toDF :: SQLContext -> RDD Row -> Text -> Text -> IO DataFrame
toDF sqlc rdd s1 s2 = do
  col1 <- reflect s1
  col2 <- reflect s2
  callStatic "Helper" "toDF" [coerce sqlc, coerce rdd, coerce col1, coerce col2]

javaRDD :: DataFrame -> IO (RDD Row)
javaRDD df = call df "javaRDD" []

createDataFrame :: SQLContext -> RDD Row -> StructType -> IO DataFrame
createDataFrame sqlc rdd st =
  call sqlc "createDataFrame" [coerce rdd, coerce st]

debugDF :: DataFrame -> IO ()
debugDF df = call df "show" []

range :: Int64 -> Int64 -> Int64 -> Int32 -> SQLContext -> IO DataFrame
range start end step partitions sqlc =
  call sqlc "range" [coerce start, coerce end, coerce step, coerce partitions]

join :: DataFrame -> DataFrame -> IO DataFrame
join d1 d2 = call d1 "join" [coerce d2]

joinOn :: DataFrame -> DataFrame -> Column -> IO DataFrame
joinOn d1 d2 colexpr = call d1 "join" [coerce d2, coerce colexpr]

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

schema :: DataFrame -> IO StructType
schema df = call df "schema" []

-- TODO fishy impl
--
-- select :: DataFrame -> [Column] -> IO DataFrame
-- select d1 colexprs = do
--   jcols <- reflect (Prelude.map Data.Coerce.coerce colexprs :: [J ('Class "org.apache.spark.sql.Column")])
--   call d1 "select" [coerce jcols]

filter :: DataFrame -> Column -> IO DataFrame
filter d1 colexpr = call d1 "where" [coerce colexpr]

unionAll :: DataFrame -> DataFrame -> IO DataFrame
unionAll d1 d2 = call d1 "unionAll" [coerce d2]

distinct :: DataFrame -> IO DataFrame
distinct d = call d "distinct" []

withColumnRenamed :: Text -> Text -> DataFrame -> IO DataFrame
withColumnRenamed old newName df = do
  jold <- reflect old
  jnew <- reflect newName
  call df "withColumnRenamed" [coerce jold, coerce jnew]

col :: DataFrame -> Text -> IO Column
col d1 t = do
  colName <- reflect t
  call d1 "col" [coerce colName]

columns :: DataFrame -> IO [Text]
columns df = call df "columns" [] >>= reify

printSchema :: DataFrame -> IO ()
printSchema df = call df "printSchema" []

-- TODO fishy impl
--
-- groupBy :: DataFrame -> [Column] -> IO GroupedData
-- groupBy d1 colexprs = do
--   jcols <- reflect (Prelude.map Data.Coerce.coerce colexprs :: [J ('Class "org.apache.spark.sql.Column")])
--   call d1 "groupBy" [coerce jcols]

-- TODO fishy impl
--
-- agg :: GroupedData -> [Column] -> IO DataFrame
-- agg _ [] = error "agg: not enough arguments."
-- agg df (c:cols) = do
--   jcols <- reflect (Prelude.map Data.Coerce.coerce cols :: [J ('Class "org.apache.spark.sql.Column")])
--   call df "agg" [coerce c, coerce jcols]
