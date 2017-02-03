{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

module Control.Distributed.Spark.SQL.StructType where

import Data.Text (Text)
import Foreign.JNI
import qualified Foreign.JNI.String as JNI
import Language.Java

newtype StructType =
    StructType (J ('Class "org.apache.spark.sql.types.StructType"))
instance Coercible StructType ('Class "org.apache.spark.sql.types.StructType")

newtype StructField =
    StructField (J ('Class "org.apache.spark.sql.types.StructField"))
instance Coercible StructField
                   ('Class "org.apache.spark.sql.types.StructField")

newStructType :: [StructField] -> IO StructType
newStructType fs = do
    jfs <- reflect [ j | StructField j <- fs ]
    new [ coerce jfs ]

addStructField :: StructField -> StructType -> IO StructType
addStructField sf st = call st "add" [coerce sf]

newStructField :: Text -> DataType -> Bool -> Metadata -> IO StructField
newStructField sname dt n md = do
    jname <- reflect sname
    new [coerce jname, coerce dt, coerce n, coerce md]

fields :: StructType -> IO [StructField]
fields st = do
    jfields <- call st "fields" []
    Prelude.map StructField <$>
      reify (jfields ::
              J ('Array ('Class "org.apache.spark.sql.types.StructField")))

name :: StructField -> IO Text
name sf = call sf "name" [] >>= reify

nullable :: StructField -> IO Bool
nullable sf = call sf "nullable" []

newtype Metadata = Metadata (J ('Class "org.apache.spark.sql.types.Metadata"))
instance Coercible Metadata ('Class "org.apache.spark.sql.types.Metadata")

emptyMetadata :: IO Metadata
emptyMetadata =
    callStatic (sing :: Sing "org.apache.spark.sql.types.Metadata") "empty" []

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

dataType :: StructField -> IO DataType
dataType sf = call sf "dataType" []

typeName :: DataType -> IO Text
typeName dt = call dt "typeName" [] >>= reify
