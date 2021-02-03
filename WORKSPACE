workspace(name = "io_tweag_sparkle")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "rules_haskell",
    sha256 = "f54eac4fd769de1c0146ab7dbb507129d6d27e2c533b42ed34baca3841f0329f",
    strip_prefix = "rules_haskell-aafcd4c3fc622e8c336b6905b0bc4a21aac09dbb",
    urls = ["https://github.com/tweag/rules_haskell/archive/aafcd4c3fc622e8c336b6905b0bc4a21aac09dbb.tar.gz"],
)

http_archive(
  name = "io_tweag_clodl",
  sha256 = "dd3729c49c169fa632ced79e5680e60a072b3204a8044daac4f51832ddae74a3",
  strip_prefix = "clodl-4143916be74a0d048fea5aaca465c6581313a2f8",
  urls = ["https://github.com/tweag/clodl/archive/4143916be74a0d048fea5aaca465c6581313a2f8.tar.gz"]
)

http_archive(
  name = "io_tweag_inline_java",
  sha256 = "52f61aa7069343667fba6f428fca5768d74b1240cefeb9620ba12c0779f21afc",
  strip_prefix = "inline-java-a466217e2d382702b1809162ee0bad2ae4812dc0",
  urls = ["https://github.com/tweag/inline-java/archive/a466217e2d382702b1809162ee0bad2ae4812dc0.tar.gz"],
)

load("@rules_haskell//haskell:repositories.bzl", "haskell_repositories")
haskell_repositories()

load("@io_tweag_rules_nixpkgs//nixpkgs:nixpkgs.bzl",
  "nixpkgs_local_repository",
  "nixpkgs_package",
  "nixpkgs_python_configure",
)

nixpkgs_local_repository(
    name = "nixpkgs",
    nix_file = "//:nixpkgs.nix",
)

nixpkgs_python_configure(
  repository = "@nixpkgs",
)

nixpkgs_package(
    name = "sed",
    attribute_path = "gnused",
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
        "org.apache.spark:spark-mllib_2.11:2.2.0",
        "org.apache.spark:spark-mllib-local_2.11:2.2.0",
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

nixpkgs_package(
    name = "stack_ignore_global_hints",
    attribute_path = "stack_ignore_global_hints",
    repository = "@nixpkgs",
)

load("//:config_settings/setup.bzl", "config_settings")
config_settings(name = "config_settings")
load("@config_settings//:info.bzl", "ghc_version")

load("@rules_haskell//haskell:cabal.bzl", "stack_snapshot")

stack_snapshot(
    name = "stackage",
    packages = [
        "Cabal",
        "async",
        "base",
        "binary",
        "bytestring",
        "choice",
        "clock",
        "constraints",
        "containers",
        "criterion",
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
        "stm",
        "streaming",
        "template-haskell",
        "temporary",
        "text",
        "vector",
        "zip-archive",
    ] + (["linear-base"] if ghc_version == "9.0.1" else ["singletons"]),
    snapshot = "nightly-2020-11-11" if ghc_version == "8.10.2" else None,
    local_snapshot = "//:snapshot-9.0.1.yaml" if ghc_version == "9.0.1" else None,
    stack = "@stack_ignore_global_hints//:bin/stack" if ghc_version == "9.0.1" else None,
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
    attribute_path = "haskell.compiler.ghc901"
        if ghc_version == "9.0.1" else "haskell.compiler.ghc8102",
    locale_archive = "@glibc_locales//:locale-archive",
    repositories = {"nixpkgs": "@nixpkgs"},
    version = ghc_version if ghc_version == "8.10.2" else "9.0.0.20201227",
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
    attribute_path = "openjdk8",
    repository = "@nixpkgs",
    build_file_content = """
filegroup(
    name = "bin",
    srcs = ["bin/javac"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "libjvm",
    srcs = select({
        "@bazel_tools//src/conditions:darwin": ["jre/lib/server/libjvm.dylib"],
        "//conditions:default": ["lib/openjdk/jre/lib/amd64/server/libjvm.so"],
    }),
    visibility = ["//visibility:public"],
)

cc_library(
    name = "lib",
    # Don't link libjvm in osx, otherwise sparkle will try to load it a second time
    srcs = select({
      "@bazel_tools//src/conditions:darwin": [],
      "//conditions:default": [":libjvm"],
    }),
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

http_archive(
    name = "com_github_bazelbuild_buildtools",
    strip_prefix = "buildtools-840218fa3afc7e7145c1eeb3bfeb612c497e67f7",
	sha256 = "0dba3995084990d557f3bbb7f7eca4ebcc71d5c9d758eca49342e69fc41e061c",
    url = "https://github.com/bazelbuild/buildtools/archive/840218fa3afc7e7145c1eeb3bfeb612c497e67f7.zip",
)
