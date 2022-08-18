{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE UndecidableInstances #-}

module Control.Distributed.Spark.ML.LinearRegressionGwas where

import Language.Java
import Language.Java.Inline
import Data.Text (Text)
import Control.Distributed.Spark.SQL.Dataset 
import Control.Distributed.Spark.SQL.SparkSession (SparkSession)
import Control.Distributed.Spark.SQL.Column (Column) 

imports "static org.apache.spark.sql.functions.udf"
imports "static org.apache.spark.sql.functions.callUDF"
imports "org.apache.spark.sql.api.java.UDF1"
imports "org.apache.spark.ml.linalg.Matrix"
imports "org.apache.spark.ml.linalg.DenseMatrix"
imports "org.apache.spark.sql.SQLUtils"
imports "scala.collection.mutable.WrappedArray"
imports "java.util.ArrayList"
imports "java.util.List"

imports "io.projectglow.Glow"
imports "io.projectglow.functions"


newtype UserDefinedFunction = UserDefinedFunction (J ('Class "org.apache.spark.sql.expressions.UserDefinedFunction"))

registerGlow :: SparkSession -> IO SparkSession
registerGlow ss =
  [java| Glow.register($ss,true) |]

genotypeStates :: Column -> IO Column
genotypeStates genotypes =
  [java| functions.genotype_states($genotypes) |]

linearRegressionGwas :: Column -> Column -> Column -> IO Column
linearRegressionGwas genotypes phenotypes covariates =
  [java| functions.linear_regression_gwas($genotypes, $phenotypes, $covariates) |]
    
registerUDFDenseMatrix :: SparkSession -> IO SparkSession
registerUDFDenseMatrix ss =
  [java|
       {
       UDF1 generateDenseMatrix = new UDF1<WrappedArray<Double>, Matrix>(){
           public Matrix call(final WrappedArray<Double> cov) throws Exception {
               List<Double> doubleList = new ArrayList<Double>();
               for(int i=0; i<cov.size(); i++){
                   doubleList.add(cov.apply(i));
               }
               double[] cov1 = doubleList.stream().mapToDouble(i -> i).toArray();
               Matrix output = new DenseMatrix(2504, 1, cov1);
               return output;
           }
       };
       $ss.udf().register("generateDenseMatrix", generateDenseMatrix, SQLUtils.newMatrixUDT());
       return $ss;
  }
  |]

callUDFDenseMatrix :: Dataset a -> Text -> IO (Dataset a)
callUDFDenseMatrix df t = do
  colName <- reflect t
  [java| $df.withColumn("cov", callUDF("generateDenseMatrix", $df.col($colName))) |]
