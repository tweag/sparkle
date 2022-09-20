{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DataKinds #-}

module Main where

import Control.Distributed.Spark
import Control.Distributed.Spark.SQL.Dataset as Dataset
import Data.Int (Int32)


main :: IO ()
main = forwardUnhandledExceptionsToSpark $ do
    conf <- newSparkConf "Sparkle Dataset demo"
    confSet conf "spark.jars.packages" "io.delta:delta-core_2.11:0.4.0,io.projectglow:glow-spark2_2.11:1.1.2"
    confSet conf "spark.hadoop.io.compression.codecs" "io.projectglow.sql.util.BGZFCodec"
    confSet conf "spark.sql.extensions" "io.delta.sql.DeltaSparkSessionExtension"
    confSet conf "spark.sql.catalog.spark_catalog" "org.apache.spark.sql.delta.catalog.DeltaCatalog"

    session <- builder >>= (`config` conf) >>= getOrCreate >>= registerGlow >>= registerUDFDenseMatrix

    Dataset.read session >>= Dataset.formatReader "vcf" >>= Dataset.load "apps/deltalake-glow/genotypes.vcf" >>= Dataset.write >>= Dataset.formatWriter "delta" >>= Dataset.modeWriter "overwrite" >>= Dataset.save "delta-table-glow"
    dfBaseVariant <- Dataset.read session >>= Dataset.formatReader "delta" >>= Dataset.load "delta-table-glow"
    Dataset.selectDS dfBaseVariant ["genotypes"] >>= Dataset.show
    Dataset.selectDS dfBaseVariant ["genotypes"] >>= Dataset.printSchema 

    dfVariant <- Dataset.col dfBaseVariant "genotypes" >>= genotypeStates >>= \colGenotypeStates -> Dataset.withColumn "genotype values" colGenotypeStates dfBaseVariant
    dfPhenotype <- Dataset.read session >>= Dataset.formatReader "csv" >>= Dataset.optionReader "header" "true" >>= Dataset.optionReader "inferSchema" "true" >>= Dataset.load "apps/deltalake-glow/continuous-phenotypes.csv"
    dfPhenColNames <- Dataset.columns dfPhenotype    
    phTrait1 <- Dataset.selectDS dfPhenotype [dfPhenColNames !! 1]
    dfVariantPheno <- Dataset.as double phTrait1 >>= Dataset.collectAsList >>= lit >>= \phTrait1Col -> Dataset.withColumn "phenotype values" phTrait1Col dfVariant
    phTrait1NameCol <- lit (dfPhenColNames !! 1)
    dfVariantPheno1 <- Dataset.withColumn "phenotype" phTrait1NameCol dfVariantPheno
    
    dfCovariates <- Dataset.read session >>= Dataset.formatReader "csv" >>= Dataset.optionReader "header" "true" >>= Dataset.optionReader "inferSchema" "true" >>= Dataset.load "apps/deltalake-glow/covariates.csv" >>= Dataset.drop "sample_id"
    nRowsCov <- Dataset.count dfCovariates
    covColNames <- Dataset.columns dfCovariates
    let nRows = (fromIntegral nRowsCov) :: Int32
    let nCols = (fromIntegral (Prelude.length covColNames)) :: Int32    
    dfVariantPhenoCov <- concatCov columnAsDoubleList dfCovariates covColNames >>= lit >>= \covariateCol -> Dataset.withColumn "covariates" covariateCol dfVariantPheno1 >>= \dfList -> callUDFDenseMatrix dfList nRows nCols  "covariates"
       
    Dataset.selectDS dfVariantPhenoCov ["genotype values", "phenotype values", "cov"] >>= Dataset.printSchema

    genoCol <- Dataset.col dfVariantPhenoCov "genotype values"
    phenoCol <- Dataset.col dfVariantPhenoCov "phenotype values"
    covCol <- Dataset.col dfVariantPhenoCov "cov"
    contigCol <- Dataset.col dfVariantPhenoCov "contigName"
    startCol <- Dataset.col dfVariantPhenoCov "start"
    phenoNameCol <- Dataset.col dfVariantPhenoCov "phenotype"
    regressionCol <- linearRegressionGwas genoCol phenoCol covCol >>= \regressionColumn -> alias regressionColumn "stats"
    result <- Dataset.select dfVariantPhenoCov [contigCol, startCol, phenoNameCol, regressionCol]
    resultExpand <- expr "expand_struct(stats)" >>= \statsCol -> Dataset.select result [contigCol, startCol, phenoNameCol, statsCol]
    Dataset.show resultExpand
    Dataset.write resultExpand >>= Dataset.formatWriter "delta" >>= Dataset.modeWriter "overwrite" >>= Dataset.save "delta-table-glow-result"

    
