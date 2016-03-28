# Sparkle: Apache Spark applications in Haskell

[![Circle CI](https://circleci.com/gh/tweag/sparkle.svg?style=svg)](https://circleci.com/gh/tweag/sparkle)

*Sparkle [spär′kəl]:* a library for writing resilient analytics
applications in Haskell that scale to thousands of nodes, using
[Spark][spark] and the rest of the Apache ecosystem under the hood.

**This is an early tech preview, not production ready.**

[spark]: http://spark.apache.org/

## Getting started

The tl;dr using the `hello` app as an example on your local machine:

```
$ stack build hello
$ mvn -f sparkle -Dsparkle.app=sparkle-example-hello package
$ spark-submit --master 'local[1]' sparkle/target/sparkle-0.1.jar
```

**Requirements:**
* the [Stack][stack] build tool;
* either, the [Nix][nix] package manager,
* or, OpenJDK, Maven and Spark >= 1.6 installed from your distro.

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
provision a local Spark and Maven in a local sandbox for good build
results reproducibility. Otherwise you'll need these installed through
your OS distribution's package manager for the next steps (and you'll
need to tell Stack how to find the JVM header files and shared
libraries).

To package your app (omit the square bracket part entirely if you're
not using `--nix`):

```
$ [stack --nix exec --] \
  mvn -f sparkle -Dsparkle.app=<app-executable-name> package
```

Finally, to run your application, for example locally:

```
$ [stack --nix exec --] \
  spark-submit --master 'local[1]' sparkle/target/sparkle-0.1.jar
```

See [here][spark-submit] for other options, including lauching
a [whole cluster from scratch on EC2][spark-ec2].

[stack]: https://github.com/commercialhaskell/stack
[spark-submit]: http://spark.apache.org/docs/latest/submitting-applications.html
[spark-ec2]: http://spark.apache.org/docs/latest/ec2-scripts.html
[nix]: http://nixos.org/nix

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
