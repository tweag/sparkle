{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StaticPointers #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

{-# OPTIONS_GHC -fplugin=Language.Java.Inline.Plugin #-}

module Control.Distributed.Spark.SQL.Dataset where

import Control.Distributed.Closure
import Control.Distributed.Spark.Closure
import Control.Distributed.Spark.RDD (RDD)
import Control.Distributed.Spark.SQL.Column
import Control.Distributed.Spark.SQL.Encoder
import Control.Distributed.Spark.SQL.Row
import Control.Distributed.Spark.SQL.StructType
import Control.Distributed.Spark.SQL.SparkSession
import qualified Data.Coerce
import Data.Int
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Typeable
import Foreign.JNI
import Language.Java
import Language.Java.Inline
import Prelude hiding (filter)
import Streaming (Stream, Of, effect)
import qualified Streaming.Prelude as S (filter, fold_, map, yield)
import System.IO.Unsafe (unsafeDupablePerformIO, unsafePerformIO)

imports "org.apache.spark.storage.StorageLevel"


newtype Dataset a = Dataset (J ('Class "org.apache.spark.sql.Dataset"))
  deriving Coercible

type DataFrame = Dataset Row

javaRDD :: Dataset a -> IO (RDD a)
javaRDD df = [java| $df.javaRDD() |]

createDataset :: SparkSession -> Encoder a -> RDD a -> IO (Dataset a)
createDataset ss enc rdd = [java| $ss.createDataset($rdd.rdd(), $enc) |]

getEncoder :: forall a. Dataset a -> IO (Encoder a)
getEncoder ds = do
    let klass = unsafeDupablePerformIO $ withLocalRef
          (findClass $
            referenceTypeName (SClass "org.apache.spark.sql.Dataset"))
          newGlobalRef
        fID = unsafePerformIO $
          getFieldID klass
                     "org$apache$spark$sql$Dataset$$encoder"
                     (signature (sing :: Sing (Interp (Encoder a))))
    (Encoder
      . (unsafeCast :: JObject -> J ('Iface "org.apache.spark.sql.Encoder"))
      )
      <$> getObjectField ds fID

as :: Encoder b -> Dataset a -> IO (Dataset b)
as enc ds = [java| $ds.as($enc) |]

createDataFrame :: SparkSession -> RDD Row -> StructType -> IO DataFrame
createDataFrame ss rdd st = [java| $ss.createDataFrame($rdd, $st) |]

sparkSession :: Dataset a -> IO SparkSession
sparkSession ds = [java| $ds.sparkSession() |]

cache :: Dataset a -> IO (Dataset a)
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
  deriving (Enum,Read,Show,Eq)

persist :: StorageLevel -> Dataset a -> IO (Dataset a)
persist storageLevel ds =
  withLocalRef (reflect (Text.pack $ Prelude.show storageLevel)) $ \jstorageLevel ->
  [java| $ds.persist(StorageLevel.fromString($jstorageLevel)) |]

unpersist :: Dataset a -> IO (Dataset a)
unpersist ds = [java| $ds.unpersist(false) |]

withColumn :: Text -> Column -> Dataset a -> IO (Dataset Row)
withColumn colName c df =
    withLocalRef (reflect colName) $ \jcolName ->
    [java| $df.withColumn($jcolName, $c) |]

withColumnRenamed :: Text -> Text -> Dataset a -> IO (Dataset Row)
withColumnRenamed  old newt df = do
    jold <- reflect old
    jnew <- reflect newt
    [java| $df.withColumnRenamed($jold, $jnew) |]

toDF :: [Text] -> Dataset a -> IO (Dataset Row)
toDF cols df = do
    jcols <- reflect cols
    [java| $df.toDF($jcols) |]

drop :: Text -> Dataset a -> IO (Dataset Row)
drop colName df =
    withLocalRef (reflect colName) $ \jcolName ->
    [java| $df.drop($jcolName) |]

selectDS :: Dataset a -> [Text] -> IO (Dataset Row)
selectDS _ [] = error "selectDS: not enough arguments."
selectDS df (c:cols) = do
    jcol <- reflect c
    jcols <- reflect cols
    [java| $df.select($jcol, $jcols) |]

limit :: Int32 -> Dataset a -> IO (Dataset a)
limit n df = [java| $df.limit($n) |]

show :: Dataset a -> IO ()
show df = [java| { $df.show(); } |]

explain :: Dataset a -> Bool -> IO ()
explain df extended = [java| { $df.explain($extended); } |]

range
  :: Int64
  -> Int64
  -> Int64
  -> Int32
  -> SparkSession
  -> IO (Dataset Int64)
range start end step partitions ss =
    [java| $ss.range($start, $end, $step, $partitions) |]

union :: Dataset a -> Dataset a -> IO (Dataset a)
union ds1 ds2 = [java| $ds1.union($ds2) |]

join :: Dataset a -> Dataset b -> IO (Dataset Row)
join d1 d2 = [java| $d1.join($d2) |]

joinOn :: Dataset a -> Dataset b -> Column -> IO DataFrame
joinOn d1 d2 colexpr = [java| $d1.join($d2, $colexpr) |]

crossJoin :: Dataset a -> Dataset b -> IO (Dataset Row)
crossJoin d1 d2 = [java| $d1.crossJoin($d2) |]

sample :: Bool -> Double -> Dataset a -> IO (Dataset Row)
sample withReplacement fraction d1 =
    [java| $d1.sample($withReplacement, $fraction) |]

dropDuplicates :: [Text] -> Dataset a -> IO (Dataset Row)
dropDuplicates cols ds = do
    jCols <- reflect cols
    [java| $ds.dropDuplicates($jCols) |]

orderBy :: [Column] -> Dataset a -> IO (Dataset Row)
orderBy cols ds = do
    jCols <- reflect cols
    [java| $ds.orderBy($jCols) |]

sortWithinPartitions :: [Column] -> Dataset a -> IO (Dataset Row)
sortWithinPartitions cols ds =
  withLocalRef (toArray (Data.Coerce.coerce cols :: [J ('Class "org.apache.spark.sql.Column")])) $ \jCols ->
  [java| $ds.sortWithinPartitions($jCols) |]

sort :: [Column] -> Dataset a -> IO (Dataset a)
sort cols ds =
    withLocalRef (toArray (Data.Coerce.coerce cols
               :: [J ('Class "org.apache.spark.sql.Column")])) $ \jcols ->
      [java| $ds.sort($jcols) |]

sortByColumnNames :: [Text] -> Dataset a -> IO (Dataset a)
sortByColumnNames [] _ = error "sortByColNames: empty list of column names"
sortByColumnNames (cname : cnames) ds =
    withLocalRef (reflect cname) $ \jn ->
    withLocalRef (reflect cnames) $ \jns ->
      [java| $ds.sort($jn, $jns) |]

except :: Dataset a -> Dataset a -> IO (Dataset Row)
except ds1 ds2 = [java| $ds1.except($ds2) |]

intersect :: Dataset a -> Dataset a -> IO (Dataset Row)
intersect ds1 ds2 = [java| $ds1.intersect($ds2) |]

columns :: Dataset a -> IO [Text]
columns df = [java| $df.columns() |] >>= reify

printSchema :: Dataset a -> IO ()
printSchema df = [java| { $df.printSchema(); } |]

distinct :: Dataset a -> IO (Dataset a)
distinct d = [java| $d.distinct() |]

repartition :: Int32 -> Dataset a -> IO (Dataset a)
repartition nbPart d = [java| $d.repartition($nbPart) |]

coalesce :: Int32 -> Dataset a -> IO (Dataset a)
coalesce nbPart ds = [java| $ds.coalesce($nbPart) |]

collectAsList :: forall a. Reify a => Dataset a -> IO [a]
collectAsList d =
    [java| $d.collectAsList().toArray() |] >>= reify . jcast
  where
    jcast :: JObjectArray -> J ('Array (Interp a))
    jcast = unsafeCast

newtype DataFrameReader = DataFrameReader (J ('Class "org.apache.spark.sql.DataFrameReader"))
  deriving Coercible

newtype DataFrameWriter = DataFrameWriter (J ('Class "org.apache.spark.sql.DataFrameWriter"))
  deriving Coercible

read :: SparkSession -> IO DataFrameReader
read ss = [java| $ss.read() |]

write :: Dataset a -> IO DataFrameWriter
write df = call df "write"

readParquet :: [Text] -> DataFrameReader -> IO DataFrame
readParquet fps dfr = do
    jfps <- reflect fps
    call dfr "parquet" jfps

writeParquet :: Text -> DataFrameWriter -> IO ()
writeParquet fp dfw = do
    jfp <- reflect fp
    call dfw "parquet" jfp

formatReader :: Text -> DataFrameReader -> IO DataFrameReader
formatReader source dfr = do
    jsource <- reflect source
    [java| $dfr.format($jsource) |]

formatWriter :: Text -> DataFrameWriter -> IO DataFrameWriter
formatWriter source dfw = do
    jsource <- reflect source
    [java| $dfw.format($jsource) |]

optionReader :: Text -> Text -> DataFrameReader -> IO DataFrameReader
optionReader key value dfr = do
    jkey <- reflect key
    jv <- reflect value
    [java| $dfr.option($jkey, $jv) |]

optionWriter
  :: Text -> Text -> DataFrameWriter -> IO DataFrameWriter
optionWriter key value dfw = do
    jkey <- reflect key
    jv <- reflect value
    [java| $dfw.option($jkey, $jv) |]

load :: Text -> DataFrameReader -> IO DataFrame
load path dfr = do
    jpath <- reflect path
    [java| $dfr.load($jpath) |]

save :: Text -> DataFrameWriter -> IO ()
save path dfw = do
    jpath <- reflect path
    [java| { $dfw.save($jpath); } |]

schema :: Dataset a -> IO StructType
schema df = [java| $df.schema() |]

select :: Dataset a -> [Column] -> IO DataFrame
select d1 colexprs = do
    jCols <- reflect colexprs
    [java| $d1.select($jCols) |]

whereDS :: Dataset a -> Column -> IO (Dataset a)
whereDS d1 colexpr = [java| $d1.where($colexpr) |]

count :: Dataset a -> IO Int64
count df = [java| $df.count() |]

col :: Dataset a -> Text -> IO Column
col d1 t = do
    colName <- reflect t
    [java| $d1.col($colName) |]

filter
  :: ( Reflect (MapPartitionsFunction a a)
     , Typeable a
     )
  => Closure (a -> Bool)
  -> Dataset a
  -> IO (Dataset a)
filter clos ds = do
    enc <- getEncoder ds
    mapPartitions clos' enc ds
  where clos' = closure (static S.filter) `cap` clos

filterByCol :: Column -> Dataset a -> IO (Dataset a)
filterByCol c ds = [java| $ds.filter($c) |]

map :: forall a b.
       ( Reflect (MapPartitionsFunction a b)
       , Typeable b
       , Typeable a
       )
  => Closure (a -> b)
  -> Encoder b
  -> Dataset a
  -> IO (Dataset b)
map clos enc ds = mapPartitions clos' enc ds
  where
    clos' :: Closure (Stream (Of a) IO () -> Stream (Of b) IO ())
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
  -> IO b
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
  => Closure (Stream (Of a) IO () -> IO b)
  -> Closure (b -> b -> b)
  -> Dataset a -> IO b
aggregatePartitions seqOp combOp ds = do
    enc <- kryo
    reducePartitions seqOp enc ds
      >>= slowReduce combOp

mapPartitions
  :: Reflect (MapPartitionsFunction a b)
  => Closure (Stream (Of a) IO () -> Stream (Of b) IO ())
  -> Encoder b
  -> Dataset a
  -> IO (Dataset b)
mapPartitions clos enc ds = do
    f <- unsafeUngeneric <$> reflect (MapPartitionsFunction clos)
    [java| $ds.mapPartitions($f, $enc) |]

-- | Like 'mapPartitions', but for a function that produces only a single
-- element partition
reducePartitions
  :: ( Reflect (MapPartitionsFunction a b)
     , Typeable a
     , Typeable b
     )
  => Closure (Stream (Of a) IO () -> IO b)
  -> Encoder b
  -> Dataset a
  -> IO (Dataset b)
reducePartitions fun =
    mapPartitions
      (closure  (static (\f it -> effect $ S.yield <$> f it)) `cap` fun)

reduce
  :: forall a. (Static (Reify a), Static (Reflect a), Typeable a)
  => Closure (a -> a -> a)
  -> Dataset a
  -> IO a
reduce clos ds = do
    f <- unsafeUngeneric <$> reflect (ReduceFunction clos)
    [java| $ds.reduce($f) |]
      >>= reify . jcast
  where
    jcast :: JObject -> J (Interp a)
    jcast = unsafeCast

slowReduce
  :: forall a. (Reflect (ReduceFunction a), Reify a)
  => Closure (a -> a -> a)
  -> Dataset a
  -> IO a
slowReduce clos ds = do
    f <- unsafeUngeneric <$> reflect (ReduceFunction clos)
    [java| $ds.reduce($f) |]
      >>= reify . jcast
  where
    jcast :: JObject -> J (Interp a)
    jcast = unsafeCast

groupBy :: forall a . Dataset a -> [Column] -> IO GroupedData
groupBy d1 colexprs = do
    cols <- reflect colexprs
    [java| $d1.groupBy($cols) |]

agg :: GroupedData -> [Column] -> IO (Dataset Row)
agg _ [] = error "agg: not enough arguments."
agg df (Column jcol : cols) = do
    jcols <- reflect cols
    [java| $df.agg($jcol, $jcols) |]
