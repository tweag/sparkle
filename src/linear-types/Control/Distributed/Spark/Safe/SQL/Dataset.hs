{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LinearTypes #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StaticPointers #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

{-# OPTIONS_GHC -fplugin=Language.Java.Inline.Plugin #-}

module Control.Distributed.Spark.Safe.SQL.Dataset where

import qualified Prelude as P
import Prelude.Linear hiding (IO, filter, zero)
import qualified Prelude.Linear as PL
import System.IO.Linear as LIO
import Control.Functor.Linear as Linear

import Control.Distributed.Closure
import Control.Distributed.Spark.Safe.Closure
import Control.Distributed.Spark.Safe.RDD (RDD)
import Control.Distributed.Spark.Safe.SQL.Column
import Control.Distributed.Spark.Safe.SQL.Encoder
import Control.Distributed.Spark.Safe.SQL.Row
import Control.Distributed.Spark.Safe.SQL.StructType
import Control.Distributed.Spark.Safe.SQL.SparkSession
import Data.Int
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Typeable

import Foreign.JNI.Safe
import qualified Foreign.JNI.Types
import Language.Java.Safe
import qualified Language.Java as Java
import Language.Java.Inline.Safe

import Streaming (Stream, Of, effect)
import qualified Streaming.Prelude as S (filter, fold_, map, yield)

imports "org.apache.spark.storage.StorageLevel"


newtype Dataset a = Dataset (J ('Class "org.apache.spark.sql.Dataset"))
  deriving Coercible

type DataFrame = Dataset Row

javaRDD :: Dataset a %1 -> IO (RDD a)
javaRDD df = [java| $df.javaRDD() |]

createDataset :: SparkSession %1 -> Encoder a %1 -> RDD a %1 -> IO (Dataset a)
createDataset ss enc rdd = [java| $ss.createDataset($rdd.rdd(), $enc) |]

-- TODO: was it safe to get rid of the unsafePerformIO?
getEncoder :: forall a. Dataset a %1 -> IO (Encoder a)
getEncoder (Dataset dsref) = Linear.do
    UnsafeUnrestrictedReference klass <- findClass $ referenceTypeName (Java.SClass "org.apache.spark.sql.Dataset")
    Ur fID <- getFieldID klass "org$apache$spark$sql$Dataset$$encoder"
                     (Java.signature (sing :: Sing ('Iface "org.apache.spark.sql.Encoder")))
    (ref, obj) <- getObjectField dsref fID
    deleteLocalRef ref
    deleteLocalRef klass
    pure . Encoder . (unsafeCast :: JObject %1 -> J ('Iface "org.apache.spark.sql.Encoder")) $ obj

as :: Encoder b %1 -> Dataset a %1 -> IO (Dataset b)
as enc ds = [java| $ds.as($enc) |]

createDataFrame :: SparkSession %1 -> RDD Row %1 -> StructType %1 -> IO DataFrame
createDataFrame ss rdd st = [java| $ss.createDataFrame($rdd, $st) |]

sparkSession :: Dataset a %1 -> IO SparkSession
sparkSession ds = [java| $ds.sparkSession() |]

cache :: Dataset a %1 -> IO (Dataset a)
cache ds = [java| $ds.cache() |]

data StorageLevel
  = DISK_ONLY
  | DISK_ONLY_2
  | MEMORY_AND_DISK
  | MEMORY_AND_DISK_2
  | MEMORY_AND_DISK_SER
  | MEMORY_AND_DISK_SER_2
  | MEMORY_ONLY
  | MEMORY_ONLY_2
  | MEMORY_ONLY_SER
  | MEMORY_ONLY_SER_2
  | NONE
  | OFF_HEAP
  deriving (P.Enum,P.Read,P.Show,P.Eq)

persist :: StorageLevel -> Dataset a %1 -> IO (Dataset a)
persist storageLevel ds =
  reflect (Text.pack $ P.show storageLevel) >>= \jstorageLevel ->
    [java| $ds.persist(StorageLevel.fromString($jstorageLevel)) |]

unpersist :: Dataset a %1 -> IO (Dataset a)
unpersist ds = [java| $ds.unpersist(false) |]

withColumn :: Text -> Column %1 -> Dataset a %1 -> IO (Dataset Row)
withColumn colName c df =
  reflect colName >>= \jcolName ->
    [java| $df.withColumn($jcolName, $c) |]

withColumnRenamed :: Text -> Text -> Dataset a %1 -> IO (Dataset Row)
withColumnRenamed  old newt df = Linear.do
    jold <- reflect old
    jnew <- reflect newt
    [java| $df.withColumnRenamed($jold, $jnew) |]

toDF :: [Text] -> Dataset a %1 -> IO (Dataset Row)
toDF cols df = Linear.do
    jcols <- reflect cols
    [java| $df.toDF($jcols) |]

drop :: Text -> Dataset a %1 -> IO (Dataset Row)
drop colName df =
  reflect colName >>= \jcolName ->
    [java| $df.drop($jcolName) |]

selectDS :: Dataset a %1 -> [Text] -> IO (Dataset Row)
selectDS ds [] = deleteLocalRef ds >> error "selectDS: not enough arguments."
selectDS df (c:cols) = Linear.do
    jcol <- reflect c
    jcols <- reflect cols
    [java| $df.select($jcol, $jcols) |]

limit :: Int32 -> Dataset a %1 -> IO (Dataset a)
limit n df = [java| $df.limit($n) |]

show :: Dataset a %1 -> IO ()
show df = [java| { $df.show(); } |]

explain :: Dataset a %1 -> Bool -> IO ()
explain df extended = [java| { $df.explain($extended); } |]

range
     :: Int64
     -> Int64
     -> Int64
     -> Int32
     -> SparkSession
  %1 -> IO (Dataset Int64)
range start end step partitions ss =
    [java| $ss.range($start, $end, $step, $partitions) |]

union :: Dataset a %1 -> Dataset a %1 -> IO (Dataset a)
union ds1 ds2 = [java| $ds1.union($ds2) |]

join :: Dataset a %1 -> Dataset b %1 -> IO (Dataset Row)
join d1 d2 = [java| $d1.join($d2) |]

joinOn :: Dataset a %1 -> Dataset b %1 -> Column %1 -> IO DataFrame
joinOn d1 d2 colexpr = [java| $d1.join($d2, $colexpr) |]

crossJoin :: Dataset a %1 -> Dataset b %1 -> IO (Dataset Row)
crossJoin d1 d2 = [java| $d1.crossJoin($d2) |]

sample :: Bool -> Double -> Dataset a %1 -> IO (Dataset Row)
sample withReplacement fraction d1 =
    [java| $d1.sample($withReplacement, $fraction) |]

dropDuplicates :: [Text] -> Dataset a %1 -> IO (Dataset Row)
dropDuplicates cols ds = Linear.do
    jCols <- reflect cols
    [java| $ds.dropDuplicates($jCols) |]

orderBy :: [Column] %1 -> Dataset a %1 -> IO (Dataset Row)
orderBy cols ds = Linear.do
    (colRefs, jcols) <- toArray (PL.map unColumn cols)
    deleteLocalRefs colRefs
    [java| $ds.orderBy($jcols) |]

sortWithinPartitions :: [Column] %1 -> Dataset a %1 -> IO (Dataset Row)
sortWithinPartitions cols ds =
  toArray (PL.map unColumn cols :: [J ('Class "org.apache.spark.sql.Column")]) >>= \(refs, jCols) ->
    deleteLocalRefs refs >>
    [java| $ds.sortWithinPartitions($jCols) |]

sort :: [Column] %1 -> Dataset a %1 -> IO (Dataset a)
sort cols ds =
  toArray (PL.map unColumn cols
    :: [J ('Class "org.apache.spark.sql.Column")]) >>= \(refs, jcols) ->
      deleteLocalRefs refs >>
      [java| $ds.sort($jcols) |]

sortByColumnNames :: [Text] -> Dataset a %1 -> IO (Dataset a)
sortByColumnNames [] ds = deleteLocalRef ds >> error "sortByColNames: empty list of column names"
sortByColumnNames (cname : cnames) ds =
  reflect cname >>= \jn ->
    reflect cnames >>= \jns ->
      [java| $ds.sort($jn, $jns) |]

except :: Dataset a %1 -> Dataset a %1 -> IO (Dataset Row)
except ds1 ds2 = [java| $ds1.except($ds2) |]

intersect :: Dataset a %1 -> Dataset a %1 -> IO (Dataset Row)
intersect ds1 ds2 = [java| $ds1.intersect($ds2) |]

columns :: Dataset a %1 -> IO (Ur [Text])
columns df = [java| $df.columns() |] >>= reify_

printSchema :: Dataset a %1 -> IO ()
printSchema df = [java| { $df.printSchema(); } |]

distinct :: Dataset a %1 -> IO (Dataset a)
distinct d = [java| $d.distinct() |]

repartition :: Int32 -> Dataset a %1 -> IO (Dataset a)
repartition nbPart d = [java| $d.repartition($nbPart) |]

coalesce :: Int32 -> Dataset a %1 -> IO (Dataset a)
coalesce nbPart ds = [java| $ds.coalesce($nbPart) |]

collectAsList :: forall a. Reify a => Dataset a %1 -> IO (Ur [a])
collectAsList d =
    [java| $d.collectAsList().toArray() |] >>= (reify_ . jcast)
  where
    jcast :: JObjectArray %1 -> J ('Array (Interp a))
    jcast = unsafeCast

newtype DataFrameReader = DataFrameReader (J ('Class "org.apache.spark.sql.DataFrameReader"))
  deriving Coercible

newtype DataFrameWriter = DataFrameWriter (J ('Class "org.apache.spark.sql.DataFrameWriter"))
  deriving Coercible

read :: SparkSession %1 -> IO DataFrameReader
read ss = [java| $ss.read() |]

write :: Dataset a %1 -> IO DataFrameWriter
write df = call df "write" End

readParquet :: [Text] -> DataFrameReader %1 -> IO DataFrame
readParquet fps dfr = Linear.do
    jfps <- reflect fps
    call dfr "parquet" jfps End

writeParquet :: Text -> DataFrameWriter %1 -> IO ()
writeParquet fp dfw = Linear.do
    jfp <- reflect fp
    call dfw "parquet" jfp End

formatReader :: Text -> DataFrameReader %1 -> IO DataFrameReader
formatReader source dfr = Linear.do
    jsource <- reflect source
    [java| $dfr.format($jsource) |]

formatWriter :: Text -> DataFrameWriter %1 -> IO DataFrameWriter
formatWriter source dfw = Linear.do
    jsource <- reflect source
    [java| $dfw.format($jsource) |]

optionReader :: Text -> Text -> DataFrameReader %1 -> IO DataFrameReader
optionReader key value dfr = Linear.do
    jkey <- reflect key
    jv <- reflect value
    [java| $dfr.option($jkey, $jv) |]

optionWriter
  :: Text -> Text -> DataFrameWriter %1 -> IO DataFrameWriter
optionWriter key value dfw = Linear.do
    jkey <- reflect key
    jv <- reflect value
    [java| $dfw.option($jkey, $jv) |]

load :: Text -> DataFrameReader %1 -> IO DataFrame
load path dfr = Linear.do
    jpath <- reflect path
    [java| $dfr.load($jpath) |]

save :: Text -> DataFrameWriter %1 -> IO ()
save path dfw = Linear.do
    jpath <- reflect path
    [java| { $dfw.save($jpath); } |]

schema :: Dataset a %1 -> IO StructType
schema df = [java| $df.schema() |]

select :: Dataset a %1 -> [Column] %1 -> IO DataFrame
select d1 colexprs = Linear.do
    (colRefs, jcols) <- toArray (PL.map unColumn colexprs)
    deleteLocalRefs colRefs
    [java| $d1.select($jcols) |]

whereDS :: Dataset a %1 -> Column %1 -> IO (Dataset a)
whereDS d1 colexpr = [java| $d1.where($colexpr) |]

count :: Dataset a %1 -> IO (Ur Int64)
count df = [java| $df.count() |]

col :: Dataset a %1 -> Text -> IO Column
col d1 t = Linear.do
    colName <- reflect t
    [java| $d1.col($colName) |]

filter
  :: ( Reflect (MapPartitionsFunction a a)
     , Typeable a
     )
     => Closure (a -> Bool)
     -> Dataset a
  %1 -> IO (Dataset a)
filter clos ds = Linear.do
    (ds0, ds1) <- newLocalRef ds
    enc <- getEncoder ds0
    mapPartitions clos' enc ds1
  where clos' = closure (static S.filter) `cap` clos

filterByCol :: Column %1 -> Dataset a %1 -> IO (Dataset a)
filterByCol c ds = [java| $ds.filter($c) |]

map :: forall a b.
       ( Reflect (MapPartitionsFunction a b)
       , Typeable b
       , Typeable a
       )
     => Closure (a -> b)
     -> Encoder b
  %1 -> Dataset a
  %1 -> IO (Dataset b)
map clos enc ds = mapPartitions clos' enc ds
  where
    clos' :: Closure (Stream (Of a) PL.IO () -> Stream (Of b) PL.IO ())
    clos' = closure (static S.map) `cap` clos

aggregate
  :: ( Reflect (MapPartitionsFunction a b)
     , Reflect (ReduceFunction b)
     , Reify b
     , Static (Serializable b)
     , Typeable a
     )
     => Closure (b -> a -> b)
     -> Closure (b -> b -> b)
     -> b
     -> Dataset a
  %1 -> IO (Ur b)
aggregate seqOp combOp zero =
    aggregatePartitions seqOp' combOp
  where
    seqOp' = (closure $ static (\f z -> S.fold_ f z id))
       `cap` seqOp
       `cap` cpure closureDict zero

-- | Like 'aggregate', but exposing the underlying iterator
aggregatePartitions
  :: forall a b.
     ( Reflect (MapPartitionsFunction a b)
     , Reflect (ReduceFunction b)
     , Reify b
     , Typeable a
     , Typeable b
     )
  => Closure (Stream (Of a) PL.IO () -> PL.IO b)
  -> Closure (b -> b -> b)
  -> Dataset a %1 -> IO (Ur b)
aggregatePartitions seqOp combOp ds = Linear.do
    enc <- kryo
    reducePartitions seqOp enc ds
      >>= slowReduce combOp

mapPartitions
  :: Reflect (MapPartitionsFunction a b)
      => Closure (Stream (Of a) PL.IO () -> Stream (Of b) PL.IO ())
      -> Encoder b
   %1 -> Dataset a
   %1 -> IO (Dataset b)
mapPartitions clos enc ds = Linear.do
    f <- ungeneric <$> reflect (MapPartitionsFunction clos)
    [java| $ds.mapPartitions($f, $enc) |]

-- | Like 'mapPartitions', but for a function that produces only a single
-- element partition
reducePartitions
  :: ( Reflect (MapPartitionsFunction a b)
     , Typeable a
     , Typeable b
     )
     => Closure (Stream (Of a) PL.IO () -> PL.IO b)
     -> Encoder b
  %1 -> Dataset a
  %1 -> IO (Dataset b)
reducePartitions fun =
    mapPartitions
      (closure  (static (\f it -> effect P.$ S.yield P.<$> f it)) `cap` fun)

reduce
  :: forall a. (Static (Reify a), Static (Reflect a), Typeable a)
     => Closure (a -> a -> a)
     -> Dataset a
  %1 -> IO (Ur a)
reduce clos ds = Linear.do
    f <- ungeneric <$> reflect (ReduceFunction clos)
    [java| $ds.reduce($f) |]
      >>= \res -> reify_ (jcast res)
  where
    jcast :: JObject %1 -> J (Interp a)
    jcast = unsafeCast

slowReduce
  :: forall a. (Reflect (ReduceFunction a), Reify a)
     => Closure (a -> a -> a)
     -> Dataset a
  %1 -> IO (Ur a)
slowReduce clos ds = Linear.do
    f <- ungeneric <$> reflect (ReduceFunction clos)
    [java| $ds.reduce($f) |]
      >>= \res -> reify_ (jcast res)
  where
    jcast :: JObject %1 -> J (Interp a)
    jcast = unsafeCast

groupBy :: forall a . Dataset a %1 -> [Column] %1 -> IO GroupedData
groupBy d1 colexprs = Linear.do
    (colRefs, jcols) <- toArray (PL.map unColumn colexprs)
    deleteLocalRefs colRefs
    [java| $d1.groupBy($jcols) |]

agg :: GroupedData %1 -> [Column] %1 -> IO (Dataset Row)
agg df [] = deleteLocalRef df >> error "agg: not enough arguments."
agg df (Column jcol : cols) = Linear.do
  (colRefs, jcols) <- toArray (PL.map unColumn cols)
  deleteLocalRefs colRefs
  [java| $df.agg($jcol, $jcols) |]
