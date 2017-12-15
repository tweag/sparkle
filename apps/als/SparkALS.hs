{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE OverloadedLabels #-}
{-# LANGUAGE StaticPointers #-}

module Main where

import Control.Distributed.Closure
import Control.Distributed.Spark as Spark
import Control.Distributed.Spark.ML.ALS
import Control.Distributed.Spark.ML.Rating
import Control.Monad.Random
import Data.Choice
import Data.Int
import Data.Typeable
import Language.Java
import Language.Scala.Tuple

-- | For use with 'join'.
unpackRatings :: RDD Rating -> IO (PairRDD (Tuple2 User Product) Double)
unpackRatings rtgs =
  Spark.fromRDD =<<
  Spark.map
  (closure $ static (\(Rating (u, p, r)) -> Tuple2 (Tuple2 u p) r)) rtgs

dropRatingValues :: RDD Rating -> IO (PairRDD User Product)
dropRatingValues rtgs =
  Spark.fromRDD =<<
  Spark.map (closure $ static (\(Tuple2 (Tuple2 u p) _) -> Tuple2 u p)) =<<
  Spark.toRDD =<<
  unpackRatings rtgs

-- | Calculate Root Mean Squared Error between corresponding values.
-- Return RMSE and the amount of items used for calculation. Unmatched
-- keys are ignored.
rmse :: (Static (Reify a), Typeable a)
     => PairRDD a Double
     -> PairRDD a Double
     -> IO (Double, Int64)
rmse rdd1 rdd2 = do
  joined <- Spark.join rdd1 rdd2
  squaredErrors <-
    mapSnd =<<
    Spark.mapValues
    (closure $ static (\(Tuple2 v1 v2) -> let e = v1 - v2 in e * e))
    joined
  cnt <- Spark.count =<< toRDD joined
  e <- Prelude.sqrt <$> Spark.mean squaredErrors
  return (e, cnt)
  where
    mapSnd pairRdd =
      Spark.map (closure $ static (\(Tuple2 _ v) -> v)) =<< toRDD pairRdd

-- | Produce a list of ratings for each user/product pair. Every
-- product will have the same rating from all users (everyone in this
-- crowd has exactly the same tastes).
mkCrowdRatings :: [User] -> [Product] -> IO [Rating]
mkCrowdRatings users products = do
  ratings <- evalRandIO $ mapM (const $ liftRand (randomR (0, 5))) products
  return $ zipWith (\(u, p) r -> Rating (u, p, r))
    [(u, p) | u <- users, p <- products]
    (cycle ratings)

main :: IO ()
main = do
  conf <- newSparkConf "Spark Alternating Least Squares in Haskell"
  sc   <- getOrCreateSparkContext conf

  -- Generate a sparse dataset of ratings
  let products :: [Product]
      products = [1 .. 100]
      crowdSize = 500
      numCrowds = 50
      users :: [[User]]
      users =
        [ [crowdLeader * crowdSize + 1 .. (crowdLeader + 1) * crowdSize]
        | crowdLeader <- [0 .. numCrowds - 1]
        ]
  rdd <- parallelize sc =<<
         (concat <$> mapM (`mkCrowdRatings` products) users)
  observedRatings <- sample rdd (Without #replacement) 0.05

  cnt <- Spark.count observedRatings
  let splitWeights = [0.7, 0.3]
  [training, validation] <- randomSplit observedRatings splitWeights
  putStrLn $
    "Using a total of " ++ show cnt ++
    " ratings, split " ++ show splitWeights

  r1 <- unpackRatings validation
  validationInputs <- dropRatingValues validation

  -- Grid search for ALS hyper-parameters
  let options =
        [ ALSOptions factors 10 lam
        | factors    <- [2, 5, 10, 20]
        , lam        <- [0.01, 0.05, 0.1, 0.5, 1.0, 5.0, 10.0]
        ]

  forM_ options $ \opts -> do
    als  <- newALS opts
    mfm  <- runALS als training
    predicted <- predictMany validationInputs mfm
    r2 <- unpackRatings predicted
    (err, _) <- rmse r1 r2
    putStrLn $ "ALS options: " ++ show opts ++ ", RMSE: " ++ show err
