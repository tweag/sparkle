# Call Java from Haskell

From this directory:

``` bash
$ stack build
$ stack exec -- javac -d . Hello.java
$ stack exec java-to-haskell
