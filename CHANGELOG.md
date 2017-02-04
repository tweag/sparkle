# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/).

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
