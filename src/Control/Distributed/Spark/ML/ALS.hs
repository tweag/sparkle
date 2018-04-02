{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE UndecidableInstances #-}

{-# OPTIONS_GHC -fplugin=Language.Java.Inline.Plugin #-}

module Control.Distributed.Spark.ML.ALS where

import Prelude hiding (product)
import Control.Distributed.Spark.ML.Rating
import Control.Distributed.Spark.PairRDD
import Control.Distributed.Spark.RDD
import Data.Int
import Data.Vector.Storable (Vector)
import Language.Java
import Language.Java.Inline

newtype ALS = ALS (J ('Class "org.apache.spark.mllib.recommendation.ALS"))
  deriving Coercible

data ALSOptions = ALSOptions
  { rank       :: Int32
  -- ^ ALS rank (latent factor space dimensionality).
  , iterations :: Int32
  -- ^ Iterations count.
  , lambda     :: Double
  -- ^ Lambda (regularization parameter).
  }
  deriving (Eq, Show)

data ImplicitALSOptions = ImplicitALSOptions
  { alpha      :: Double
  -- ^ Implicit ALS alpha parameter (confidence factor for the
  -- relation between observations and preference).
  , alsOptions :: ALSOptions
  }
  deriving (Eq, Show)

newALS :: ALSOptions -> IO ALS
newALS ALSOptions{..} = do
  als :: ALS <- new []
  als' :: ALS <- call als "setRank" [JInt rank]
  als'' :: ALS <- call als' "setIterations" [JInt iterations]
  call als'' "setLambda" [JDouble lambda]

newImplicitALS :: ImplicitALSOptions -> IO ALS
newImplicitALS ImplicitALSOptions{..} = do
  als :: ALS <- newALS alsOptions
  als' :: ALS <- call als "setAlpha" [JDouble alpha]
  call als' "setImplicitPrefs" [JBoolean 1]

newtype MatrixFactorizationModel = MatrixFactorizationModel (J ('Class "org.apache.spark.mllib.recommendation.MatrixFactorizationModel"))
  deriving Coercible

runALS :: ALS -> RDD Rating -> IO MatrixFactorizationModel
runALS als rdd = [java| $als.run($rdd) |]

predict
  :: User
  -> Product
  -> MatrixFactorizationModel
  -> IO Double
predict user product mfm = [java| $mfm.predict($user, $product) |]

predictMany
  :: PairRDD User Product
  -> MatrixFactorizationModel
  -> IO (RDD Rating)
predictMany usersProducts mfm = [java| $mfm.predict($usersProducts) |]

productFeatures
  :: MatrixFactorizationModel
  -> IO (PairRDD Product (Vector Double))
productFeatures mfm =
  fromRDD =<< [java| $mfm.productFeatures().toJavaRDD() |]

userFeatures
  :: MatrixFactorizationModel
  -> IO (PairRDD User (Vector Double))
userFeatures mfm =
  fromRDD =<< [java| $mfm.userFeatures().toJavaRDD() |]

recommendProducts
  :: User
  -> Int32
  -> MatrixFactorizationModel
  -> IO [Rating]
recommendProducts user num mfm =
  reify =<< [java| $mfm.recommendProducts($user, $num) |]

recommendProductsForUsers
  :: Int32
  -> MatrixFactorizationModel
  -> IO (PairRDD User [Rating])
recommendProductsForUsers num mfm =
  fromRDD =<< [java| $mfm.recommendProductsForUsers($num).toJavaRDD() |]

recommendUsers
  :: Product
  -> Int32
  -> MatrixFactorizationModel
  -> IO [Rating]
recommendUsers product num mfm =
  reify =<< [java| $mfm.recommendUsers($product, $num) |]

recommendUsersForProducts
  :: Int32
  -> MatrixFactorizationModel
  -> IO (PairRDD Product [Rating])
recommendUsersForProducts num mfm =
  fromRDD =<< [java| $mfm.recommendUsersForProducts($num).toJavaRDD() |]
