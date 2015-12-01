{-# LANGUAGE StaticPointers #-}
module Simple where

import Control.Distributed.Closure
import Data.Binary (encode)
import Spark

import qualified Data.ByteString as BS

f :: Int -> Int
f x = x * 2

wrappedF :: BS.ByteString -> BS.ByteString
wrappedF = wrap1 f

fClosure :: Closure (BS.ByteString -> BS.ByteString)
fClosure = closure (static wrappedF)

fSerialized = encode fClosure
