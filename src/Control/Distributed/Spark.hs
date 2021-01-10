{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Control.Distributed.Spark (module S) where

import Control.Distributed.Closure as S
import Control.Distributed.Spark.Closure as S
import Control.Distributed.Spark.Context as S
import Control.Distributed.Spark.ML.Feature.CountVectorizer as S
import Control.Distributed.Spark.ML.Feature.RegexTokenizer as S
import Control.Distributed.Spark.ML.Feature.StopWordsRemover as S
import Control.Distributed.Spark.ML.LDA as S
import Control.Distributed.Spark.PairRDD as S
import Control.Distributed.Spark.SQL.Column as S hiding
  (mean)
import Control.Distributed.Spark.SQL.Context as S
import Control.Distributed.Spark.SQL.Encoder as S
import Control.Distributed.Spark.SQL.Row as S
import Control.Distributed.Spark.SQL.SparkSession as S
import Control.Distributed.Spark.RDD as S
import Control.Exception (SomeException, handle)
import Data.Singletons (SomeSing(..))
import qualified Data.Text as Text
import qualified Data.Text.Foreign as Text
import Foreign.JNI
import Language.Java
import Language.Java.Inline
import System.IO


-- This function will be called before running main or any user code in
-- executors.
foreign export ccall sparkle_hs_init :: IO ()

{-# ANN sparkle_hs_init ("HLint: ignore Use camelCase" :: String) #-}
sparkle_hs_init :: IO ()
sparkle_hs_init = do
    startFinalizerThread
    handle (printError "sparkle_hs_init") $ do
      loader <- do
        thr <- callStatic "java.lang.Thread" "currentThread"
        cl <- call (thr :: J ('Class "java.lang.Thread")) "getContextClassLoader"
              <* deleteLocalRef thr
        newGlobalRef cl <* deleteLocalRef cl

      setGetClass loader
      loadJavaWrappers

  where
    -- We need to load classes using the context ClassLoader. Here we
    -- tell jvm to use it.
    setGetClass :: J ('Class "java.lang.ClassLoader") -> IO ()
    setGetClass loader = do
      jclass <- do
        cls <- findClass (referenceTypeName (sing :: Sing ('Class "java.lang.Class")))
        newGlobalRef cls <* deleteLocalRef cls
      forNameID <-
        getStaticMethodID jclass "forName"
          (methodSignature
            [ SomeSing (SClass "java.lang.String")
            , SomeSing (SPrim "boolean")
            , SomeSing (SClass "java.lang.ClassLoader")
            ]
            (SClass "java.lang.Class")
          )

      setGetClassFunction $ \s ->
        Text.useAsPtr (Text.pack $ forNameFQN s) $ \ptr len -> do
          jstr <- newString ptr (fromIntegral len)
          (unsafeCast :: JObject -> JClass)
            <$> callStaticObjectMethod jclass forNameID
                  [coerce jstr, coerce True, coerce loader]
            <* deleteLocalRef jstr

    printError :: String -> SomeException -> IO ()
    printError lbl e = hPutStrLn stderr $ lbl ++ " failed: " ++ show e

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
sparkle_hs_fini = stopFinalizerThread
