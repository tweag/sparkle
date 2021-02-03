package(default_visibility = ["//visibility:public"])

load(
  "@rules_haskell//haskell:defs.bzl",
  "haskell_binary",
  "haskell_library",
  "haskell_toolchain",
)
load("@config_settings//:info.bzl", "ghc_version")

_sparkle_java_deps = [
  "@maven//:org_apache_spark_spark_core_2_11",
  "@maven//:com_esotericsoftware_kryo_shaded",
]

java_library(
  name = "sparkle-jar",
  deps = _sparkle_java_deps,
  srcs = glob(["src/main/java/io/tweag/sparkle/**/*.java"]),
)

cc_library(
  name = "sparkle-bootstrap-cc",
  srcs = ["cbits/bootstrap.c", "cbits/io_tweag_sparkle_Sparkle.h"],
  deps = ["@openjdk//:lib", "@rules_haskell_ghc_nixpkgs//:include"],
  linkopts = select({
    "@bazel_tools//src/conditions:darwin": [],
    "//conditions:default": ["-Wl,-z,lazy"],
  }),
  copts = ["-std=c99"],
) 

haskell_library(
  name = "sparkle-lib",
  src_strip_prefix = "src",
  srcs = glob(['src/**/*.hs']) + ["cbits/io_tweag_sparkle_Sparkle.h"],
  extra_srcs = ["cbits/bootstrap.c"],
  deps = [
    "@openjdk//:lib", "@rules_haskell_ghc_nixpkgs//:include",
    "@io_tweag_inline_java//jni",
    "@io_tweag_inline_java//jvm",
    "@io_tweag_inline_java//jvm-streaming",
    "@io_tweag_inline_java//:inline-java",
    "@maven//:org_apache_spark_spark_catalyst_2_11",
    "@maven//:org_apache_spark_spark_mllib_2_11",
    "@maven//:org_apache_spark_spark_mllib_local_2_11",
    "@maven//:org_apache_spark_spark_sql_2_11",
    "@maven//:org_scala_lang_scala_library",
    "@maven//:org_scala_lang_scala_reflect",
    ":sparkle-jar",
    ":sparkle-bootstrap-cc",
	"@stackage//:base",
	"@stackage//:binary",
	"@stackage//:bytestring",
	"@stackage//:choice",
	"@stackage//:constraints",
	"@stackage//:distributed-closure",
	"@stackage//:streaming",
	"@stackage//:text",
	"@stackage//:vector",
  ] + _sparkle_java_deps +
  ([] if ghc_version == "9.0.1" else ["@stackage//:singletons"]),
  plugins = ["@io_tweag_inline_java//:inline-java-plugin"],
)

# Provided for convenience to run sparkle applications.
sh_binary(
    name = "spark-submit",
    srcs = ["@spark//:spark-submit"],
)
