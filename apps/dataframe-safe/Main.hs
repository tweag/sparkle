{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE LinearTypes #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Main where

import Prelude.Linear hiding (IO, filter, zero, sqrt)
import qualified Prelude.Linear as PL
import System.IO.Linear as LIO
import Control.Functor.Linear as Linear
import Control.Monad.IO.Class.Linear
import qualified Data.Functor.Linear as D

import qualified Control.Distributed.Spark as Spark
import Control.Distributed.Spark.Safe
import Control.Distributed.Spark.Safe.SQL.Dataset as Dataset
import qualified Control.Distributed.Spark.Safe.SQL.Column as Column

import Data.Int (Int32, Int64)
import Data.Coerce as Coerce
import qualified Data.Text as Text

import Language.Java.Safe
import Language.Java.Inline.Safe
import qualified Foreign.JNI.Types
import Language.Scala.Tuple

-- Some helpers to deal with multiple copies of a reference
-- What we really need is an `nLocalRefs` that returns a length-indexed vector
newLocalRef3 :: (MonadIO m, Coerce.Coercible o (J ty)) => o %1-> m (o, o, o)
newLocalRef3 j = Linear.do 
  (j0, j1) <- newLocalRef j
  (j2, j3) <- newLocalRef j0
  pure $ (j1, j2, j3)

newLocalRef4 :: (MonadIO m, Coerce.Coercible o (J ty)) => o %1-> m (o, o, o, o)
newLocalRef4 j = Linear.do 
  (j0, j1, j2) <- newLocalRef3 j
  (j3, j4) <- newLocalRef j0
  pure $ (j1, j2, j3, j4)

newLocalRef5 :: (MonadIO m, Coerce.Coercible o (J ty)) => o %1-> m (o, o, o, o, o)
newLocalRef5 j = Linear.do 
  (j0, j1, j2, j3) <- newLocalRef4 j
  (j4, j5) <- newLocalRef j0
  pure $ (j1, j2, j3, j4, j5)

newLocalRef6 :: (MonadIO m, Coerce.Coercible o (J ty)) => o %1-> m (o, o, o, o, o, o)
newLocalRef6 j = Linear.do 
  (j0, j1, j2, j3, j4) <- newLocalRef5 j
  (j5, j6) <- newLocalRef j0
  pure $ (j1, j2, j3, j4, j5, j6)

newLocalRef7 :: (MonadIO m, Coerce.Coercible o (J ty)) => o %1-> m (o, o, o, o, o, o, o)
newLocalRef7 j = Linear.do 
  (j0, j1, j2, j3, j4, j5) <- newLocalRef6 j
  (j6, j7) <- newLocalRef j0
  pure $ (j1, j2, j3, j4, j5, j6, j7)

main :: PL.IO ()
main = Spark.forwardUnhandledExceptionsToSpark $ do
  LIO.withLinearIO $ Linear.do
    conf <- newSparkConf "Sparkle Dataset demo"
    (session, sess0, sess1) <- builder >>= (`config` conf) >>= getOrCreate >>= newLocalRef3
    (sc0, sc1) <- sparkContext session >>= newLocalRef

    Ur exampleData1 <- pure $ Ur $ Text.words "why is a mouse when it spins"
    Ur exampleData2 <- pure $ Ur $ Text.words "because the higher the fewer"

    Ur (exampleToDS :: SparkContext %1 -> SparkSession %1 -> [Text.Text] -> IO (Dataset (Tuple2 Text.Text Int64))) <- pure $ Ur $
      \sc sess ws ->
          parallelize sc ws >>=
          zipWithIndex >>=
          toRDD >>= \rdd ->
          encoder >>= 
          newLocalRef >>= \(enc0, enc1) -> 
          createDataset sess enc0 rdd >>= toDF ["word", "index"] >>= as enc1

     -- i.e.  [(1,"why"), (2,"is"), ... ] etc
    (df1, df1', df1'') <- exampleToDS sc0 sess0 exampleData1 >>= newLocalRef3
    (df2, df2', df2'') <- exampleToDS sc1 sess1 exampleData2 >>= newLocalRef3

    Dataset.show df1'
    Dataset.show df2'

    (unionedDF, unionedDF', unionedDF'') <- Dataset.union df1 df2 >>= newLocalRef3
    Dataset.show unionedDF

    Linear.do 
       (colexp1, colexp1', colexp1'', colexp1''')  <- col unionedDF' "index" >>= newLocalRef4
       (colexp4, colexp4')   <- Column.lit (4 :: Int64) >>= newLocalRef
       colexp2a  <- Column.lit (32 :: Int32)
       colexp2b  <- Column.lit (10 :: Int32)
       (colexp20, colexp21, colexp22, colexp23, colexp24, colexp25, colexp26)   <- Column.plus colexp2a colexp1 >>= newLocalRef7
       colexp2m  <- Column.minus colexp20 colexp1'
       colexp2mu <- Column.multiply colexp21 colexp22
       colexp2d  <- Column.divide colexp23 colexp1''
       (colexp2mo, colexp2mo') <- Column.mod colexp24 colexp4 >>= newLocalRef
       colexp2ne <- Column.notEqual colexp25 colexp2b
       colexp3   <- Column.lit (True :: Bool)
       (colexp5, colexp5')   <- Column.lit (3.14 :: Double) >>= newLocalRef
       colexp6   <- Column.lit ("text" :: Text.Text)
       _colexp7   <- alias colexp5 "pi"
       deleteLocalRef _colexp7
       (selected, selected0, selected1, selected2) <- Dataset.select unionedDF''
            [    colexp1''', colexp26, colexp3
            ,    colexp2m, colexp2mu, colexp2d, colexp2mo, colexp2ne
            ,    colexp4', colexp5', colexp6 ] >>= newLocalRef4
       Dataset.show selected

       coldiv <- col selected0 "((32 + index) / index)"
       colmin <- Column.min coldiv
       colix <- col selected1 "index"
       colmean <- Column.mean colix
       grouped <- Dataset.groupBy selected2 [colexp2mo']
       aggregated <- agg grouped [colmin, colmean]
       Dataset.show aggregated

    (df2_1, df2_2, df2_c) <- newLocalRef3 df2''
    Linear.do 
       colexp1   <- col df2_1 "index"
       colexp2   <- lit (3 :: Int32)
       colexp3   <- leq colexp1 colexp2
       filtered  <- Dataset.filterByCol colexp3 df2_2 -- index <= 3
       Dataset.show filtered

    (df1_1, df1_2, df1_3, df1_4, df1_c) <- newLocalRef5 df1''
    (df2_3, df2_4, df2_5, df2_cc) <- newLocalRef4 df2_c
    Linear.do 
       colindex1 <- col df1_1 "index"
       colindex2 <- col df2_3 "index"
       colexp    <- equalTo colindex1 colindex2
       (joined, joined')    <- joinOn df1_2 df2_4 colexp >>= newLocalRef
       Dataset.show joined
       -- The joined table has two columns called index and two called word.

       -- This makes clear we can get columns from the input tables when those
       -- names would otherwise be ambiguous:
       colindex  <- col df1_3 "index"
       colwords1 <- col df1_4 "word"
       colwords2 <- col df2_5 "word"
       selected <- select joined' [colindex, colwords1, colwords2]
       Dataset.show selected

    (df1_5, df1_6, df1_ccb) <- newLocalRef3 df1_c
    Linear.do 
       (wcol, wcol') <- col df1_5 "word" >>= newLocalRef
       arrCols <- array [wcol, wcol']
       select df1_6 [arrCols] >>= Dataset.show

    -- This one shows a use of collectJ
    (df1_6b, df1_cc) <- newLocalRef df1_ccb
    Linear.do 
       col1 <- lit (3.14 :: Double)
       col2 <- lit (10.0 :: Double)
       arrCols <- array [col1, col2]
       select df1_6b [arrCols]
         >>= javaRDD
         >>= collectJ
         >>= \xs -> D.mapM (getList 0) xs
         >>= \ys -> D.mapM (\(Ur yelts) -> LIO.fromSystemIO (print (yelts :: [Double]))) ys
         >>= \units -> pure $ foldr (\() () -> ()) () units

    (df1_7, df1_8, df1_ccc) <- newLocalRef3 df1_cc
    Linear.do 
       redundantDF <- Dataset.union df1_7 df1_8
       distinctDF  <- Dataset.distinct redundantDF
       Dataset.show distinctDF

    -- implicit and explicit casts
    (df1_9, df1_10, df1_c') <- newLocalRef3 df1_ccc
    Linear.do 
       (longCol, longCol', longCol'') <- col df1_9 "index" >>= named "long" >>= newLocalRef3
       (boolCol, boolCol', boolCol'') <- cast longCol "boolean" >>= named "cast long to bool" >>= newLocalRef3
       sqrtLongCol     <- sqrt longCol' >>= named "sqrt(long)"

       -- the following two don't work, no implicit casts
       -- for Bool -> Double and Bool -> Int
       --
       -- sqrtBoolCol    <- sqrt boolCol
       -- longPlusBoolCol <- plus longCol boolCol

       (castBoolIntCol, castBoolIntCol') <- cast boolCol "long"
                     >>= named "cast bool to long" >>= newLocalRef

       (castBoolDoubleCol, castBoolDoubleCol') <- cast boolCol' "double"
                        >>= named "cast bool to double" >>= newLocalRef

       sqrtBoolIntCol <- sqrt castBoolIntCol
                     >>= named "sqrt(cast bool to long)"
       sqrtBoolDoubleCol <- sqrt castBoolDoubleCol
                        >>= named "sqrt(cast bool to double)"

       select df1_10 [ longCol''
                     , boolCol''
                     , sqrtLongCol
                     , castBoolIntCol'
                     , castBoolDoubleCol'
                     , sqrtBoolIntCol
                     , sqrtBoolDoubleCol
                     ]
         >>= Dataset.show

    (df1_h, df1_i, df1_j, df1_c'') <- newLocalRef4 df1_c' 
    Linear.do 
       int2Col   <- lit (2 :: Int32)
       int4Col   <- lit (4 :: Int32)
       fooCol    <- lit ("foo" :: Text.Text)
       barCol    <- lit ("bar" :: Text.Text)
       (index1Col, index1Col') <- col df1_h "index" >>= newLocalRef
       (cond1Col, cond1Col')  <- leq index1Col int2Col >>= newLocalRef -- index <= 2
       cond2Col  <- leq index1Col' int4Col  -- index <= 4

       trueCol   <- lit True
       falseCol  <- lit False
       (colwords1, colwords1', colwords1'', colwords1''') <- col df1_i "word" >>= newLocalRef4
       ex1      <- when trueCol  colwords1  -- all words
       ex2      <- when falseCol colwords1'  -- all null
       ex3      <- when cond1Col colwords1''  -- some words, some null
       ex4      <- multiwayIf [(cond1Col', colwords1'''),
                               (cond2Col, fooCol)]
                              barCol         -- some words, foo, bar
       select df1_j [ex1, ex2, ex3, ex4] >>= Dataset.show

    (df1_k, df1_c''') <- newLocalRef df1_c''
    Linear.do 
       (nowTsCol0, nowTsCol1, nowTsCol2, nowTsCol3, nowTsCol4, nowTsCol5, nowTsCol6) <- current_timestamp >>= newLocalRef7
       (nowDtCol, nowDtCol',  nowDtCol'', nowDtCol''') <- current_date >>= newLocalRef4

       (jdate :: J ('Class "java.sql.Date")) <- [java| new java.sql.Date(0) |]
       epochTsCol <- [java| org.apache.spark.sql.functions.lit($jdate) |]

       (jtimestamp :: J ('Class "java.sql.Timestamp")) <- [java| new java.sql.Timestamp(0) |] 
       epochDtCol <- [java| org.apache.spark.sql.functions.lit($jtimestamp) |]

       secCol     <- second nowTsCol0
       minsCol    <- minute nowTsCol1
       hrsCol     <- hour nowTsCol2

       daysCol    <- dayofmonth nowTsCol3
       monthsCol  <- month nowTsCol4
       yearsCol   <- year nowTsCol5

       daysCol'   <- dayofmonth nowDtCol
       monthsCol' <- month nowDtCol'
       yearsCol'  <- year nowDtCol''

       select df1_k [ epochDtCol, epochTsCol
                  , nowTsCol6, nowDtCol'''
                  , secCol, minsCol, hrsCol
                  , daysCol, monthsCol, yearsCol
                  , daysCol', monthsCol', yearsCol' ]
         >>= Dataset.show

    (df1_l, df1_cc') <- newLocalRef df1_c'''
    Linear.do 
      (lit (1 :: Int32)       >>= named "int")  >>= newLocalRef >>= \(intCol, intCol')  ->
        (lit True               >>= named "bool") >>= newLocalRef3 >>= \(boolCol, boolCol', boolCol'') ->
          (sqrt intCol            >>= named "sqrt(int)") >>= \sqrtIntCol ->
            (cast boolCol "int"     >>= named "cast bool to int") >>= newLocalRef >>= \(castBoolIntCol, castBoolIntCol')    ->
              (cast boolCol' "double"  >>= named "cast bool to double") >>= newLocalRef >>= \(castBoolDoubleCol, castBoolDoubleCol') ->
                (sqrt castBoolIntCol    >>= named "sqrt(cast bool to int)") >>= \sqrtBoolIntCol    ->
                  (sqrt castBoolDoubleCol >>= named "sqrt(cast bool to double)") >>= \sqrtBoolDoubleCol ->

                       select df1_l [ intCol'
                                  , boolCol''
                                  , sqrtIntCol
                                  , castBoolIntCol'
                                  , castBoolDoubleCol'
                                  , sqrtBoolIntCol
                                  , sqrtBoolDoubleCol
                                  ] >>= Dataset.show
    deleteLocalRef df1_cc'
    deleteLocalRef df2_cc
    return (Ur ())

named :: Text.Text -> Column %1 -> IO Column
named t c = alias c t
