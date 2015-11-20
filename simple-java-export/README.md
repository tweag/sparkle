# Description

This "mini-project" shows how one can use static pointers to serialize functions and *invoke them from C*.

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
$ git checkout export-invoke-to-c
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
stack exec simple-run-closure -- double.bin arg_double.bin
```

... and do the same in C.

``` bash
stack exec simple-c -- double.bin arg_double.bin double_result.bin
```
