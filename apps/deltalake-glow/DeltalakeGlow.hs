{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DataKinds #-}

module Main where

import Control.Distributed.Spark
import Control.Distributed.Spark.SQL.Dataset as Dataset



main :: IO ()
main = forwardUnhandledExceptionsToSpark $ do
    conf <- newSparkConf "Sparkle Dataset demo"
    confSet conf "spark.jars.packages" "io.delta:delta-core_2.11:0.4.0,io.projectglow:glow-spark2_2.11:1.1.2"
    confSet conf "spark.hadoop.io.compression.codecs" "io.projectglow.sql.util.BGZFCodec"
    confSet conf "spark.sql.extensions" "io.delta.sql.DeltaSparkSessionExtension"
    confSet conf "spark.sql.catalog.spark_catalog" "org.apache.spark.sql.delta.catalog.DeltaCatalog"

    session <- builder >>= (`config` conf) >>= getOrCreate >>= registerGlow >>= registerUDFDenseMatrix

    base_variant_df <- Dataset.read session >>= Dataset.formatReader "vcf" >>= Dataset.load "apps/deltalake-glow/genotypes.vcf"

    variant_df <- Dataset.col base_variant_df "genotypes" >>= genotypeStates >>= \colGenotypeStates -> Dataset.withColumn "values" colGenotypeStates base_variant_df
    phenotype_df <- Dataset.read session >>= Dataset.formatReader "csv" >>= Dataset.optionReader "header" "true" >>= Dataset.optionReader "inferSchema" "true" >>= Dataset.load "apps/deltalake-glow/continuous-phenotypes.csv"
    phTrait1 <- Dataset.selectDS phenotype_df ["Continuous_Trait_1"]
    variant_df_pheno <- Dataset.as double phTrait1 >>= Dataset.collectAsList >>= lit >>= \phTrait1Col -> Dataset.withColumn "Trait_1" phTrait1Col variant_df 
    covariates_df <- Dataset.read session >>= Dataset.formatReader "csv" >>= Dataset.optionReader "header" "true" >>= Dataset.optionReader "inferSchema" "true" >>= Dataset.load "apps/deltalake-glow/covariates.csv"

    

    variant_df_pheno_cov <- Dataset.selectDS covariates_df ["independentConfounder4_norm1"] >>= Dataset.as double >>= Dataset.collectAsList >>= lit >>= \covariateCol -> Dataset.withColumn "covariates" covariateCol variant_df_pheno >>= \dfList -> callUDFDenseMatrix dfList "covariates"

    Dataset.selectDS variant_df_pheno_cov ["values","Trait_1","cov"] >>= Dataset.printSchema

    genoCol <- Dataset.col variant_df_pheno_cov "values"
    phenoCol <- Dataset.col variant_df_pheno_cov "Trait_1"
    covCol <- Dataset.col variant_df_pheno_cov "cov"
    regressionCol <- linearRegressionGwas genoCol phenoCol covCol >>= \regressionColumn -> alias regressionColumn "stats"
    result <- Dataset.select variant_df_pheno_cov [regressionCol]
    Dataset.printSchema result
    expr "expand_struct(stats)" >>= \colS -> Dataset.select result [colS] >>= Dataset.show
