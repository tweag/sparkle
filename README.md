# sparkle: Apache Spark applications in Haskell

[![Circle CI](https://circleci.com/gh/tweag/sparkle.svg?style=svg)](https://circleci.com/gh/tweag/sparkle)

*sparkle [spär′kəl]:* a library for writing resilient analytics
applications in Haskell that scale to thousands of nodes, using
[Spark][spark] and the rest of the Apache ecosystem under the hood.
See [this blog post][hello-sparkle] for the details.

**This is an early tech preview, not production ready.**

[spark]: http://spark.apache.org/
[hello-sparkle]: http://blog.tweag.io/posts/2016-02-25-hello-sparkle.html

## Getting started

The tl;dr using the `hello` app as an example on your local machine:

```
$ stack build hello
$ stack exec -- sparkle package sparkle-example-hello
$ stack exec -- spark-submit --master 'local[1]' sparkle-example-hello.jar
```

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
[tweag-blog-haskell-paas]: http://blog.tweag.io/posts/2016-06-20-haskell-compute-paas-with-sparkle.html
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

## License

Copyright (c) 2015-2016 EURL Tweag.

All rights reserved.

sparkle is free software, and may be redistributed under the terms
specified in the [LICENSE](LICENSE) file.

## About

![Tweag I/O](http://i.imgur.com/0HK8X4y.png)

sparkle is maintained by [Tweag I/O](http://tweag.io/).

Have questions? Need help? Tweet at
[@tweagio](http://twitter.com/tweagio).
