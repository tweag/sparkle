{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

module Control.Distributed.Spark.ML.Feature.RegexTokenizer where

import Control.Distributed.Spark.SQL.DataFrame
import Data.Text (Text)
import Foreign.JNI
import Language.Java

newtype RegexTokenizer = RegexTokenizer (J ('Class "org.apache.spark.ml.feature.RegexTokenizer"))
instance Coercible RegexTokenizer ('Class "org.apache.spark.ml.feature.RegexTokenizer")

newTokenizer :: Text -> Text -> IO RegexTokenizer
newTokenizer icol ocol = do
  cls <- findClass "org/apache/spark/ml/feature/RegexTokenizer"
  tok0 <- newObject cls "()V" []
  let patt = "\\p{L}+" :: Text
  let gaps = False
  let jgaps = if gaps then 1 else 0
  jpatt <- reflect patt
  jicol <- reflect icol
  jocol <- reflect ocol
  helper <- findClass "Helper"
  setuptok <- getStaticMethodID helper "setupTokenizer" "(Lorg/apache/spark/ml/feature/RegexTokenizer;Ljava/lang/String;Ljava/lang/String;ZLjava/lang/String;)Lorg/apache/spark/ml/feature/RegexTokenizer;"
  unsafeUncoerce . coerce <$>
    callStaticObjectMethod helper setuptok [ coerce tok0
                                           , coerce jicol
                                           , coerce jocol
                                           , JBoolean jgaps
                                           , coerce jpatt
                                           ]

tokenize :: RegexTokenizer -> DataFrame -> IO DataFrame
tokenize tok df = do
  cls <- findClass "org/apache/spark/ml/feature/RegexTokenizer"
  mth <- getMethodID cls "transform" "(Lorg/apache/spark/sql/DataFrame;)Lorg/apache/spark/sql/DataFrame;"
  unsafeUncoerce . coerce <$>
    callObjectMethod tok mth [coerce df]
