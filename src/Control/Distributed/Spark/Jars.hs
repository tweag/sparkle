-- | Provides the paths to the jars needed to build with sparkle.
module Control.Distributed.Spark.Jars where

import qualified Language.Java.Streaming.Jars (getJars)
import Paths_sparkle (getDataFileName)

getJars :: IO [String]
getJars = (:) <$> getDataFileName "build/libs/sparkle.jar"
              <*> Language.Java.Streaming.Jars.getJars
