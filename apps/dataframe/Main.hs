{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Distributed.Spark
import Data.Int (Int32, Int64)
import qualified Data.Text as Text

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
       colexp4   <- lit (4 :: Int64)
       colexp2a  <- lit (32 :: Int32)
       colexp2b  <- lit (10 :: Int32)
       colexp2   <- plus colexp2a colexp1
       colexp2m  <- minus colexp2 colexp1
       colexp2mu <- multiply colexp2 colexp2
       colexp2d  <- divide colexp2 colexp1
       colexp2mo <- modCol colexp2 colexp4
       colexp2ne <- notEqual colexp2 colexp2b
       colexp3   <- lit (True :: Bool)
       colexp5   <- lit (3.14 :: Double)
       colexp6   <- lit ("text" :: Text.Text)
       colexp7   <- alias colexp5 "pi"
       selected  <- select unionedDF
          [    colexp1, colexp2, colexp3
          ,    colexp2m, colexp2mu, colexp2d, colexp2mo, colexp2ne
          ,    colexp4, colexp5, colexp6 ]
       debugDF selected

       coldiv <- col selected "((32 + index) / index)"
       colmin <- minCol coldiv
       colix <- col selected "index"
       colmean <- meanCol colix
       grouped <- groupBy selected [colexp2mo]
       aggregated <- agg grouped [colmin, colmean]
       debugDF aggregated

    do colexp1   <- col df2 "index"
       colexp2   <- lit (3 :: Int32)
       colexp3   <- leq colexp1 colexp2
       filtered  <- filterDF df2 colexp3 -- index <= 3
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

    return ()
