# Complete spark application in Haskell

The goal of this project is to have a fixed Java application
that simply calls out to a "main" in Haskell land, which will
in turn call Java code (Spark's RDD methods, for example) but
applying _Haskell functions_.

We would like to eventually be able to write something like:

``` haskell
import Control.Distributed.Sparkle as Sparkle

main = do
  sc <- makeSparkContext ...
  let xs = [1..10]
  xs' <- parallelize sc xs
  ys <- Sparkle.map (static (\x -> x * 2)) xs'
  ys' <- Sparkle.toList ys
  forM_ ys' $ print
```

## Build/run it

**Prerequesites:**
* the [Stack][stack] build tool;
* the [Nix][nix] package manager (used under the hood by Stack to
  provision the required system dependencies).

```sh
$ stack exec mvn package
$ stack build
```

Now, let's just get our hands on the shared library we've just created.

```sh
# libHaskellRTS.so if on Linux
# libHaskellRTS.dylib if on OS X
$ stack exec -- ghc -o libHaskellRTS.so -dynamic -shared -fPIC -l<rts> $(./findLib.sh)
```

where `<rts>` stands for the RTS you want to select:
`HSrts_thr-ghc$VERSION` if you don't know which (e.g `HSrts_thr-ghc7.10.2`).

You can now launch your Spark application:

```sh
$ stack exec spark-submit -- --class SparkMain --driver-library-path . --master local[1] target/sparkle-1.0-jar-with-dependencies.jar
```

[stack]: http://haskellstack.org
[nix]: http://nixos.org/nix
