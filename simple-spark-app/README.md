# First Spark + Haskell application

## Getting started

**Prerequesites:**
* the [Stack][stack] build tool;
* the [Nix][nix] package manager (used under the hood by Stack to
  provision the required system dependencies).

```sh
$ stack exec mvn package
$ stack exec -- java -o hs-invoke/HaskellRTS.h -cp target/classes/ HaskellRTS
$ stack build
```

**NOTE:** You need `stack --version >= 0.1.11` for the above to work,
due to a bug in earlier releases.

Now, let's just get our hands on the shared library we've just created.

```sh
$ ghc -o libHaskellRTS.so -dynamic -shared -fPIC -l<rts> $(./findLib.sh)
```

where `<rts>` stands for the RTS you want to select:
`HSrts_thr-ghc$VERSION` if you don't know which.

This command will tell you where to find it and where to copy it.
Let's give a name to the `simple-spark-app/` directory and use it when
launching the Spark application:

```sh
$ stack exec spark-submit -- --class HelloInvoke --driver-library-path . --master local[1] target/hs-invoke-1.0-jar-with-dependencies.jar
```

[stack]: http://haskellstack.org
[nix]: http://nixos.org/nix
