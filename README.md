# sparkle: Apache Spark applications in Haskell

[![Build status](https://badge.buildkite.com/79871bedbeeb63a3ac46ad57ad7e2da54255b39abcc09ec85f.svg?branch=master)](https://buildkite.com/tweag-1/sparkle)
[![CircleCI](https://circleci.com/gh/tweag/sparkle.svg?style=svg)](https://circleci.com/gh/tweag/sparkle)

*sparkle [spär′kəl]:* a library for writing resilient analytics
applications in Haskell that scale to thousands of nodes, using
[Spark][spark] and the rest of the Apache ecosystem under the hood.
See [this blog post][hello-sparkle] for the details.

[spark]: http://spark.apache.org/
[hello-sparkle]: http://www.tweag.io/posts/2016-02-25-hello-sparkle.html

## Getting started

The tl;dr using the `hello` app as an example on your local machine:

```
$ stack build hello
$ stack exec -- sparkle package sparkle-example-hello
$ stack exec -- spark-submit --master 'local[1]' --packages com.amazonaws:aws-java-sdk:1.11.253,org.apache.hadoop:hadoop-aws:2.7.2,com.google.guava:guava:23.0 sparkle-example-hello.jar
```

### Using bazel

There is experimental support for [bazel]. This mechanism doesn't require
executing `sparkle package`. Note however, that `bazel` evolves quickly and
you'll need an old version (0.13.0) to use the following instructions.

```
$ bazel build //apps/hello:sparkle-example-hello_deploy.jar
$ bazel run spark-submit -- --packages com.amazonaws:aws-java-sdk:1.11.253,org.apache.hadoop:hadoop-aws:2.7.2,com.google.guava:guava:23.0 $(pwd)/bazel-bin/apps/hello/sparkle-example-hello_deploy.jar
```

[bazel]: https://bazel.build

## How to use

To run a Spark application the process is as follows:

1. **create** an application in the `apps/` folder, in-repo or as
   a submodule;
1. **add** your app to `stack.yaml`;
1. **build** the app;
1. **package** your app into a deployable JAR container;
1. **submit** it to a local or cluster deployment of Spark.

**If you run into issues, read the Troubleshooting section below
  first.**

### Build

#### Linux

**Requirements**

* the [Stack][stack] build tool (version 1.2 or above);
* either, the [Nix][nix] package manager,
* or, OpenJDK, Gradle and Spark (version 1.6) installed from your distro.

To build:

```
$ stack build
```

You can optionally get Stack to download Spark and Gradle in a local
sandbox (using [Nix][nix]) for good build results reproducibility.
**This is the recommended way to build sparkle.** Alternatively,
you'll need these installed through your OS distribution's package
manager for the next steps (and you'll need to tell Stack how to find
the JVM header files and shared libraries).

To use Nix, set the following in your `~/.stack/config.yaml` (or pass
`--nix` to all Stack commands, see the [Stack manual][stack-nix] for
more):

```yaml
nix:
  enable: true
```

#### Other platforms

sparkle is not directly supported on non-Linux operating systems (e.g.
Mac OS X or Windows). But you can use Docker to run sparkle natively
inside a container on those platforms. First,

```
$ stack docker pull
```

Then, just add `--docker` as an argument to *all* Stack commands, e.g.

```
$ stack --docker build
```

By default, Stack uses the [tweag/sparkle][docker-build-img] build and
test Docker image, which includes everything that Nix does as in the
Linux section. See the [Stack manual][stack-docker] for how to modify
the Docker settings.

#### Integrating `sparkle` in another project

As `sparkle` interacts with the JVM, you need to tell `ghc`
where JVM-specific headers and libraries are. It needs to be able to
locate `jni.h`, `jni_md.h` and `libjvm.so`. Doing this with `stack`
is explained in the Troubleshooting section below.

`sparkle` uses `inline-java` to embed fragments of Java code in Haskell
modules, which requires running the `javac` compiler, which must be
available in the `PATH` of the shell. Moreover, `javac` needs to find
the Spark classes that `inline-java` quotations refer to. Therefore,
these classes need to be added to the `CLASSPATH` when building sparkle.
Dependending on your build system, how to do this might vary. In this
repo, we use `gradle` to install Spark, and we query `gradle` to get
the paths we need to add to the `CLASSPATH`. This is done with Cabal
hooks (see [./Setup.hs](./Setup.hs)).

### Package

To package your app as a JAR directly consumable by Spark:

```
$ stack exec -- sparkle package <app-executable-name>
```

### Submit

Finally, to run your application, for example locally:

```
$ stack exec -- spark-submit --master 'local[1]' <app-executable-name>.jar
```

The `<app-executable-name>` is any executable name as given in the
`.cabal` file for your app. See apps in the [apps/](apps/) folder for
examples.

See [here][spark-submit] for other options, including launching
a [whole cluster from scratch on EC2][spark-ec2]. This
[blog post][tweag-blog-haskell-paas] shows you how to get started on
the [Databricks hosted platform][databricks] and on
[Amazon's Elastic MapReduce][aws-emr].

[docker-build-img]: https://hub.docker.com/r/tweag/sparkle/
[stack]: https://github.com/commercialhaskell/stack
[stack-docker]: https://docs.haskellstack.org/en/stable/docker_integration/
[stack-nix]: https://docs.haskellstack.org/en/stable/nix_integration/#configuration
[spark-submit]: http://spark.apache.org/docs/1.6.2/submitting-applications.html
[spark-ec2]: http://spark.apache.org/docs/1.6.2/ec2-scripts.html
[nix]: http://nixos.org/nix
[tweag-blog-haskell-paas]: http://www.tweag.io/posts/2016-06-20-haskell-compute-paas-with-sparkle.html
[databricks]: https://databricks.com/
[aws-emr]: https://aws.amazon.com/emr/

## How it works

sparkle is a tool for creating self-contained Spark applications in
Haskell. Spark applications are typically distributed as JAR files, so
that's what sparkle creates. We embed Haskell native object code as
compiled by GHC in these JAR files, along with any shared library
required by this object code to run. Spark dynamically loads this
object code into its address space at runtime and interacts with it
via the Java Native Interface (JNI).

## Troubleshooting

### `jvm` library or header files not found

You'll need to tell Stack where to find your local JVM installation.
Something like the following in your `~/.stack/config.yaml` should do
the trick, but check that the paths match up what's on your system:

```
extra-include-dirs: [/usr/lib/jvm/java-7-openjdk-amd64/include]
extra-lib-dirs: [/usr/lib/jvm/java-7-openjdk-amd64/jre/lib/amd64/server]
```

Or use `--nix`: since it won't use your globally installed JDK, it
will have no trouble finding its own locally installed one.

### Can't build sparkle on OS X

OS X is not a supported platform for now. There are several issues to
make sparkle work on OS X, tracked
[in this ticket](https://github.com/tweag/sparkle/issues/12).

### Gradle <= 2.12 incompatible with JDK 9

If you're using JDK 9, note that you'll need to either downgrade to
JDK 8 or update your Gradle version, since Gradle versions up to and
including 2.12 are not compatible with JDK 9.

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

Spark 2.2 requires explicitly specifying extra JAR files to `spark-submit`
in order to work with AWS. To work around this, add an additional 'packages'
argument when submitting the job:

```
spark-submit --packages com.amazonaws:aws-java-sdk:1.7.4,org.apache.hadoop:hadoop-aws:2.7.2,com.google.guava:guava:12.0
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
