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
  tok0 :: RegexTokenizer <- new
  let patt = "\\p{L}+" :: Text
  let gaps = False
  jpatt <- reflect patt
  jicol <- reflect icol
  jocol <- reflect ocol
  callStatic
    "Helper"
    "setupTokenizer"
    tok0
    jicol
    jocol
    gaps
    jpatt

tokenize :: RegexTokenizer -> DataFrame -> IO DataFrame
tokenize tok = call tok "transform"
