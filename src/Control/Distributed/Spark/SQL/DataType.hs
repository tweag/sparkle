{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

module Control.Distributed.Spark.SQL.DataType where

import Data.Text (Text)
import Foreign.JNI
import qualified Foreign.JNI.String as JNI
import Language.Java

newtype DataType = DataType (J ('Class "org.apache.spark.sql.types.DataType"))
  deriving Eq
instance Coercible DataType ('Class "org.apache.spark.sql.types.DataType")

staticDataType :: JNI.String -> IO DataType
staticDataType dname = do
    jclass <- findClass "org/apache/spark/sql/types/DataTypes"
    jfield <- getStaticFieldID jclass dname
      (signature (sing :: Sing ('Class "org.apache.spark.sql.types.DataType")))
    DataType . unsafeCast <$> getStaticObjectField jclass jfield

doubleType :: IO DataType
doubleType = staticDataType "DoubleType"

booleanType :: IO DataType
booleanType = staticDataType "BooleanType"

longType :: IO DataType
longType = staticDataType "LongType"

stringType :: IO DataType
stringType = staticDataType "StringType"

typeName :: DataType -> IO Text
typeName dt = call dt "typeName" [] >>= reify
