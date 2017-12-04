{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module Control.Distributed.Spark.PairRDD where

import Control.Distributed.Closure
import Control.Distributed.Closure.TH
import Control.Distributed.Spark.Closure (Function2(..))
import Control.Distributed.Spark.Context
import Control.Distributed.Spark.RDD
import Data.Int
import Data.Text (Text)
import Language.Java

newtype PairRDD a b = PairRDD (J ('Class "org.apache.spark.api.java.JavaPairRDD"))
instance Coercible (PairRDD a b) ('Class "org.apache.spark.api.java.JavaPairRDD")

zipWithIndex :: RDD a -> IO (PairRDD a Int64)
zipWithIndex rdd = call rdd "zipWithIndex" []

toRDD :: PairRDD a b -> IO (RDD (Tuple2 a b))
toRDD prdd = do
  scalaRDD <- call prdd "rdd" []
  call (scalaRDD :: J ('Class "org.apache.spark.rdd.RDD")) "toJavaRDD" []

fromRDD :: RDD (Tuple2 a b) -> IO (PairRDD a b)
fromRDD rdd =
  callStatic "org.apache.spark.api.java.JavaPairRDD"
             "fromJavaRDD" [coerce rdd]

join :: PairRDD a b -> PairRDD a c -> IO (PairRDD a (Tuple2 b c))
join prdd0 prdd1 = call prdd0 "join" [coerce prdd1]

keyBy :: Reflect (Closure (v -> k))
      => Closure (v -> k) -> RDD v -> IO (PairRDD k v)
keyBy byKeyOp rdd = do
  jbyKeyOp <- reflect byKeyOp
  call rdd "keyBy" [ coerce jbyKeyOp ]

mapValues :: Reflect (Closure (a -> b))
          => Closure (a -> b) -> PairRDD k a -> IO (PairRDD k b)
mapValues f prdd = do
  jf <- reflect f
  call prdd "mapValues" [coerce jf]

wholeTextFiles :: SparkContext -> Text -> IO (PairRDD Text Text)
wholeTextFiles sc uri = do
  juri <- reflect uri
  call sc "wholeTextFiles" [coerce juri]

justValues :: PairRDD a b -> IO (RDD b)
justValues prdd = call prdd "values" []

aggregateByKey
  :: ( Reflect (Function2 b a b)
     , Reflect (Function2 b b b)
     , Reify b
     , Reflect b
     )
  => Closure (b -> a -> b)
  -> Closure (b -> b -> b)
  -> b
  -> PairRDD k a
  -> IO (PairRDD k b)
aggregateByKey seqOp combOp zero prdd = do
    jseqOp <- reflect (Function2 seqOp)
    jcombOp <- reflect (Function2 combOp)
    jzero <- upcast <$> reflect zero
    call prdd "aggregateByKey"
      [coerce jzero, coerce jseqOp, coerce jcombOp]

zip :: RDD a -> RDD b -> IO (PairRDD a b)
zip rdda rddb = call rdda "zip" [coerce rddb]

sortByKey :: PairRDD a b -> IO (PairRDD a b)
sortByKey prdd = call prdd "sortByKey" []

data Tuple2 a b = Tuple2 a b
  deriving (Show, Eq)

withStatic [d|

  type instance Interp (Tuple2 a b) = 'Class "scala.Tuple2"

  instance (Reify a, Reify b) =>
           Reify (Tuple2 a b) where
    reify jobj =
      Tuple2 <$> ((call jobj "_1" [] :: IO JObject) >>= reify . unsafeCast)
             <*> ((call jobj "_2" [] :: IO JObject) >>= reify . unsafeCast)

  instance (Reflect a, Reflect b) => Reflect (Tuple2 a b) where
    reflect (Tuple2 a b) = do
      ja <- reflect a
      jb <- reflect b
      new [coerce $ upcast ja, coerce $ upcast jb]
 |]
