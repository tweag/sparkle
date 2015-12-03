# First Spark + Haskell application

This project shows an example of a Java Spark application that calls some Haskell code (through C) as part of a `filter()` predicate, hence distributed over each "worker" (executor in Spark terminology) of the cluster.

This is fragile and a bit annoying to build/use.

## Get the code and build it

You must have git, a JDK, maven, the haskell **stack**tool and a freshly-downloaded copy of Apache Spark.

``` bash
# get 'distributed-closure' and modified 'binary'
$ git clone https://github.com/tweag/distributed-closure.git
$ cd distributed-closure/vendor
$ git submodule update --init ./binary
$ cd ../../

# get this repo
$ git clone https://github.com/tweag/sparkle.git
$ cd sparkle
$ git checkout first-spark-hs-app
$ cd simple-spark-app

# compile Java code, generate Java-friendly header
# for the Java -> C -> Haskell bridge
$ mvn package
$ javah -o hs-invoke/HaskellRTS.h -cp target/classes/ HaskellRTS
```

In order for the Java code to call our Haskell/C code, you need to tell Cabal where it can find Java's JNI headers.

Open `hs-invoke/hs-invoke.cabal` and tweak the `include-dirs` line. The first dir is the one that must contain `jni.h` while the second dir is the one that must contain `jni_md.h`, located in a subdir of the former (`darwin/` or `linux/`, from what I've seen).

Finally, build all the Haskell & C code, then the Spark+Java app.

``` bash
$ stack build
```

Now, let's just get our hands on the shared library we've just created.

``` bash
$ bash findLib.sh
```

This command will tell you where to find it and where to copy it. Let's give a name to the `simple-spark-app/` directory and use it when launching the Spark application:

``` bash
$ APPDIR=$PWD ; cd path/to/spark ; bin/spark-submit --class "HelloInvoke" --master local[8] --driver-library-path $APPDIR $APPDIR/target/hs-invoke-1.0.jar
```
