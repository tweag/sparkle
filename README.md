# sparkle: Apache Spark applications in Haskell

[![Build](https://github.com/tweag/sparkle/actions/workflows/build.yml/badge.svg?branch=master)](https://github.com/tweag/sparkle/actions/workflows/build.yml)

*sparkle [spär′kəl]:* a library for writing resilient analytics
applications in Haskell that scale to thousands of nodes, using
[Spark][spark] and the rest of the Apache ecosystem under the hood.
See [this blog post][hello-sparkle] for the details.

[spark]: http://spark.apache.org/
[hello-sparkle]: http://www.tweag.io/posts/2016-02-25-hello-sparkle.html

## Getting started

The tl;dr using the `hello` app as an example on your local machine:
```
$ nix-shell --pure --run "bazel build //apps/hello:sparkle-example-hello_deploy.jar"
$ nix-shell --pure --run "bazel run spark-submit -- --packages com.amazonaws:aws-java-sdk:1.11.920,org.apache.hadoop:hadoop-aws:2.10.2 $PWD/bazel-bin/apps/hello/sparkle-example-hello_deploy.jar"
```

You'll need [Nix][nix] for the above to work.

## How it works

sparkle is a tool for creating self-contained Spark applications in
Haskell. Spark applications are typically distributed as JAR files, so
that's what sparkle creates. We embed Haskell native object code as
compiled by GHC in these JAR files, along with any shared library
required by this object code to run. Spark dynamically loads this
object code into its address space at runtime and interacts with it
via the Java Native Interface (JNI).

## How to use

To run a Spark application the process is as follows:

1. **create** an application in the `apps/` folder, in-repo or as
   a submodule;
1. **build** the app;
1. **submit** it to a local or cluster deployment of Spark.

**If you run into issues, read the Troubleshooting section below
  first.**

### Build

#### Linux

Include the following in a `BUILD.bazel` file next to your source code.
```
package(default_visibility = ["//visibility:public"])

load(
  "@rules_haskell//haskell:defs.bzl",
  "haskell_library",
)

load("@io_tweag_sparkle//:sparkle.bzl", "sparkle_package")

# hello-hs needs to contain a Main module with a main function.
# This main function will be invoked by spark.
haskell_library (
  name = "hello-hs",
  srcs = ...,
  deps = ...,
  ...
)

sparkle_package(
  name = "sparkle-example-hello",
  src = ":hello-hs",
)
```

You might want to add the following settings to your `.bazelrc.local`
file.
```
common --repository_cache=~/.bazel_repo_cache
common --disk_cache=~/.bazel_disk_cache
common --local_cpu_resources=4
```

And then ask [Bazel][bazel] to build a *deploy* jar file.

```
$ nix-shell --pure --run "bazel build //apps/hello:sparkle-example-hello_deploy.jar"
```

#### Other platforms

`sparkle` builds in Mac OS X, but running it requires installing binaries
for `Spark` and maybe `Hadoop` (See [.github/workflows/build.yml](.github/workflows/build.yml).

Another alternative is to build and run `sparkle` via Docker in non-Linux
platforms, using a docker image provisioned with Nix.

#### Integrating `sparkle` in another project

As `sparkle` interacts with the JVM, you need to tell `ghc`
where JVM-specific headers and libraries are. It needs to be able to
locate `jni.h`, `jni_md.h` and `libjvm.so`.

`sparkle` uses `inline-java` to embed fragments of Java code in Haskell
modules, which requires running the `javac` compiler, which must be
available in the `PATH` of the shell. Moreover, `javac` needs to find
the Spark classes that `inline-java` quotations refer to. Therefore,
these classes need to be added to the `CLASSPATH` when building sparkle.
Dependending on your build system, how to do this might vary. In this
repo, we use `gradle` to install Spark, and we query `gradle` to get
the paths we need to add to the `CLASSPATH`.

Additionally, the classes need to be found at runtime to load them.
The main thread can find them, but other threads need to invoke
`initializeSparkThread` or `runInSparkThread` from
`Control.Distributed.Spark`.

If the `main` function terminates with unhandled exceptions, they
can be propagated to Spark with
`Control.Distributed.Spark.forwardUnhandledExceptionsToSpark`. This
allows spark both to report the exception and to cleanup before
termination.

### Submit

Finally, to run your application, for example locally:

```
$ nix-shell --pure --run "bazel run spark-submit -- /path/to/$PWD/<app-target-name>_deploy.jar"
```

The `<app-target-name>` is the name of the Bazel target producing the jar file. See apps in
the [apps/](apps/) folder for examples.

RTS options can be passed as a java property
```
$ nix-shell --pure --run "bazel run spark-submit -- --driver-java-options=-Dghc_rts_opts='+RTS\ -s\ -RTS' <app-target-name>_deploy.jar
```
or as command line arguments
```
$ nix-shell --pure --run "bazel run spark-submit -- <app-target-name>_deploy.jar +RTS -s -RTS
```

See [here][spark-submit] for other options, including launching
a [whole cluster from scratch on EC2][spark-ec2]. This
[blog post][tweag-blog-haskell-paas] shows you how to get started on
the [Databricks hosted platform][databricks] and on
[Amazon's Elastic MapReduce][aws-emr].

[bazel]: https://bazel.build
[docker-build-img]: https://hub.docker.com/r/tweag/sparkle/
[spark-submit]: http://spark.apache.org/docs/1.6.2/submitting-applications.html
[spark-ec2]: http://spark.apache.org/docs/1.6.2/ec2-scripts.html
[nix]: http://nixos.org/nix
[tweag-blog-haskell-paas]: http://www.tweag.io/posts/2016-06-20-haskell-compute-paas-with-sparkle.html
[databricks]: https://databricks.com/
[aws-emr]: https://aws.amazon.com/emr/

## Troubleshooting

### JNI calls in auxiliary threads fail with ClassNotFoundException

The context class loader of threads needs to be set appropriately
before JNI calls can find classes in Spark. Calling
`initializeSparkThread` or `runInSparkThread` from
`Control.Distributed.Spark` should set it.

### Anonymous classes in inline-java quasiquotes fail to deserialize

When using inline-java, it is recommended to use the Kryo serializer,
which is currently not the default in Spark but is faster anyways. If
you don't use the Kryo serializer, objects of anonymous class, which
arise e.g. when using Java 8 function literals,

```haskell
foo :: RDD Int -> IO (RDD Bool)
foo rdd = [java| $rdd.map((Integer x) -> x.equals(0)) |]
```

won't be deserialized properly in multi-node setups. To avoid this
problem, switch to the Kryo serializer by setting the following
configuration properties in your `SparkConf`:

```haskell
do conf <- newSparkConf "some spark app"
   confSet conf "spark.serializer" "org.apache.spark.serializer.KryoSerializer"
   confSet conf "spark.kryo.registrator" "io.tweag.sparkle.kryo.InlineJavaRegistrator"
```

See [#104](https://github.com/tweag/sparkle/issues/104) for more
details.

### java.lang.UnsatisfiedLinkError: /tmp/sparkle-app...: failed to map segment from shared object

Sparkle unzips the Haskell binary program in a temporary location on
the filesystem and then loads it from there. For loading to succeed, the
temporary location must not be mounted with the `noexec` option.
Alternatively, the temporary location can be changed with
```
spark-submit --driver-java-options="-Djava.io.tmpdir=..." \
             --conf "spark.executor.extraJavaOptions=-Djava.io.tmpdir=..."
```

### java.io.IOException: No FileSystem for scheme: s3n

Spark 2.4 requires explicitly specifying extra JAR files to `spark-submit`
in order to work with AWS. To work around this, add an additional 'packages'
argument when submitting the job:

```
spark-submit --packages com.amazonaws:aws-java-sdk:1.11.920,org.apache.hadoop:hadoop-aws:2.8.4
```

## License

Copyright (c) 2015-2016 EURL Tweag.

All rights reserved.

sparkle is free software, and may be redistributed under the terms
specified in the [LICENSE](LICENSE) file.

## Sponsors

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
[![Tweag I/O](http://i.imgur.com/0HK8X4y.png)](http://tweag.io)
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
[![LeapYear](http://i.imgur.com/t9VxRHn.png)](http://leapyear.io)

sparkle is maintained by [Tweag I/O](http://tweag.io/).

Have questions? Need help? Tweet at
[@tweagio](http://twitter.com/tweagio).
