{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE UndecidableInstances #-}

module Control.Distributed.Spark.ML.Feature.RegexTokenizer where

import Control.Distributed.Spark.SQL.Dataset
import Data.Text (Text)
import Language.Java
import Language.Java.Inline

imports "org.apache.spark.ml.feature.RegexTokenizer"


newtype RegexTokenizer = RegexTokenizer (J ('Class "org.apache.spark.ml.feature.RegexTokenizer"))
  deriving Coercible

newTokenizer :: Text -> Text -> IO RegexTokenizer
newTokenizer icol ocol = do
  jicol <- reflect icol
  jocol <- reflect ocol
  [java|
    new RegexTokenizer().setInputCol($jicol)
             .setOutputCol($jocol)
             .setGaps(false)
             .setPattern("\\p{L}+")
             .setMinTokenLength(5)
   |]

tokenize :: RegexTokenizer -> DataFrame -> IO DataFrame
tokenize tok df = [java| $tok.transform($df) |]
