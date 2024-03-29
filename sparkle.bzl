"""Helpers for sparkle packaging."""

load("@io_tweag_clodl//clodl:clodl.bzl", "library_closure")
load("@rules_haskell//haskell:defs.bzl", "haskell_library")

def _mangle_dir(name):
    """Creates a unique directory name from the repo name and package
      name of the package being evaluated, and a given name.
    """
    components = [native.repository_name(), native.package_name(), name]
    components = [c.replace("@", "") for c in components]
    components = [c for c in components if c]
    return "/".join(components).replace("_", "_U").replace("/", "_S")

def sparkle_package(name, src, resource_jars=[], **kwargs):
  libclosure = "libclosure-%s" % name
  
  libclosure_hs_wrapper = libclosure + "-hs-wrapper"
  haskell_library(
	name = libclosure_hs_wrapper,
	srcs = ["@io_tweag_sparkle//:hs-wrapper/FFIWrapper.hs"],
	deps = [src, "@io_tweag_sparkle//:base"],
    compiler_flags = ["-threaded", "-flink-rts"],
  )

  library_closure(
    name = libclosure,
    srcs = [libclosure_hs_wrapper],
    excludes = [
      "^/System/",
      "^/usr/lib/",
      "ld\\.so.*",
      "ld-linux\\.so.*",
      "ld-linux-x86-64\\.so.*",
      "libgcc_s\\.so.*",
      "libc\\.so.*",
      "libcrypt\\.so.*",
      "libdl\\.so.*",
      "libjava\\.so.*",
      "libjli\\.so.*",
      "libjvm\\.so.*",
      "libm\\.so.*",
      "libpthread\\.so.*",
      "librt\\.so.*",
      "libresolv\\.so.*",
      "libstdc++\\.so.*",
      "libutil\\.so.*",
      "libz\\.so.*",
    ],
    **kwargs
  )

  libclosure_renamed = libclosure + "-renamed"
  native.genrule(
    name = libclosure_renamed,
    srcs = [libclosure],
    outs = [_mangle_dir(libclosure) + "/sparkle-app.zip"],
    cmd = "cp $< $@",
  )

  native.java_binary(
    name = name,
    create_executable = False,
    classpath_resources = [libclosure_renamed],
    resource_jars = ["@io_tweag_sparkle//:sparkle-jar"] + resource_jars,
    deploy_manifest_lines = ["Main-Class: io.tweag.sparkle.SparkMain"]
  )
