{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Distributed.Spark as Spark
import Control.Distributed.Spark.SQL.DataFrame as DataFrame
import qualified Control.Distributed.Spark.SQL.Column as Column
import Data.Int (Int32, Int64)
import qualified Data.Text as Text
import Language.Java
import Prelude hiding (sqrt)

main :: IO ()
main = do
    conf <- newSparkConf "Sparkle DataFrame demo"
    sc   <- getOrCreateSparkContext conf
    sqlc <- getOrCreateSQLContext sc

    let exampleData1 = Text.words "why is a mouse when it spins"
        exampleData2 = Text.words "because the higher the fewer"
    exRows1 <- toRows =<< zipWithIndex =<< parallelize sc exampleData1
    exRows2 <- toRows =<< zipWithIndex =<< parallelize sc exampleData2
    -- i.e.  [(1,"why"), (2,"is"), ... ] etc
    df1    <- toDF sqlc exRows1 "index" "word"
    df2    <- toDF sqlc exRows2 "index" "word"

    debugDF df1
    debugDF df2

    unionedDF <- unionAll df1 df2
    debugDF unionedDF

    do colexp1   <- col unionedDF "index"
       colexp4   <- Column.lit (4 :: Int64)
       colexp2a  <- Column.lit (32 :: Int32)
       colexp2b  <- Column.lit (10 :: Int32)
       colexp2   <- Column.plus colexp2a colexp1
       colexp2m  <- Column.minus colexp2 colexp1
       colexp2mu <- Column.multiply colexp2 colexp2
       colexp2d  <- Column.divide colexp2 colexp1
       colexp2mo <- Column.mod colexp2 colexp4
       colexp2ne <- Column.notEqual colexp2 colexp2b
       colexp3   <- Column.lit (True :: Bool)
       colexp5   <- Column.lit (3.14 :: Double)
       colexp6   <- Column.lit ("text" :: Text.Text)
       _colexp7   <- alias colexp5 "pi"
       selected  <- select unionedDF
          [    colexp1, colexp2, colexp3
          ,    colexp2m, colexp2mu, colexp2d, colexp2mo, colexp2ne
          ,    colexp4, colexp5, colexp6 ]
       debugDF selected

       coldiv <- col selected "((32 + index) / index)"
       colmin <- Column.min coldiv
       colix <- col selected "index"
       colmean <- mean colix
       grouped <- groupBy selected [colexp2mo]
       aggregated <- agg grouped [colmin, colmean]
       debugDF aggregated

    do colexp1   <- col df2 "index"
       colexp2   <- lit (3 :: Int32)
       colexp3   <- leq colexp1 colexp2
       filtered  <- DataFrame.filter df2 colexp3 -- index <= 3
       debugDF filtered

    do colindex1 <- col df1 "index"
       colindex2 <- col df2 "index"
       colexp    <- equalTo colindex1 colindex2
       joined    <- joinOn df1 df2 colexp
       debugDF joined
       -- The joined table has two columns called index and two called word.

       -- This makes clear we can get columns from the input tables when those
       -- names would otherwise be ambiguous:
       colindex  <- col df1 "index"
       colwords1 <- col df1 "word"
       colwords2 <- col df2 "word"
       selected <- select joined [colindex, colwords1, colwords2]
       debugDF selected

    do wcol <- col df1 "word"
       arrCols <- array [wcol, wcol]
       select df1 [arrCols] >>= debugDF

    do col1 <- lit (3.14 :: Double)
       col2 <- lit (10.0 :: Double)
       arrCols <- array [col1, col2]
       select df1 [arrCols]
         >>= javaRDD
         >>= collect
         >>= mapM (getList 0)
         >>= mapM (mapM (\x -> (reify (unsafeCast x) :: IO Double)))
         >>= print

    do redundantDF <- unionAll df1 df1
       distinctDF  <- DataFrame.distinct redundantDF
       debugDF distinctDF

    -- implicit and explicit casts
    do longCol         <- col df1 "index" >>= named "long"
       boolCol         <- cast longCol "boolean" >>= named "cast long to bool"
       sqrtLongCol     <- sqrt longCol >>= named "sqrt(long)"

       -- the following two don't work, no implicit casts
       -- for Bool -> Double and Bool -> Int
       --
       -- sqrtBoolCol    <- sqrt boolCol
       -- longPlusBoolCol <- plus longCol boolCol

       castBoolIntCol <- cast boolCol "long"
                     >>= named "cast bool to long"

       castBoolDoubleCol <- cast boolCol "double"
                        >>= named "cast bool to double"

       sqrtBoolIntCol <- sqrt castBoolIntCol
                     >>= named "sqrt(cast bool to long)"
       sqrtBoolDoubleCol <- sqrt castBoolDoubleCol
                        >>= named "sqrt(cast bool to double)"

       select df1 [ longCol
                  , boolCol
                  , sqrtLongCol
                  , castBoolIntCol
                  , castBoolDoubleCol
                  , sqrtBoolIntCol
                  , sqrtBoolDoubleCol
                  ]
         >>= debugDF

    return ()

named :: Text.Text -> Column -> IO Column
named = flip alias
