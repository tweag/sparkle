# Sparkle: program Apache Spark applications in Haskell

[![Circle CI](https://circleci.com/gh/tweag/sparkle.svg?style=svg)](https://circleci.com/gh/tweag/sparkle)

The HaskellR project provides an environment for efficiently
processing data using Haskell or R code, interchangeably. HaskellR
allows Haskell functions to seamlessly call R functions and *vice
versa*. It provides the Haskell programmer with the full breadth of
existing R libraries and extensions for numerical computation,
statistical analysis and machine learning.

## Getting started

The tl;dr using the `hello` app as an example:

```
$ stack build hello
$ mvn -f sparkle -Dsparkle.app=sparkle-example-hello package
$ spark-submit --master 'local[1]' sparkle/target/sparkle-0.1.jar
```

*Requirements:*
* the [Stack][stack] build tool;
* either, the [Nix][nix] package manager,
* or, OpenJDK, Maven and Spark >= 1.6 installed from your distro.

To run a Spark application the process is as follows:
1. create an application in the `apps/` folder, in-repo or as
   a submodule;
1. add your app to `stack.yaml`;
1. build the app;
1. package your app into a deployable JAR container;
1. submit it to a local or cluster deployment of Spark.

To build:

```
$ stack [--nix] build
```

You can optionally pass `--nix` to all Stack commands to ask Nix to
provision a local Spark and Maven in a local sandbox for good build
results reproducibility. Otherwise you'll need these installed through
your OS distribution's package manager for the next steps.

To package your app:

```
$ mvn -f sparkle -Dsparkle.app=<app-executable-name> package
```

or with

```
$ stack --nix exec -- mvn -f sparkle -Dsparkle.app=<app-executable-name> package
```

And finally, to run your application, say locally:

```
$ spark-submit --master 'local[1]' target/sparkle-0.1.jar
```

See [here][spark-submit] for other options, including lauching
a [whole cluster from scratch on EC2][spark-ec2].

[stack]: https://github.com/commercialhaskell/stack
[spark-submit]: http://spark.apache.org/docs/latest/submitting-applications.html
[spark-ec2]: http://spark.apache.org/docs/latest/ec2-scripts.html

## License

Copyright (c) 2015-2016 Tweag I/O Limited.

All rights reserved.

Sparkle is free software, and may be redistributed under the terms
specified in the [LICENSE](LICENSE) file.

## About

![Tweag I/O](http://i.imgur.com/0HK8X4y.png)

Sparkle is maintained by [Tweag I/O](http://tweag.io/).

Have questions? Need help? Tweet at
[@tweagio](http://twitter.com/tweagio).
