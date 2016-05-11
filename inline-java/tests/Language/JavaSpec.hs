{-# LANGUAGE DataKinds #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedStrings #-}
module Language.JavaSpec where

import Data.ByteString (ByteString)
import Data.Int
import Data.Text (Text)
import GHC.TypeLits
import Language.Java
import Test.Hspec

main :: IO ()
main = withJVM [] (hspec spec)

spec :: Spec
spec = describe "callStatic" $ do
  it "allows to call double-returning static functions" $ do
    jstr <- reflect ("1.2345" :: Text)
    callStatic (sing :: Sing "java.lang.Double")
               "parseDouble"
               [coerce jstr]
      `shouldReturn` (1.2345 :: Double)

  it "allows to call int-returning static functions" $ do
    jstr <- reflect ("12345" :: Text)
    callStatic (sing :: Sing "java.lang.Integer")
               "parseInt"
               [coerce jstr]
      `shouldReturn` (12345 :: Int32)
