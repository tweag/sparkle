{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Distributed.Spark as Spark
import Control.Distributed.Spark.SQL.Dataset as Dataset
import qualified Control.Distributed.Spark.SQL.Column as Column
import Data.Int (Int32, Int64)
import qualified Data.Text as Text
import Language.Java
import Language.Scala.Tuple
import Prelude hiding (sqrt)

main :: IO ()
main = forwardUnhandledExceptionsToSpark $ do
    conf <- newSparkConf "Sparkle Dataset demo"
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

    unionedDF <- Dataset.union df1 df2
    Dataset.show unionedDF

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
       selected  <- Dataset.select unionedDF
          [    colexp1, colexp2, colexp3
          ,    colexp2m, colexp2mu, colexp2d, colexp2mo, colexp2ne
          ,    colexp4, colexp5, colexp6 ]
       Dataset.show selected

       coldiv <- col selected "((32 + index) / index)"
       colmin <- Column.min coldiv
       colix <- col selected "index"
       colmean <- Column.mean colix
       grouped <- Dataset.groupBy selected [colexp2mo]
       aggregated <- agg grouped [colmin, colmean]
       Dataset.show aggregated

    do colexp1   <- col df2 "index"
       colexp2   <- lit (3 :: Int32)
       colexp3   <- leq colexp1 colexp2
       filtered  <- Dataset.filterByCol colexp3 df2 -- index <= 3
       Dataset.show filtered

    do colindex1 <- col df1 "index"
       colindex2 <- col df2 "index"
       colexp    <- equalTo colindex1 colindex2
       joined    <- joinOn df1 df2 colexp
       Dataset.show joined
       -- The joined table has two columns called index and two called word.

       -- This makes clear we can get columns from the input tables when those
       -- names would otherwise be ambiguous:
       colindex  <- col df1 "index"
       colwords1 <- col df1 "word"
       colwords2 <- col df2 "word"
       selected <- select joined [colindex, colwords1, colwords2]
       Dataset.show selected

    do wcol <- col df1 "word"
       arrCols <- array [wcol, wcol]
       select df1 [arrCols] >>= Dataset.show

    do col1 <- lit (3.14 :: Double)
       col2 <- lit (10.0 :: Double)
       arrCols <- array [col1, col2]
       select df1 [arrCols]
         >>= javaRDD
         >>= collect
         >>= mapM (getList 0)
         >>= \xs -> print (xs :: [[Double]])

    do redundantDF <- Dataset.union df1 df1
       distinctDF  <- Dataset.distinct redundantDF
       Dataset.show distinctDF

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
         >>= Dataset.show

    do int2Col   <- lit (2 :: Int32)
       int4Col   <- lit (4 :: Int32)
       fooCol    <- lit ("foo" :: Text.Text)
       barCol    <- lit ("bar" :: Text.Text)
       index1Col <- col df1 "index"
       cond1Col  <- leq index1Col int2Col  -- index <= 2
       cond2Col  <- leq index1Col int4Col  -- index <= 4

       trueCol   <- lit True
       falseCol  <- lit False
       colwords1 <- col df1 "word"
       ex1      <- when trueCol  colwords1  -- all words
       ex2      <- when falseCol colwords1  -- all null
       ex3      <- when cond1Col colwords1  -- some words, some null
       ex4      <- multiwayIf [(cond1Col, colwords1),
                               (cond2Col, fooCol)]
                              barCol         -- some words, foo, bar
       select df1 [ex1, ex2, ex3, ex4] >>= Dataset.show

    do nowTsCol   <- current_timestamp
       nowDtCol   <- current_date

       jdate <- new (0 :: Int64) :: IO (J ('Class "java.sql.Date"))
       epochTsCol <- lit jdate
       jtimestamp <- new (0 :: Int64) :: IO (J ('Class "java.sql.Timestamp"))
       epochDtCol <- lit jtimestamp

       secCol     <- second nowTsCol
       minsCol    <- minute nowTsCol
       hrsCol     <- hour nowTsCol

       daysCol    <- dayofmonth nowTsCol
       monthsCol  <- month nowTsCol
       yearsCol   <- year nowTsCol

       daysCol'   <- dayofmonth nowDtCol
       monthsCol' <- month nowDtCol
       yearsCol'  <- year nowDtCol

       select df1 [ epochDtCol, epochTsCol
                  , nowTsCol, nowDtCol
                  , secCol, minsCol, hrsCol
                  , daysCol, monthsCol, yearsCol
                  , daysCol', monthsCol', yearsCol' ]
         >>= Dataset.show

    do (lit (1 :: Int32)         `withLocalRef` named "int")                       `withLocalRef` \intCol            ->
         (lit True               `withLocalRef` named "bool")                      `withLocalRef` \boolCol           ->
         (sqrt intCol            `withLocalRef` named "sqrt(int)")                 `withLocalRef` \sqrtIntCol        ->
         (cast boolCol "int"     `withLocalRef` named "cast bool to int")          `withLocalRef` \castBoolIntCol    ->
         (cast boolCol "double"  `withLocalRef` named "cast bool to double")       `withLocalRef` \castBoolDoubleCol ->
         (sqrt castBoolIntCol    `withLocalRef` named "sqrt(cast bool to int)")    `withLocalRef` \sqrtBoolIntCol    ->
         (sqrt castBoolDoubleCol `withLocalRef` named "sqrt(cast bool to double)") `withLocalRef` \sqrtBoolDoubleCol ->

         select df1 [ intCol
                    , boolCol
                    , sqrtIntCol
                    , castBoolIntCol
                    , castBoolDoubleCol
                    , sqrtBoolIntCol
                    , sqrtBoolDoubleCol
                    ] `withLocalRef` Dataset.show

    return ()

named :: Text.Text -> Column -> IO Column
named = flip alias
