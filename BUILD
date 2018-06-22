package(default_visibility = ["//visibility:public"])

load(
  "@io_tweag_rules_haskell//haskell:haskell.bzl",
  "haskell_binary",
  "haskell_library",
  "haskell_toolchain",
  "haskell_cc_import",
)

_sparkle_java_deps = [
  "@org_apache_spark_spark_core//jar",
  "@com_esotericsoftware_kryo_shaded//jar",
]

java_library(
  name = "sparkle-jar",
  deps = _sparkle_java_deps,
  srcs = glob(["src/main/java/io/tweag/sparkle/**/*.java"]),
)

cc_library(
  name = "sparkle-bootstrap-cc",
  srcs = ["cbits/bootstrap.c", "cbits/io_tweag_sparkle_Sparkle.h"],
  deps = ["@openjdk//:include", "@sparkle-toolchain//:include"],
  copts = ["-std=c99"],
) 

haskell_library(
  name = "sparkle-lib",
  src_strip_prefix = "src",
  srcs = glob(['src/**/*.hs']),
  deps = [
    "@io_tweag_inline_java//jni",
    "@io_tweag_inline_java//jvm",
    "@io_tweag_inline_java//jvm-streaming",
    "@io_tweag_inline_java//:inline-java",
    "@org_apache_spark_spark_catalyst//jar",
    "@org_apache_spark_spark_sql//jar",
    "@org_scala_lang_scala_library//jar",
    "@org_scala_lang_scala_reflect//jar",
    ":sparkle-jar",
    ":sparkle-bootstrap-cc",
  ] + _sparkle_java_deps,
  prebuilt_dependencies = [
    "base",
    "binary",
    "bytestring",
    "choice",
    "constraints",
    "distributed-closure",
    "singletons",
    "streaming",
    "text",
    "vector",
  ],
)

haskell_toolchain(
  name = "sparkle-toolchain",
  version = "8.2.2",
  tools = "@sparkle-toolchain//:bin",
  extra_binaries = ["@openjdk//:bin"],
)

# Provided for convenience to run sparkle applications.
sh_binary(
    name = "spark-submit",
    srcs = ["@spark//:spark-submit"],
)
