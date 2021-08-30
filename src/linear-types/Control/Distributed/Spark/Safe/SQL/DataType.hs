{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LinearTypes #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QualifiedDo #-}
{-# LANGUAGE UndecidableInstances #-}

module Control.Distributed.Spark.Safe.SQL.DataType where

import Prelude.Linear hiding (IO)
import System.IO.Linear as LIO
import Control.Functor.Linear as Linear

import Data.Text (Text)
import Foreign.JNI.Safe
import qualified Foreign.JNI.String as JNI
import Language.Java.Safe
import qualified Language.Java as Java

newtype DataType = DataType (J ('Class "org.apache.spark.sql.types.DataType"))
  deriving Coercible

staticDataType :: JNI.String -> IO DataType
staticDataType dname = Linear.do
    UnsafeUnrestrictedReference jclass <- findClass (referenceTypeName (Java.SClass "org.apache.spark.sql.types.DataTypes"))
    Ur jfield <- getStaticFieldID jclass dname
      (Java.signature (sing :: Sing ('Class "org.apache.spark.sql.types.DataType")))
    deleteLocalRef jclass
    (DataType . unsafeCast <$> getStaticObjectField jclass jfield) <* deleteLocalRef jclass

doubleType :: IO DataType
doubleType = staticDataType "DoubleType"

booleanType :: IO DataType
booleanType = staticDataType "BooleanType"

longType :: IO DataType
longType = staticDataType "LongType"

stringType :: IO DataType
stringType = staticDataType "StringType"

typeName :: DataType %1 -> IO (Ur Text)
typeName dt = call dt "typeName" End >>= reify_
