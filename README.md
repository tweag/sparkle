# Sparkle: Apache Spark applications in Haskell

[![Circle CI](https://circleci.com/gh/tweag/sparkle.svg?style=svg)](https://circleci.com/gh/tweag/sparkle)

*Sparkle [spär′kəl]:* a library for writing resilient analytics
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
$ stack exec sparkle package sparkle-example-hello
$ spark-submit --master 'local[1]' sparkle-example-hello.jar
```

**Requirements:**
* the [Stack][stack] build tool;
* either, the [Nix][nix] package manager,
* or, OpenJDK, Gradle and Spark >= 1.6 installed from your distro.

To run a Spark application the process is as follows:

1. **create** an application in the `apps/` folder, in-repo or as
   a submodule;
1. **add** your app to `stack.yaml`;
1. **build** the app;
1. **package** your app into a deployable JAR container;
1. **submit** it to a local or cluster deployment of Spark.

**If you run into issues, read the Troubleshooting section below
  first.**

To build:

```
$ stack [--nix] build
```

You can optionally pass `--nix` to all Stack commands to ask Nix to
make Spark and Gradle available in a local sandbox for good build
results reproducibility. Otherwise you'll need these installed through
your OS distribution's package manager for the next steps (and you'll
need to tell Stack how to find the JVM header files and shared
libraries).

To package your app (omit everything inside square brackets if you're
not using `--nix`):

```
$ [stack --nix exec --] sparkle package <app-executable-name>
```

Finally, to run your application, for example locally:

```
$ [stack --nix exec --] spark-submit --master 'local[1]' <app-executable-name>.jar
```

The `<app-executable-name>` is any executable name as given in the
`.cabal` file for your app. See apps in the [apps/](apps/) folder for
examples.

See [here][spark-submit] for other options, including lauching
a [whole cluster from scratch on EC2][spark-ec2]. This
[blog post][tweag-blog-haskell-paas] shows you how to get started on
the [Databricks hosted platform][databricks] and on
[Amazon's Elastic MapReduce][aws-emr].

[stack]: https://github.com/commercialhaskell/stack
[spark-submit]: http://spark.apache.org/docs/1.6.2/submitting-applications.html
[spark-ec2]: http://spark.apache.org/docs/1.6.2/ec2-scripts.html
[nix]: http://nixos.org/nix
[tweag-blog-haskell-paas]: http://blog.tweag.io/posts/2016-06-20-haskell-compute-paas-with-sparkle.html
[databricks]: https://databricks.com/
[aws-emr]: https://aws.amazon.com/emr/

### Non-Linux OSes

Sparkle is not currently supported on non-linux OSes, e.g. Mac OS X or Windows. If you want to build and use it from a machine using
such an OS, you can use the provided `Dockerfile` and build everything in [docker](http://docker.io):

```
$ docker build -t sparkle .
```

will create an image named `sparkle` containing everything that's
needed to build sparkle and Spark applications: Stack, Java 8, Gradle.

This image can be used to build sparkle then package and run applications:

```
# stack --docker --docker-image sparkle build
...
```

Note that you will need to edit the `stack.yaml` file to point to
include directories and libraries for building the C bits that
interact with the JVM:

```
extra-include-dirs:
  - '/usr/lib/jvm/java-1.8.0-openjdk-amd64/include'
  - '/usr/lib/jvm/java-1.8.0-openjdk-amd64/include/linux'
extra-lib-dirs:
  - '/usr/lib/jvm/java-1.8.0-openjdk-amd64/jre/lib/amd64/server/'
```

Once everything is built you can generate a spark package and run it using `sparkle`'s command-line:

```
# stack --docker --docker-image sparkle exec sparkle package sparkle-example-hello
```

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

Sparkle is free software, and may be redistributed under the terms
specified in the [LICENSE](LICENSE) file.

## About

![Tweag I/O](http://i.imgur.com/0HK8X4y.png)

Sparkle is maintained by [Tweag I/O](http://tweag.io/).

Have questions? Need help? Tweet at
[@tweagio](http://twitter.com/tweagio).
