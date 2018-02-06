# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/).

## [Unreleased]

### Added

### Changed

## [0.7.3] - 2018-02-06

### Added

* More `RDD` method bindings: `randomSplit`, `mean`,
  `zipWithUniqueId`, `reduceByKey`, `subtractByKey`.

### Changed

* Use inline-java for PairRDD bindings under the hood.
* Updated sparkle to build with distributed-closure-0.4.0.

## [0.7.2] - 2017-12-25

### Added

* More `RDD` method bindings: `sortBy`.

## [0.7.1] - 2017-12-13

### Fixed

* Use StaticPointers for `PairRDD` as a workaround for [GHC bug
  #14204][ghc-14204] occuring when mapping over a PairRDD (see [issue
  #119][issue-119])

## [0.7] - 2017-12-09

## [0.6] - 2017-07-16

### Added

* Support shipping anonymous objects that appear in inline-java
  quasiquotes. You'll need to configure your app to use the Kryo
  serializer for this to work. See FAQ in README. This fixes #104.

### Changed

* Move `parallelize`, `textFile` and `binaryRecords` to `Context`
  module.
* Functions such as `sample` now use the [choice][hackage-choice]
  library to describe the semantics of boolean arguments in their
  types.
* Use inline-java for RDD bindings under the hood.

## [0.5] - 2017-02-21

### Added

* Bind to expm1
* Add bindings to dayofmonth, current_timestamp and current_date.
* Add support for the dataframe condition expressions
* Add bindings to withColumnRenamed, columns, printSchema, Column.expr.
* Bind DataFrame distinct.
* Add bindings for log and log1p for Columns.
* Add binding to Column.cast.
* Add bindings getList and array for columns.
* Add bindings: schema for rows, Metadata type, javaRDD, range, Row
  getters and constructors, StrucType constructors, createDataFrame,
  more DataType bindings.

### Changed

* Prevent Haskell exceptions from escaping apply.
* Update sparkle to work with latest jni which uses ForeignPtr
  for java references.
* Move StructType and friends to modules StructField, DataType and Metadata.
* Rename createRow, rowGet, rowSize, joinPairRDD to have the same names
  as the java methods.

## [0.4]

### Added

* Support for reading/writing Parquet files.
* More `RDD` method bindings: `repartition`, `treeAggregate`,
  `binaryRecords`, `aggregateByKey`, `mapPartitions`, `mapPartitionsWithIndex`.
* More complete `DataFrame` support.
* Intero support.
* `stack ghci` support.
* Support Template Haskell splices and `ANN` annotations that use
  sparkle code.

### Changed

### Fixed

* More reliable initialization of embedded shared library.
* Cleanup temporary files properly.

## [0.3] - 2016-12-27

### Added

* Dockerfile to build sparkle.
* Compatibility with singletons-2.2.
* Add the identity `Reify`/`Reflect` instances.
* Change JNI bindings to use new `JNI.String` type, instead of
  `ByteString`. This new type guarantees the invariants required by
  the JNI API (null-termination in particular).

### Changed

* Remove `Reify`/`Reflect` instances for `Int`. Only instances for
  sized types remain.

### Fixed

* Fix type in `Reify Int` making it incorrect.

## [0.2.0] - 2016-12-13

### Added

* New binding: `getOrCreateSQLContext`.

### Changed

* `getOrCreate` renamed to `getOrCreateSparkContext`.

## [0.1.0.1] - 2016-06-12

### Added

* More bindings to more `call*Method` JNI functions.

### Changed

* Use `getOrCreate` to get `SparkContext`.

## [0.1.0] - 2016-04-25

* Initial release

[ghc-14204]: https://ghc.haskell.org/trac/ghc/ticket/14204
[hackage-choice]: https://hackage.haskell.org/package/choice
[issue-119]: https://github.com/tweag/sparkle/issues/119
