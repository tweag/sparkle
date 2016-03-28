{ nixpkgs ? import <nixpkgs> {}}:

with nixpkgs;
with stdenv.lib;

let
  spark = nixpkgs.spark.override { mesosSupport = false; };

  jvmlibdir =
    if stdenv.isLinux
      then "${openjdk}/lib/openjdk/jre/lib/amd64/server"
      else "${openjdk}/jre/lib/server";
in
haskell.lib.buildStackProject {
  name = "sparkle";
  buildInputs =
    [ maven
      openjdk
      spark
      nixpkgs.zip
      # to fetch distributed-closure
      git
      openssh
    ];
  extraArgs = ["--extra-lib-dirs=${jvmlibdir}"];
  # XXX Workaround https://ghc.haskell.org/trac/ghc/ticket/11042.
  LD_LIBRARY_PATH = jvmlibdir;
}
