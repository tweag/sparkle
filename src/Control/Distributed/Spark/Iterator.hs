{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

module Control.Distributed.Spark.Iterator
  ( Iterator(..)
  , JIterator
  , emptyIterator
  , foldIterator
  , singletonIterator
  ) where

import Control.Distributed.Closure.TH
import Data.Int
import Data.IORef
import Foreign.JNI
import Foreign.Ptr
import Foreign.StablePtr
import Language.Java
import System.IO (fixIO)


-- | This is a haskell representation for iterators.
newtype Iterator a = Iterator (IO (Maybe (a, Iterator a)))
type JIterator a = 'Iface "java.util.Iterator" <> '[a]
type instance Interp (Iterator a) = JIterator (Interp (Uncurry a))

type JHaskellIterator = J ('Class "io.tweag.sparkle.HaskellIterator")

sparkle_iterator_next :: Int64 -> JObject -> IO JObject
sparkle_iterator_next i this = do
    f <- deRefStablePtr $ castPtrToStablePtr $ intPtrToPtr $ fromIntegral i
    f this

foreign export ccall sparkle_iterator_next :: Int64 -> JObject -> IO JObject

withStatic [d|

  instance Reify a t => Reify (Iterator a) (JIterator t) where
    reify jiterator = return $ Iterator $ do
      b <- call jiterator "hasNext" []
      if b then do
        jx <- call jiterator "next" []
        x <- reify $ unsafeCast (jx :: JObject)
        fmap Just $ (,) x <$> reify jiterator
      else return Nothing

  instance Reflect a t => Reflect (Iterator a) (JIterator t) where
    reflect (Iterator maIterator) = maIterator >>= \case
      Nothing -> unsafeCast <$> newHaskellIterator 0 True
      Just (itFirst, iterator) -> do
        r <- newIORef (itFirst, iterator)
        selfClass <- findClass "io/tweag/sparkle/HaskellIterator"
        fieldEndId <- getFieldID selfClass "end" "Z"
        -- iteratorPtr is called once per element
        iteratorPtr <- fixIO $ \iteratorPtr -> newStablePtr $ \jthis -> do
          (previous, Iterator maIterator') <- readIORef r
          maIterator' >>= \case
            Nothing     -> do
              -- When the stream ends, set the end field to True
              -- so the HaskellIterable class knows not to call
              -- woStreamPtr again.
              setBooleanField (jthis :: JHaskellIterator) fieldEndId True
              -- We release the pointer here or in the finalizer of
              -- HaskellIterable (whichever happens first).
              freeStablePtr iteratorPtr
            Just next -> writeIORef r next
          reflect previous
        let ptr = fromIntegral $ ptrToIntPtr $ castStablePtrToPtr iteratorPtr
        unsafeCast <$> newHaskellIterator ptr False
     where
      newHaskellIterator :: Int64 -> Bool -> IO JHaskellIterator
      newHaskellIterator ptr end = new [coerce ptr, coerce end]
 |]

-- | If xs if the list of values provided by the iterator
--
-- > foldIterator f z it == return (foldr f z xs)
--
foldIterator :: (b -> a -> b) -> b -> Iterator a -> IO b
foldIterator f z (Iterator iter) = iter >>= \case
    Nothing         -> return z
    Just (x, iter') -> case f z x of
      !z' -> foldIterator f z' iter'

-- | Produces an iterator containing a single element.
singletonIterator :: IO a -> Iterator a
singletonIterator m = Iterator $ do
    x <- m
    return $ Just (x, emptyIterator)

-- | Produces an iterator with no elements.
emptyIterator :: Iterator a
emptyIterator = Iterator $ return Nothing
