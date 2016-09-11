{ nixpkgs ? import <nixpkgs> {}, ghc }:

with nixpkgs;

let
  spark = nixpkgs.spark.override { mesosSupport = false; };
  openjdk = openjdk7;
  jvmlibdir =
    if stdenv.isLinux
    then "${openjdk}/lib/openjdk/jre/lib/amd64/server"
    else "${openjdk}/jre/lib/server";
in
haskell.lib.buildStackProject {
  name = "sparkle";
  buildInputs =
    [ gradle
      openjdk
      spark
      which
      zlib
      zip
    ];
  inherit ghc;
  extraArgs = ["--extra-lib-dirs=${jvmlibdir}"];
  # XXX Workaround https://ghc.haskell.org/trac/ghc/ticket/11042.
  LD_LIBRARY_PATH = [jvmlibdir];
}
