# sparkle

```
$ stack build
$ cd sparkle; mvn package -Dsparkle.app=<app-executable-name>
```

Or, if you want to rely on Nix to provision Spark and Maven in a local
sandbox:

```
$ stack --nix build
$ cd sparkle; stack --nix exec -- mvn package -Dsparkle.app=<app-executable-name>
```

To run:

```
$ spark-submit --class io.tweag.sparkle.SparkMain --master 'local[1]' target/sparkle-0.1.jar
```
