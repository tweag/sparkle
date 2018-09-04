workspace(name = "io_tweag_sparkle")

http_archive(
  name = "io_tweag_rules_haskell",
  strip_prefix = "rules_haskell-730d42c225f008a13e48bf5e9c13010174324b8c",
  urls = ["https://github.com/tweag/rules_haskell/archive/730d42c225f008a13e48bf5e9c13010174324b8c.tar.gz"]
)

http_archive(
  name = "io_tweag_clodl",
  strip_prefix = "clodl-52cf5b82b431de8ea6cc7e3d9cc920184d8b7a48",
  urls = ["https://github.com/tweag/clodl/archive/52cf5b82b431de8ea6cc7e3d9cc920184d8b7a48.tar.gz"]
)

http_archive(
  name = "io_tweag_rules_nixpkgs",
  strip_prefix = "rules_nixpkgs-d9df5c834f07c72be1b9e320eb742796557612f8",
  urls = ["https://github.com/tweag/rules_nixpkgs/archive/d9df5c834f07c72be1b9e320eb742796557612f8.tar.gz"],
)

# Required due to rules_haskell use of skylib.
http_archive(
  name = "bazel_skylib",
  strip_prefix = "bazel-skylib-0.2.0",
  urls = ["https://github.com/bazelbuild/bazel-skylib/archive/0.2.0.tar.gz"]
)

http_archive(
  name = "io_tweag_inline_java",
  strip_prefix = "inline-java-3a68626c27ed9c3315dc44ff500a1bf3568c982d",
  urls = ["https://github.com/tweag/inline-java/archive/3a68626c27ed9c3315dc44ff500a1bf3568c982d.tar.gz"],
)

load("@io_tweag_rules_nixpkgs//nixpkgs:nixpkgs.bzl",
  "nixpkgs_git_repository",
  "nixpkgs_package",
)

nixpkgs_git_repository(
  name = "nixpkgs",
  # Keep consistent with ./nixpkgs.nix.
  revision = "1fa2503f9dba814eb23726a25642d2180ce791c3",
)

# Maven dependencies from 'gradle dependencies' + grep on compile
# errors to see what needs to be filled in.
maven_jar(
  name = "org_apache_spark_spark_core",
  artifact = "org.apache.spark:spark-core_2.11:2.2.0",
)

maven_jar(
  name = "org_apache_spark_spark_mllib",
  artifact = "org.apache.spark:spark-mllib_2.11:2.2.0",
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
""",
  build_file_content = """ 
package(default_visibility = [ "//visibility:public" ]) 
 
filegroup(
  name = "bin",
  srcs = glob(["bin/*"]),
)

cc_library( 
  name = "include", 
  hdrs = glob(["lib/ghc-*/include/**/*.h"]),
  strip_include_prefix = glob(["lib/ghc-*/include"], exclude_directories=0)[0],
)
""",
)

nixpkgs_package(
  name = "openjdk",
  repository = "@nixpkgs",
  build_file_content = """
package(default_visibility = [ "//visibility:public" ])
filegroup (
  name = "lib",
  srcs = ["lib/openjdk/jre/lib/amd64/server/libjvm.so"],
  visibility = ["//visibility:public"],
)
filegroup (
  name = "bin",
  srcs = ["bin/javac"],
  visibility = ["//visibility:public"],
)
filegroup (
  name = "jni_header",
  srcs = ["include/jni.h"],
  visibility = ["//visibility:public"],
)
filegroup (
  name = "jni_md_header",
  srcs = ["include/jni_md.h"],
  visibility = ["//visibility:public"],
)
cc_library(
  name = "include",
  hdrs = glob(["include/*.h"]),
  strip_include_prefix = "include",
)
"""
)

nixpkgs_package(
  name = "spark",
  repository = "@nixpkgs",
  build_file_content = """
package(default_visibility = [ "//visibility:public" ])
filegroup (
  name = "spark-submit",
  srcs = ["bin/spark-submit"],
  visibility = ["//visibility:public"],
)
"""
)

register_toolchains("//:sparkle-toolchain")
