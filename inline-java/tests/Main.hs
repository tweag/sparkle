module Main where

import Language.Java (withJVM)
import qualified Spec
import Test.Hspec

main :: IO ()
main = withJVM [] $ hspec Spec.spec
