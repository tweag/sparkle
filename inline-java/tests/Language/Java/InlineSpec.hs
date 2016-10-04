{-# LANGUAGE DataKinds #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Language.Java.InlineSpec where

import Data.Int
import Language.Java.Inline
import Test.Hspec

spec :: Spec
spec = do
    describe "Java quasiquoter" $ do
      it "Evaluates simple expressions" $ do
        [java| 1 + 1 |] `shouldReturn` (2 :: Int32)

      it "Evaluates simple blocks" $ do
        [java| {
             int x = 1;
             int y = 2;
             return x + y;
           } |] `shouldReturn` (3 :: Int32)

      it "Supports antiquotation variables" $ do
        let x = 1 :: Int32
        [java| $x + 1 |] `shouldReturn` (2 :: Int32)

      it "Supports multiple antiquotation variables" $ do
        let foo = 1 :: Int32
            bar = 2 :: Int32
        [java| $foo + $bar |] `shouldReturn` (3 :: Int32)

      it "Supports antiquotation variables in blocks" $ do
        let z = 1 :: Int32
        [java| { return $z + 1; } |] `shouldReturn` (2 :: Int32)
