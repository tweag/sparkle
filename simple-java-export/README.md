# Description

This "mini-project" shows how one can use static pointers to serialize functions and *invoke them from Java*, through C.

# Building

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
$ cd simple-java-export

# compile Java code, generate Java-friendly header
# for the Java -> C -> Haskell bridge
$ javac HelloInvoke.java
$ javah -o hs-invoke/HelloInvoke.h HelloInvoke
```

In order for the Java code to call our Haskell/C code, you need to tell Cabal where it can find Java's JNI headers.

Open `hs-invoke/hs-invoke.cabal` and tweak the `include-dirs` line. The first dir is the one that must contain `jni.h` while the second dir is the one that must contain `jni_md.h`, located in a subdir of the former (`darwin/` or `linux/`, from what I've seen).

Finally, build all the Haskell & C code.

``` bash
$ stack build
```

# Running

Generate a serialized closure for `f x = x * 2` and the argument `20`:

``` bash
stack exec simple-write-closure -- double.bin 20
```

Run it using static pointer lookup, from haskell:

``` bash
stack exec simple-run-closure-hs -- double.bin arg_double.bin
```

... and do the same in Java!

``` bash
$ cp hs-invoke/.stack-work/dist/x86_64-osx/Cabal-1.22.4.0/build/libHShs-invoke-0.1-5qzCCDWLNw0AXQFdt76TGi-ghc7.10.2.dylib libHelloInvoke.dylib
# ^^^ might need to adapt this line depending on OS, arch, cabal version, lib hash, etc
$ java -classpath . -Djava.path.library=. HelloInvoke double.bin arg_double.bin
# result, encoded with binary, gets written to result.bin
# you can check it works by loading ghci and running:
# decodeFile "result.bin" :: IO Int
```
