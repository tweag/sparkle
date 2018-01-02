workspace(name = "io_tweag_sparkle")

http_archive(
  name = "io_tweag_rules_haskell",
  strip_prefix = "rules_haskell-7136d1eced6e335feb90f0adb23db96fad0925ff",
  urls = ["https://github.com/tweag/rules_haskell/archive/7136d1eced6e335feb90f0adb23db96fad0925ff.tar.gz"]
)

http_archive(
  name = "io_tweag_rules_nixpkgs",
  strip_prefix = "rules_nixpkgs-53700e429928530f1566cfff3ec00283a123f17f",
  urls = ["https://github.com/tweag/rules_nixpkgs/archive/53700e429928530f1566cfff3ec00283a123f17f.tar.gz"],
)

# Required due to rules_haskell use of skylib.
http_archive(
  name = "bazel_skylib",
  strip_prefix = "bazel-skylib-0.2.0",
  urls = ["https://github.com/bazelbuild/bazel-skylib/archive/0.2.0.tar.gz"]
)

http_archive(
  name = "io_tweag_inline_java",
  strip_prefix = "inline-java-50bbcc2c4d833b261aaacb7b5033123e8f0c6373",
  urls = ["https://github.com/tweag/inline-java/archive/50bbcc2c4d833b261aaacb7b5033123e8f0c6373.tar.gz"],
)

load("@io_tweag_rules_nixpkgs//nixpkgs:nixpkgs.bzl",
  "nixpkgs_git_repository",
  "nixpkgs_package",
)

nixpkgs_git_repository(
  name = "nixpkgs",
  # Keep consistent with ./nixpkgs.nix.
  revision = "4026ea9c8afd09b60896b861a04cc5748fdcdfb4",
)

# Maven dependencies from 'gradle dependencies' + grep on compile
# errors to see what needs to be filled in.
maven_jar(
  name = "org_apache_spark_spark_core",
  artifact = "org.apache.spark:spark-core_2.11:2.2.0",
)

maven_jar(
  name = "org_apache_spark_spark_sql",
  artifact = "org.apache.spark:spark-sql_2.11:2.2.0",
)

maven_jar(
  name = "org_apache_spark_spark_catalyst",
  artifact = "org.apache.spark:spark-catalyst_2.11:2.2.0",
)

maven_jar(
  name = "com_esotericsoftware_kryo_shaded",
  artifact = "com.esotericsoftware:kryo:3.0.3",
)

maven_jar(
  name = "org_scala_lang_scala_library",
  artifact = "org.scala-lang:scala-library:2.11.8",
)

maven_jar(
  name = "org_scala_lang_scala_reflect",
  artifact = "org.scala-lang:scala-reflect:2.11.8",
)


nixpkgs_package(
  name = "sparkle-toolchain",
  repository = "@nixpkgs",
  # This is a hack abusing the fact that CLASSPATH can point at things
  # that don't exist. We pass these jars Haskell part of sparkle as
  # extra dependencies and they are available just in time for that
  # rule. This lets javac be called with the CLASSPATH set. It's not
  # very nice for obvious reasons of hard-coding things.
  nix_file_content = """
let pkgs = import <nixpkgs> {};
in pkgs.buildEnv {
  name = "sparkle-toolchain";
  paths = with pkgs; [
    (haskell.packages.ghc822.ghcWithPackages (p: with p; [
      Cabal
      base
      binary
      bytestring
      choice
      constraints
      containers
      deepseq
      directory
      distributed-closure
      exceptions
      filemanip
      filepath
      ghc
      hspec
      inline-c
      language-java
      mtl
      process
      regex-tdfa
      singletons
      streaming
      template-haskell
      temporary
      text
      vector
      zip-archive
    ]))
    openjdk
  ];
}
"""
)

nixpkgs_package(
  name = "openjdk",
  repository = "@nixpkgs",
  build_file_content = """
filegroup (
  name = "lib",
  srcs = ["nix/lib/openjdk/jre/lib/amd64/server/libjvm.so"],
  visibility = ["//visibility:public"],
)
filegroup (
  name = "jni_header",
  srcs = ["nix/include/jni.h"],
  visibility = ["//visibility:public"],
)
filegroup (
  name = "jni_md_header",
  srcs = ["nix/include/jni_md.h"],
  visibility = ["//visibility:public"],
)"""
)

register_toolchains("//:sparkle-toolchain")
