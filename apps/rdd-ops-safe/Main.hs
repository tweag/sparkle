{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE LinearTypes #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StaticPointers #-}
{-# LANGUAGE QualifiedDo #-}

module Main where

import Control.Distributed.Closure
import qualified Control.Distributed.Spark as Spark
import Control.Distributed.Spark.Safe.RDD as RDD
import Control.Distributed.Spark.Safe.Context

import qualified Prelude as P
import Prelude.Linear hiding (IO, filter, zero, sqrt)
import qualified Prelude.Linear as PL
import System.IO.Linear as LIO
import Control.Functor.Linear as Linear
import Control.Monad.IO.Class.Linear
import qualified Data.Functor.Linear as D

import qualified Data.Text as Text
import Data.Coerce as Coerce
import Foreign.JNI.Safe
import qualified Foreign.JNI.Types
import Language.Java.Safe

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

(=<<) = flip (Linear.>>=)
infixr 1 =<<

main :: P.IO ()
main = Spark.forwardUnhandledExceptionsToSpark $ do
  withLocalFrame $ Linear.do
    conf <- newSparkConf "RDD operations demo"
    sc   <- getOrCreateSparkContext conf
    rdd  <- parallelize sc $ Text.words "The quick brown fox jumps over the lazy dog"
    (rdd0, rdd1, rdd2, rdd3, rdd4, rdd5) <- newLocalRef6 rdd
    print =<< collect rdd0
    -- Does not work, because we don't have reify and reflect instances for
    -- streams - this might require jvm-streaming-safe
    print =<< RDD.reduce (closure P.$ static (\a b -> b P.<> " " P.<> a)) rdd1
    print =<< collect =<< RDD.map (closure $ static Text.reverse) rdd2
    print =<< RDD.take 3 rdd3
    print =<< collect =<< RDD.distinct rdd4
    printU =<< RDD.fold (closure P.$ static (P.||)) False
           =<< RDD.map (closure P.$ static (P.=="dog")) rdd5
  where 
    print :: Show a => Ur a %1 -> IO ()
    print (Ur a) = LIO.fromSystemIO (P.print a)

    printU :: Show a => Ur a %1 -> IO (Ur ())
    printU (Ur a) = LIO.fromSystemIOU (P.print a)
