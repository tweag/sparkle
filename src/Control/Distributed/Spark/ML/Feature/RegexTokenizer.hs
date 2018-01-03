{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE UndecidableInstances #-}

module Control.Distributed.Spark.ML.Feature.RegexTokenizer where

import Control.Distributed.Spark.SQL.Dataset
import Data.Text (Text)
import Language.Java

newtype RegexTokenizer = RegexTokenizer (J ('Class "org.apache.spark.ml.feature.RegexTokenizer"))
  deriving Coercible

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
    "Helper"
    "setupTokenizer"
    [ coerce tok0
    , coerce jicol
    , coerce jocol
    , JBoolean jgaps
    , coerce jpatt
    ]

tokenize :: RegexTokenizer -> DataFrame -> IO DataFrame
tokenize tok df = call tok "transform" [coerce df]
