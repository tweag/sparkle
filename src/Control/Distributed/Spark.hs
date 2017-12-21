module Control.Distributed.Spark (module S) where

import Control.Distributed.Closure as S
import Control.Distributed.Spark.Closure as S
import Control.Distributed.Spark.Context as S
import Control.Distributed.Spark.ML.Feature.CountVectorizer as S
import Control.Distributed.Spark.ML.Feature.RegexTokenizer as S
import Control.Distributed.Spark.ML.Feature.StopWordsRemover as S
import Control.Distributed.Spark.ML.LDA as S
import Control.Distributed.Spark.PairRDD as S
import Control.Distributed.Spark.SQL.Column as S
import Control.Distributed.Spark.SQL.Context as S
import Control.Distributed.Spark.SQL.Encoder as S
import Control.Distributed.Spark.SQL.Row as S
import Control.Distributed.Spark.SQL.SparkSession as S
import Control.Distributed.Spark.RDD as S
import Foreign.JNI.Types (JNIEnv, JClass)
import Foreign.Ptr (Ptr)
import Language.Java.Inline

foreign export ccall
  "Java_io_tweag_sparkle_Sparkle_loadJavaWrappers"
  jniLoadJavaWrappers
  :: Ptr JNIEnv
  -> Ptr JClass
  -> IO ()

jniLoadJavaWrappers :: Ptr JNIEnv -> Ptr JClass -> IO ()
jniLoadJavaWrappers _ _ = loadJavaWrappers
