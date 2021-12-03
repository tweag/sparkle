{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Distributed.Spark as Spark
import Control.Distributed.Spark.SQL.Dataset as Dataset
--import qualified Control.Distributed.Spark.SQL.Column as Column
--import Data.Int (Int32, Int64)
import Data.Int (Int64)
import qualified Data.Text as Text
--import Language.Java
import Language.Scala.Tuple
import Prelude hiding (sqrt)



main :: IO ()
main = forwardUnhandledExceptionsToSpark $ do
    conf <- newSparkConf "Sparkle Dataset demo"
    confSet conf "spark.sql.extensions" "io.delta.sql.DeltaSparkSessionExtension"
    confSet conf "spark.sql.catalog.spark_catalog" "org.apache.spark.sql.delta.catalog.DeltaCatalog"
    --confSet conf "spark.serializer" "org.apache.spark.serializer.KryoSerializer"
    --confSet conf "spark.kryo.registrator" "io.tweag.sparkle.kryo.InlineJavaRegistrator"

    session <- builder >>= (`config` conf) >>= getOrCreate
    sc <- sparkContext session

    let exampleData1 = Text.words "why is a mouse when it spins"
        exampleData2 = Text.words "because the higher the fewer"

        exampleToDS :: [Text.Text] -> IO (Dataset (Tuple2 Text.Text Int64))
        exampleToDS ws =
          parallelize sc ws >>=
          zipWithIndex >>=
          toRDD >>= \rdd ->
          encoder >>= \enc ->
          createDataset session enc rdd >>= toDF ["word", "index"] >>= as enc

    -- i.e.  [(1,"why"), (2,"is"), ... ] etc
    df1 <- exampleToDS exampleData1
    df2 <- exampleToDS exampleData2

    Dataset.show df1
    Dataset.show df2

    dfw1 <- Dataset.write df1
    dfw2 <- Dataset.write df2
    
    dfw1_delta <- Dataset.formatWriter "delta" dfw1 
    dfw2_delta <- Dataset.formatWriter "delta" dfw2
    Dataset.save "deltalake" dfw1_delta

    dfr <- Dataset.read session
    dfr_delta <- Dataset.formatReader "delta" dfr
    df1_1 <- Dataset.load "deltalake" dfr_delta
    Dataset.show df1_1


    dfw2_delta_append <- Dataset.modeWriter "append" dfw2_delta
    Dataset.save "deltalake" dfw2_delta_append

    dfr2 <- Dataset.read session
    dfr2_delta <- Dataset.formatReader "delta" dfr2
    df2_1 <- Dataset.load "deltalake" dfr2_delta
    Dataset.show df2_1

    dfrRollback <- Dataset.read session
    dfrRollback_delta <- Dataset.formatReader "delta" dfrRollback
    dfrRollback_option <- Dataset.optionReader "versionAsOf" "0" dfrRollback_delta
    df3_1 <- Dataset.load "deltalake" dfrRollback_option
    Dataset.show df3_1
