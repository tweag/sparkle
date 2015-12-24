{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
module JNI where

import Data.Map (fromList)
import Foreign.Ptr
import Foreign.Storable
import Language.C.Inline.Context
import Language.C.Types

-- data JNIEnv_

-- newtype JNIEnv = JNIEnv (Ptr JNIEnv_)

newtype JObject = JObject (Ptr JObject)
  deriving (Eq, Show, Storable)


jniCtx :: Context
jniCtx = mempty { ctxTypesTable = fromList tytab }
  where
    tytab =
      [ (TypeName "jobject", [t| JObject |]) ]
