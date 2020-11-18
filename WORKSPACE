workspace(name = "io_tweag_sparkle")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "rules_haskell",
    sha256 = "a81f63fd05613cc3a3286ab0f4ed5acd527295fef7509184fb62d70e030d7ad1",
    strip_prefix = "rules_haskell-8663806d1611b96c260b7dcd8693dfb5cf302b8b",
    urls = ["https://github.com/tweag/rules_haskell/archive/8663806d1611b96c260b7dcd8693dfb5cf302b8b.tar.gz"],
)

http_archive(
  name = "io_tweag_clodl",
  sha256 = "13c1ca41dca52f13483b33ab1579777b0eb6eeaaaa28fd6164c13cc7704f0d2d",
  strip_prefix = "clodl-cb330384fc0a06632e8e4464921b0bcf7c5fe077",
  urls = ["https://github.com/tweag/clodl/archive/cb330384fc0a06632e8e4464921b0bcf7c5fe077.tar.gz"]
)

http_archive(
  name = "io_tweag_inline_java",
  sha256 = "f5780df3e903e121f360f8deea468226f00cd14cc1ac8cac57aa19762d2da5db",
  strip_prefix = "inline-java-0.9.1",
  urls = ["https://github.com/tweag/inline-java/archive/v0.9.1.tar.gz"],
)

load("@rules_haskell//haskell:repositories.bzl", "haskell_repositories")
haskell_repositories()

load("@io_tweag_rules_nixpkgs//nixpkgs:nixpkgs.bzl",
  "nixpkgs_git_repository",
  "nixpkgs_package",
  "nixpkgs_python_configure",
)

nixpkgs_git_repository(
  name = "nixpkgs",
  # Keep consistent with ./nixpkgs.nix.
  revision = "e7ebd6be80d80000ea9efb62c589a827ba4c22dc",
)

nixpkgs_python_configure(
  repository = "@nixpkgs",
)

RULES_JVM_EXTERNAL_TAG = "3.3"
RULES_JVM_EXTERNAL_SHA = "d85951a92c0908c80bd8551002d66cb23c3434409c814179c0ff026b53544dab"

http_archive(
    name = "rules_jvm_external",
    strip_prefix = "rules_jvm_external-%s" % RULES_JVM_EXTERNAL_TAG,
    sha256 = RULES_JVM_EXTERNAL_SHA,
    url = "https://github.com/bazelbuild/rules_jvm_external/archive/%s.zip" % RULES_JVM_EXTERNAL_TAG,
)

load("@rules_jvm_external//:defs.bzl", "maven_install")

maven_install(
    artifacts = [
	    "org.apache.spark:spark-core_2.11:2.2.0",
        "org.apache.spark:spark-sql_2.11:2.2.0",
        "org.apache.spark:spark-catalyst_2.11:2.2.0",
        "com.esotericsoftware:kryo:3.0.3",
        "org.scala-lang:scala-library:2.11.8",
        "org.scala-lang:scala-reflect:2.11.8",
    ],
    repositories = [
        "https://maven.google.com",
        "https://repo1.maven.org/maven2",
    ],
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


load("@rules_haskell//haskell:cabal.bzl", "stack_snapshot")

stack_snapshot(
    name = "stackage",
    packages = [
        "Cabal",
        "base",
        "binary",
        "bytestring",
        "choice",
        "constraints",
        "containers",
        "deepseq",
        "directory",
        "distributed-closure",
        "exceptions",
        "filemanip",
        "filepath",
        "ghc",
        "hspec",
        "inline-c",
        "language-java",
        "mtl",
        "process",
        "regex-tdfa",
        "singletons",
        "streaming",
        "template-haskell",
        "temporary",
        "text",
        "vector",
        "zip-archive",
    ],
    snapshot = "nightly-2020-11-11",
)

load("@rules_haskell//haskell:nixpkgs.bzl", "haskell_register_ghc_nixpkgs")

nixpkgs_package(
    name = "glibc_locales",
    attribute_path = "glibcLocales",
    build_file_content = """
package(default_visibility = ["//visibility:public"])

filegroup(
    name = "locale-archive",
    srcs = ["lib/locale/locale-archive"],
)
""",
    repository = "@nixpkgs",
)

haskell_register_ghc_nixpkgs(
    attribute_path = "haskell.compiler.ghc8102",
    locale_archive = "@glibc_locales//:locale-archive",
    repositories = {"nixpkgs": "@nixpkgs"},
    version = "8.10.2",
    compiler_flags = [
        "-Werror",
        "-Wall",
        "-Wcompat",
        "-Wincomplete-record-updates",
        "-Wredundant-constraints",
    ],
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
    name = "hspec-discover",
    attribute_path = "haskellPackages.hspec-discover",
    repository = "@nixpkgs",
)

nixpkgs_package(
    name = "openjdk",
    attribute_path = "openjdk11",
    repository = "@nixpkgs",
    build_file_content = """
filegroup(
    name = "bin",
    srcs = ["bin/javac"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "libjvm",
    srcs = ["lib/openjdk/lib/server/libjvm.so"],
    visibility = ["//visibility:public"],
)

cc_library(
    name = "lib",
    srcs = [":libjvm"],
    hdrs = ["include/jni.h", "include/jni_md.h"],
    strip_include_prefix = "include",
    linkstatic = 1,
    visibility = ["//visibility:public"],
)

# XXX Temporary workaround for
# https://github.com/bazelbuild/bazel/issues/8180.
genrule(
    name = "rpath",
    srcs = ["@openjdk//:libjvm"],
    cmd = "libjvm=$(location :libjvm); echo -rpath $$(dirname $$(realpath $$libjvm)) > $@",
    outs = ["openjdk_response_file"],
    visibility = ["//visibility:public"],
)
""",
)
