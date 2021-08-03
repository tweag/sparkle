{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE LinearTypes #-}

module Control.Distributed.Spark.Safe
  ( module S
  , initializeSparkThread
  , runInSparkThread
  , forwardUnhandledExceptionsToSpark
  ) where

import Control.Concurrent (runInBoundThread, yield)

import Control.Distributed.Closure as S
import Control.Distributed.Spark.Closure as S
import Control.Distributed.Spark.Context as S
import Control.Distributed.Spark.ML.Feature.CountVectorizer as S
import Control.Distributed.Spark.ML.Feature.RegexTokenizer as S
import Control.Distributed.Spark.ML.Feature.StopWordsRemover as S
import Control.Distributed.Spark.ML.LDA as S
import Control.Distributed.Spark.PairRDD as S
import Control.Distributed.Spark.SQL.Column as S hiding
  (count, first, mean)
import Control.Distributed.Spark.SQL.Context as S
import Control.Distributed.Spark.SQL.Encoder as S
import Control.Distributed.Spark.SQL.Row as S
import Control.Distributed.Spark.SQL.SparkSession as S
import Control.Distributed.Spark.RDD as S hiding (coalesce)

import Control.Exception (SomeException, handle)

import Data.IORef (IORef)

import Data.Singletons (SomeSing(..))
import qualified Data.Text as Text
import qualified Data.Text.Foreign as Text

import Data.Unrestricted.Linear

import Foreign.JNI (JVMException(..))
import qualified Foreign.JNI as JNI
import Foreign.JNI.Safe
import Foreign.JNI.String (fromChars)

import Language.Java (JClass, SJType(..), setGetClassFunction)
import Language.Java.Safe as JL
import Language.Java.Inline.Safe

import qualified Prelude.Linear as PL

import System.IO.Linear as L
import System.IO.Resource
import Prelude hiding (IO)
import qualified System.IO as SIO
import System.IO.Unsafe (unsafePerformIO)
import System.Mem (performMajorGC)


-- This function will be called before running main or any user code in
-- executors.
foreign export ccall sparkle_hs_init :: SIO.IO ()

{-# ANN sparkle_hs_init ("HLint: ignore Use camelCase" :: String) #-}
sparkle_hs_init :: SIO.IO ()
sparkle_hs_init = do
    JNI.startFinalizerThread
    handle (printError "sparkle_hs_init") $ withLinearIO $ do
      loader <- do
        cl <- [java| Thread.currentThread().getContextClassLoader() |]
        newGlobalRef cl <* deleteLocalRef cl

      L.writeIORef contextClassLoaderRef loader
      setGetClass loader
      loadJavaWrappers

  where
    -- We need to load classes using the context ClassLoader. Here we
    -- tell jvm to use it.
    setGetClass :: J ('Class "java.lang.ClassLoader") -> L.IO ()
    setGetClass loader = do
      UnsafeUnrestrictedReference jclass <- do
        cls <- findClass (referenceTypeName (sing :: Sing ('Class "java.lang.Class")))
        newGlobalRef_ cls -- <* deleteLocalRef cls
      Ur forNameID <-
        getStaticMethodID jclass "forName"
          (methodSignature
            [ SomeSing (SClass "java.lang.String")
            , SomeSing (SPrim "boolean")
            , SomeSing (SClass "java.lang.ClassLoader")
            ]
            (SClass "java.lang.Class")
          )

      fromSystemIO $ setGetClassFunction $ \s ->
        -- we can't use inline-java here, as the generated code would call
        -- into this function creating an infinite recursion
        Text.useAsPtr (Text.pack $ forNameFQN s) $ \ptr len -> do
          jstr <- JNI.newString ptr (fromIntegral len)
          (unsafeCast :: JObject -> JClass)
            <$> JNI.callStaticObjectMethod jclass forNameID
                  [coerce jstr, coerce True, coerce loader]
            <* deleteLocalRef jstr

    -- We're just printing to stderr, so we don't need to worry about dealing
    -- with handles here
    printError :: String -> SomeException -> IO ()
    printError lbl e = fromSystemIO $ SIO.hPutStrLn SIO.stderr $ lbl ++ " failed: " ++ show e

-- | The fully qualified name of a type as needed by @Class.forName@
forNameFQN :: forall ty. IsReferenceType ty => Sing (ty :: JType) -> String
forNameFQN s0 = case s0 of
    SArray _ -> arrayPrefix s0
    _        -> refName s0
  where
    arrayPrefix :: Sing (ty1 :: JType) -> String
    arrayPrefix (SArray s) = '[' : arrayPrefix s
    arrayPrefix s@(SPrim _) = [primSignature s]
    arrayPrefix s = 'L' : refName s ++ ";"

    refName :: Sing (ty1 :: JType) -> String
    refName (SClass sym) = sym
    refName (SIface sym) = sym
    refName (SGeneric s _) = refName s
    refName s = error $ "refName: impossible " ++ show s

    _ = Dict :: Dict (IsReferenceType ty)

-- This function will be called before running hs_exit.
foreign export ccall sparkle_hs_fini :: IO ()

{-# ANN sparkle_hs_fini ("HLint: ignore Use camelCase" :: String) #-}
sparkle_hs_fini :: IO ()
sparkle_hs_fini = do
  performMajorGC
  stopFinalizerThread
  -- Try yield to give an opportunity to finish the finalizer thread
  -- before shutting down the RTS.
  yield

{-# NOINLINE contextClassLoaderRef #-}
contextClassLoaderRef :: IORef (J ('Class "java.lang.ClassLoader"))
contextClassLoaderRef =
  unsafePerformIO $ newIORef (error "uninitialized contextClassLoader")

-- | Sets the context class loader of the current thread so it can find
-- spark classes
initializeSparkThread :: IO ()
initializeSparkThread = do
  Ur contextClassLoader <- readIORef contextClassLoaderRef
  [java| { Thread.currentThread().setContextClassLoader($contextClassLoader); } |]

-- | Runs a computation in a thread that can call functions from spark
runInSparkThread :: IO a -> IO a
runInSparkThread m =
  runInBoundThread $ runInAttachedThread $ initializeSparkThread >> m

-- | Invoke this functions at the main function to forward any unhandled
-- exceptions to Spark.
forwardUnhandledExceptionsToSpark :: IO () -> IO ()
forwardUnhandledExceptionsToSpark =
    handle (\e ->
      findClass (referenceTypeName (SClass "java.lang.RuntimeException")) `withLocalRef` \jclass ->
      throwNew jclass (fromChars $ show (e :: SomeException))
    ) .
    handle (\(JVMException je) -> throw je)
