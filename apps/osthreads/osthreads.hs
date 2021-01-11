{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedLabels #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StaticPointers #-}

-- | Shows that calls to sparkle can happen from multiple OS threads.
--
-- Can be invoked with arguments `+RTS -N4 -RTS` or
-- `FAIR $PWD/apps/osthreads/scheduler-pool.xml` or
-- `FAIR $PWD/apps/osthreads/scheduler-pool.xml FIFO`
module Main (main) where

import Control.Concurrent (forkOS)
import Control.Concurrent.MVar
import Control.Distributed.Closure (closure)
import qualified Control.Distributed.Spark as Spark
import Control.Exception (onException)
import Control.Monad (forM_, void)
import Data.Choice
import Data.Int (Int64)
import qualified Data.Text as Text (pack)
import Foreign.JNI.Types
import Language.Java (withLocalRef)
import Language.Java.Streaming ()
import qualified Streaming.Prelude as Streaming
import System.Clock (Clock(Monotonic), TimeSpec(sec), diffTimeSpec, getTime)
import System.Environment (getArgs)
import Text.Printf (printf)


measure :: IO a -> IO (TimeSpec, a)
measure io = do
    t0 <- getTime Monotonic
    a <- io
    tf <- getTime Monotonic
    return (diffTimeSpec tf t0, a)

partitionSize :: Int64
partitionSize = 1000*10

main :: IO ()
main = (`onException` putStrLn "main terminated with exception") $ do
    conf <- Spark.newSparkConf "osthreads sparkle"
    defaultPoolMode <- getArgs >>= \case
      "FAIR" : poolConfigXmlFile : rest -> do
        putStrLn "spark.scheduler.mode = FAIR"
        void $ Spark.confSet conf "spark.scheduler.mode" "FAIR"
        case rest of
          "FIFO" : _ -> return "FIFO"
          _ -> do
            void $ Spark.confSet conf "spark.scheduler.allocation.file"
                                      (Text.pack poolConfigXmlFile)
            return "FAIR"
      _ -> do
        putStrLn "spark.scheduler.mode = FIFO"
        return "FIFO"
    sc   <- Spark.getOrCreateSparkContext conf
    let xs = [1..66] :: [Int64]
        (xs1, xs') = splitAt (length xs `div` 3) xs
        (xs2, xs3) = splitAt (length xs `div` 3) xs'
        compute :: [Int64] -> IO Int64
        compute ys = Spark.parallelize sc ys
          `withLocalRef` Spark.repartition (fromIntegral $ length ys)
          `withLocalRef` Spark.mapPartitions (Don't #preservePartitions)
               (closure $ static
                 (\_ -> Streaming.each [1..partitionSize])
               )
          `withLocalRef` Spark.reduce (closure $ static (+))

    mv2 <- newEmptyMVar
    _ <- forkOS $ Spark.runInSparkThread $
      measure (compute xs2) >>= putMVar mv2

    mv3 <- newEmptyMVar
    _ <- forkOS $ Spark.runInSparkThread $ do
      Spark.setLocalProperty sc "spark.scheduler.pool" "pool1"
      measure (compute xs3) >>= putMVar mv3

    trs <- sequence [ measure (compute xs1)
                    , takeMVar mv2
                    , takeMVar mv3
                    ]
    let maxt = maximum $ map fst trs
        result = sum $ map snd trs

    let expected = fromIntegral (length xs) * sum [1..partitionSize]
    putStrLn $ "Total sum: " ++ show result ++
               if result == expected then " matches the expected."
                 else " doesn't match the expected (" ++ show expected ++ ")."
    putStrLn $ "Total time: " ++ show (sec maxt) ++ " seconds"
    putStrLn ""
    putStrLn "Job |           pool | start time (s) | end time (s)"
    forM_ (zip3 [1..] trs [ "default (" ++ defaultPoolMode ++ ")"
                          , "default (" ++ defaultPoolMode ++ ")"
                          , "pool1 (FIFO)"]
          )
      $ \(i, (t, _), pname) ->
        printf "%3d | %14s | %14d | %12d\n"
          (i :: Int) (pname :: String) (0 :: Int) (sec t)
