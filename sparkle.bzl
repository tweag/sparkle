"""Helpers for sparkle packaging."""

load("@io_tweag_clodl//:clodl/clodl.bzl", "library_closure")

def sparkle_package(name, src, **kwargs):
  libclosure = "libclosure-%s" % name
  
  library_closure(
    name = libclosure,
    srcs = [src],
    outzip = "sparkle-app.zip",
    excludes = [
      "ld\.so.*",
      "ld-linux\.so.*",
      "ld-linux-x86-64\.so.*",
      "libgcc_s\.so.*",
      "libc\.so.*",
      "libcrypt\.so.*",
      "libdl\.so.*",
      "libjava\.so.*",
      "libjli\.so.*",
      "libjvm\.so.*",
      "libm\.so.*",
      "libpthread\.so.*",
      "librt\.so.*",
      "libresolv\.so.*",
      "libstdc++\.so.*",
      "libutil\.so.*",
      "libz\.so.*",
    ],
    **kwargs
  )

  native.java_binary(
    name = name,
    main_class = "io.tweag.sparkle.SparkMain",
    classpath_resources = [libclosure],
    resource_jars = [native.repository_name() + "//:sparkle-jar"],
  )
