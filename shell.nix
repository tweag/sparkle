{ nixpkgs ? import <nixpkgs> {}
, ghc ? nixpkgs.haskell.compiler.ghc802 # Default needed for Docker build.
}:

with import (fetchTarball https://github.com/nixos/nixpkgs/archive/e91840cfb6b7778f8c29d455a2f24cffa1b4e43e.tar.gz) {};

let
  spark = nixpkgs.spark.override { mesosSupport = false; };
  openjdk = openjdk8;
  jvmlibdir =
    if stdenv.isLinux
    then "${openjdk}/lib/openjdk/jre/lib/amd64/server"
    else "${openjdk}/jre/lib/server";
in
haskell.lib.buildStackProject {
  name = "sparkle";
  buildInputs =
    [ git
      gradle
      ncurses5 # For intero
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
  # XXX By default recent Nixpkgs passes hardening flags to the
  # linker. The bindnow hardening flag is problematic, because it
  # makes objects fail to load in GHCi, with strange errors about
  # undefined symbols. See
  # https://ghc.haskell.org/trac/ghc/ticket/12684. As a workaround,
  # disable bindnow for now.
  hardeningDisable = [ "bindnow" ];
  LANG = "en_US.utf8";
}
