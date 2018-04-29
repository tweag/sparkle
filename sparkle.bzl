"""Helpers for sparkle packaging."""

load("@io_tweag_clodl//:clodl/clodl.bzl", "library_closure")

def sparkle_package(name, src, **kwargs):
  libclosure = "libclosure-%s" % name
  
  library_closure(
    name = libclosure,
    srcs = [src],
    outzip = "sparkle-app.zip",
    excludes = [
      "ld-linux-x86-64\.so.*",
      "libgcc_s\.so.*",
      "libc\.so.*",
      "libdl\.so.*",
      "libm\.so.*",
      "libpthread\.so.*",
    ],
    **kwargs
  )

  native.java_binary(
    name = name,
    main_class = "io.tweag.sparkle.SparkMain",
    classpath_resources = [libclosure],
    resource_jars = [native.repository_name() + "//:sparkle-jar"],
  )
