{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Control.Distributed.Spark.ML.Feature.RegexTokenizer where

import Control.Distributed.Spark.SQL.DataFrame
import Data.Singletons (Sing, sing)
import Data.Text (Text)
import Foreign.JNI
import Language.Java

newtype RegexTokenizer = RegexTokenizer (J ('Class "org.apache.spark.ml.feature.RegexTokenizer"))
instance Coercible RegexTokenizer ('Class "org.apache.spark.ml.feature.RegexTokenizer")

newTokenizer :: Text -> Text -> IO RegexTokenizer
newTokenizer icol ocol = do
  tok0 :: RegexTokenizer <- new []
  let patt = "\\p{L}+" :: Text
  let gaps = False
  let jgaps = if gaps then 1 else 0
  jpatt <- reflect patt
  jicol <- reflect icol
  jocol <- reflect ocol
  callStatic
    (sing :: Sing "Helper")
    "setupTokenizer"
    [ coerce tok0
    , coerce jicol
    , coerce jocol
    , JBoolean jgaps
    , coerce jpatt
    ]

tokenize :: RegexTokenizer -> DataFrame -> IO DataFrame
tokenize tok df = call tok "transform" [coerce df]
