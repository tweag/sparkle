This is a program that demonstrates that it is possible to crash a `sparkle`
program by creating too many references to (possibly large) Java objects, causing the JVM
to run out of memory. This should serve as a motivation for an interface to
`sparkle` that uses linear types, as such an interface would make any such
proliferation of references more explicit.

In order to observe behavior that crashes the JVM, after building the program
with
```
nix-shell --pure --run "bazel build //apps/memerr:memerr_deploy.jar"
```
The program can be run with:
```
nix-shell --pure --run "bazel run spark-submit -- --driver-memory M $PWD/bazel-bin/apps/memerr/memerr_deploy.jar [OPTIONS]"
```
Where `M` is the memory to be allocated to the spark driver program. A full
description of the available options can be obtained by running the program with
the `--help` flag.

Note that `512M` seems to be the minimum amount of memory that can be allocated
to the driver for the program to run, so this is a good starting point to play
around at. At this memory setting, the default parameters to the program (-n
1500 -l 370 -w 1000) should crash the program by filling up the Java heap. This
basically corresponds to a program in which the Spark driver stores 1500 copies
of ~100K file in memory.
