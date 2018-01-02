package(default_visibility = ["//visibility:public"])

load(
  "@io_tweag_rules_haskell//haskell:haskell.bzl",
  "haskell_binary",
  "haskell_library",
  "haskell_toolchain",
  "haskell_cc_import",
)

load(":sparkle.bzl", "wrap_sparkle_hs")

_sparkle_java_deps = [
  "@org_apache_spark_spark_core_2_10//jar",
  "@org_apache_spark_spark_mllib_2_10//jar",
  "@com_esotericsoftware_kryo//jar",
]

java_binary(
  name = "sparkle-jar",
  deps = _sparkle_java_deps,
  srcs = glob(["src/main/java/io/tweag/sparkle/**/*.java"]),
  main_class = "io.tweag.sparkle.SparkMain",
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
  ],
  prebuilt_dependencies = [
    "base",
    "binary",
    "bytestring",
    "choice",
    "distributed-closure",
    "singletons",
    "streaming",
    "text",
    "vector",
  ],
  data = [
    "@org_scala_lang_scala_library//jar",
  ] + _sparkle_java_deps,
)

haskell_binary(
  name = "sparkle-hs",
  srcs = ["Sparkle_run.hs"],
  main = "Sparkle_run.main",
  deps = [
    ":sparkle-lib",
  ],
  prebuilt_dependencies = [
    "base",
    "bytestring",
    "filepath",
    "process",
    "regex-tdfa",
    "text",
    "zip-archive",
  ],
  compiler_flags = ["-threaded"],
)

wrap_sparkle_hs(
  name = "sparkle",
  sparkle_hs_rule = ":sparkle-hs",
  sparkle_jar_rule = ":sparkle-jar",
)

haskell_toolchain(
  name = "sparkle-toolchain",
  version = "8.2.2",
  tools = "@sparkle-toolchain//:bin",
)
