# Description

This "mini-project" shows how one can use static pointers to serialize functions and *invoke them from Java*, through C.

# Building and running

Clone [distributed-closure](https://github.com/tweag/distributed-closure) and this repo and build everything:

``` bash
# get 'distributed-closure' and modified 'binary'
$ git clone https://github.com/tweag/distributed-closure.git
$ cd distributed-closure/vendor
$ git submodule update --init ./binary
$ cd ../../

# get this repo
$ git clone https://github.com/tweag/sparkle.git
$ cd sparkle
$ git checkout export-invoke-to-java
$ cd simple-c-export

# build everything
$ stack build
```

Generate a serialized closure for `f x = x * 2` and the argument `20`:

``` bash
stack exec simple-write-closure -- double.bin 20
```

Run it using static pointer lookup, from haskell:

``` bash
stack exec simple-run-closure-hs -- double.bin arg_double.bin
```

... and do the same in C.

``` bash
stack exec simple-run-closure-c -- double.bin arg_double.bin double_result.bin
```

... and fail to do the same in Java. This one requires some fragile build commands though.

First, open `simple-c-export.cabal` and tweak the `include-dirs` line. The first dir is the one that must contain `jni.h` while the second dir is the one that must contain `jni_md.h`, located in a subdir of the former (`darwin/` or `linux/`, from what I've seen).

Next, run:

``` bash
$ javac HelloInvoke.java
$ javah HelloInvoke

$ cp .stack-work/dist/x86_64-osx/Cabal-1.22.4.0/build/libHSsimple-c-export-0.1-68i7Qs9bE8e9L0dHLMZ51G-ghc7.10.2.dylib libHelloInvoke.dylib
# might need to adapt this line depending on OS, arch, cabal version, lib hash, etc
$ java -classpath . -Djava.path.library=. HelloInvoke double.bin arg_double.bin
```
