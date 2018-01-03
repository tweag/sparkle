workspace(name = "io_tweag_sparkle")

http_archive(
  name = "io_tweag_rules_haskell",
  strip_prefix = "rules_haskell-46313a8a76ec0e5666c572d921418ce14988aaa4",
  urls = ["https://github.com/tweag/rules_haskell/archive/46313a8a76ec0e5666c572d921418ce14988aaa4.tar.gz"]
)

local_repository(
  name = "io_tweag_rules_haskell",
  path = "/home/shana/programming/rules_haskell",
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

maven_jar(
  name = "org_apache_spark_spark_core_2_10",
  artifact = "org.apache.spark:spark-core_2.10:1.6.0",
)

maven_jar(
  name = "org_apache_spark_spark_mllib_2_10",
  artifact = "org.apache.spark:spark-mllib_2.10:1.6.0",
)

maven_jar(
  name = "com_esotericsoftware_kryo",
  artifact = "com.esotericsoftware:kryo:4.0.1",
)

maven_jar(
  name = "org_scala_lang_scala_library",
  artifact = "org.scala-lang:scala-library:2.10.5",
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
    javac_wrapped = pkgs.stdenv.mkDerivation {
      name = "javac_wrapped";
      buildInputs = [ pkgs.openjdk pkgs.makeWrapper ];
      phases = [ "installPhase" ];
      installPhase = ''
        mkdir -p $out/bin
        makeWrapper ${pkgs.openjdk}/bin/javac $out/bin/javac \
          --prefix CLASSPATH : "external/org_apache_spark_spark_core_2_10/jar/spark-core_2.10-1.6.0.jar" \
          --prefix CLASSPATH : "external/org_apache_spark_spark_mllib_2_10/jar/spark-m##llib_2.10-1.6.0.jar" \
          --prefix CLASSPATH : "external/com_esotericsoftware_kryo/jar/kryo-4.0.1.jar" \
          --prefix CLASSPATH : "external/org_scala_lang_scala_library/jar/scala-library-2.10.5.jar"
      '';
    };
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
    javac_wrapped
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
