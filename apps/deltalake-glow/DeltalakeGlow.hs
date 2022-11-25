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

    session <- do { sess <- builder >>= (`config` conf) >>= getOrCreate
                  ; session <- registerGlow sess >>= registerUDFDenseMatrix
                  ; return session
                  }

    dfBaseVariant <- do { vcfReader <- Dataset.read session >>= Dataset.formatReader "vcf"
                        ; df <- Dataset.load "apps/deltalake-glow/genotypes.vcf" vcfReader
                        ; dfWriter <- Dataset.write df
                        ; deltaWriter <- Dataset.formatWriter "delta" dfWriter >>= Dataset.modeWriter "overwrite"
                        ; Dataset.save "delta-table-glow" deltaWriter
                        ; deltaReader <- Dataset.read session >>= Dataset.formatReader "delta"
                        ; dfBaseVariant <- Dataset.load "delta-table-glow" deltaReader
                        ; return dfBaseVariant
                        }
    Dataset.selectDS dfBaseVariant ["genotypes"] >>= Dataset.show
    Dataset.selectDS dfBaseVariant ["genotypes"] >>= Dataset.printSchema 

    dfVariant <- do { colGenotype <- Dataset.col dfBaseVariant "genotypes"
                    ; colGenotypeStates <- genotypeStates colGenotype
                    ; dfVariant <- Dataset.withColumn "genotype values" colGenotypeStates dfBaseVariant
                    ; return dfVariant
                    }
    dfPhenotype <- do { csvReader <- Dataset.read session >>= Dataset.formatReader "csv"
                      ; csvReaderOptions <- Dataset.optionReader "header" "true" csvReader >>= Dataset.optionReader "inferSchema" "true"
                      ; dfPhenotype <- Dataset.load "apps/deltalake-glow/continuous-phenotypes.csv" csvReaderOptions
                      ; return dfPhenotype
                      }
    dfVariantPheno1 <- do { dfPhenoColNames <- Dataset.columns dfPhenotype
                          ; dfPhenoTrait1 <- Dataset.selectDS dfPhenotype [dfPhenoColNames !! 1]
                          ; dfTrait1Double <- Dataset.as double dfPhenoTrait1
                          ; colTrait1 <- Dataset.collectAsList dfTrait1Double >>= lit
                          ; dfVariantPheno <- Dataset.withColumn "phenotype values" colTrait1 dfVariant
                          ; colPhenoTrait1Name <- lit (dfPhenoColNames !! 1)
                          ; dfVariantPheno1 <- Dataset.withColumn "phenotype" colPhenoTrait1Name dfVariantPheno
                          ; return dfVariantPheno1
                          }
    dfCovariates <- do { csvReader <- Dataset.read session >>= Dataset.formatReader "csv"
                       ; csvReaderOptions <- Dataset.optionReader "header" "true" csvReader >>= Dataset.optionReader "inferSchema" "true"
                       ; dfCovariates <- Dataset.load "apps/deltalake-glow/covariates.csv" csvReaderOptions >>= Dataset.drop "sample_id"
                       ; return dfCovariates
                       }
    dfVariantPhenoCov <- do { nRowsCov <- Dataset.count dfCovariates
                            ; dfCovColNames <- Dataset.columns dfCovariates
                            ; let nRows = (fromIntegral nRowsCov) :: Int32
                            ; let nCols = (fromIntegral (Prelude.length dfCovColNames)) :: Int32
                            ; colCovariate <- concatCov columnAsDoubleList dfCovariates dfCovColNames >>= lit
                            ; dfCovariateList <- Dataset.withColumn "covariates" colCovariate dfVariantPheno1
                            ; dfCovariateMatrix <- callUDFDenseMatrix dfCovariateList nRows nCols  "covariates"
                            ; return dfCovariateMatrix
                            }
    Dataset.selectDS dfVariantPhenoCov ["genotype values", "phenotype values", "cov"] >>= Dataset.printSchema

    colGeno <- Dataset.col dfVariantPhenoCov "genotype values"
    colPheno <- Dataset.col dfVariantPhenoCov "phenotype values"
    colCov <- Dataset.col dfVariantPhenoCov "cov"
    colContig <- Dataset.col dfVariantPhenoCov "contigName"
    colStart <- Dataset.col dfVariantPhenoCov "start"
    colPhenoName <- Dataset.col dfVariantPhenoCov "phenotype"
    colRegression <- linearRegressionGwas colGeno colPheno colCov >>= \regressionColumn -> alias regressionColumn "stats"
    result <- Dataset.select dfVariantPhenoCov [colContig, colStart, colPhenoName, colRegression]
    resultExpand <- do { colResult <- expr "expand_struct(stats)"
                       ; resultExpand <- Dataset.select result [colContig, colStart, colPhenoName, colResult]
                       ; return resultExpand
                       }
    Dataset.show resultExpand
    do { dfWriter <- Dataset.write resultExpand
       ; deltaWriter <- Dataset.formatWriter "delta" dfWriter >>= Dataset.modeWriter "overwrite"
       ; Dataset.save "delta-table-glow-result" deltaWriter
       }
