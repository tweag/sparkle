{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

module Control.Distributed.Spark.PairRDD where

import Control.Distributed.Closure
import Control.Distributed.Spark.Closure ()
import Control.Distributed.Spark.Context
import Control.Distributed.Spark.RDD
import Data.Int
import Data.Text (Text)
import Language.Java

newtype PairRDD a b = PairRDD (J ('Class "org.apache.spark.api.java.JavaPairRDD"))
instance Coercible (PairRDD a b) ('Class "org.apache.spark.api.java.JavaPairRDD")

zipWithIndex :: RDD a -> IO (PairRDD Int64 a)
zipWithIndex rdd = call rdd "zipWithIndex" []

wholeTextFiles :: SparkContext -> Text -> IO (PairRDD Text Text)
wholeTextFiles sc uri = do
  juri <- reflect uri
  call sc "wholeTextFiles" [coerce juri]

justValues :: PairRDD a b -> IO (RDD b)
justValues prdd = call prdd "values" []

aggregateByKey
  :: ( Reflect (Closure (b -> a -> b)) ty1
     , Reflect (Closure (b -> b -> b)) ty2
     , Reify b ty3
     , Reflect b ty3
     )
  => Closure (b -> a -> b)
  -> Closure (b -> b -> b)
  -> b
  -> PairRDD k a
  -> IO (PairRDD k b)
aggregateByKey seqOp combOp zero prdd = do
    jseqOp <- reflect seqOp
    jcombOp <- reflect combOp
    jzero <- upcast <$> reflect zero
    call prdd "aggregateByKey"
      [coerce jzero, coerce jseqOp, coerce jcombOp]
