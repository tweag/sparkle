# First Spark + Haskell application

## Getting started

Prerequesites: [stack][stack] and the [Nix][nix] package manager (used
under the hood by Stack to provision the required system
dependencies).

```
$ stack exec mvn package

$ $(stack exec which javah) -o hs-invoke/HaskellRTS.h -cp target/classes/ HaskellRTS
$ stack build
```

Now, let's just get our hands on the shared library we've just created.

``` bash
$ bash findLib.sh
```

This command will tell you where to find it and where to copy it.
Let's give a name to the `simple-spark-app/` directory and use it when
launching the Spark application:

``` bash
$ APPDIR=$PWD ; cd path/to/spark ; bin/spark-submit --class "HelloInvoke" --master local[4] --driver-library-path $APPDIR $APPDIR/target/hs-invoke-1.0-jar-with-dependencies.jar
```

[stack]: http://haskellstack.org
[nix]: http://nixos.org/nix
