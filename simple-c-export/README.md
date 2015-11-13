Clone distributed-closure and this repo and build everything:

``` bash
$ git clone https://github.com/tweag/distributed-closure.git
$ git clone https://github.com/tweag/sparkle.git
$ cd sparkle
$ git checkout export-invoke-to-c
$ cd simple-c-export
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

... and fail to do the same in C.

``` bash
# prints a parsing error from `binary`
stack exec simple-c -- double.bin arg_double.bin
```
