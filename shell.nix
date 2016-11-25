{ nixpkgs ? import <nixpkgs> {}
, ghc ? nixpkgs.haskell.compiler.ghc7103   # Default needed for Docker build.
}:

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
  # XXX By default recent Nixpkgs passes hardening flags to the
  # linker. The bindnow hardening flag is problematic, because it
  # makes objects fail to load in GHCi, with strange errors about
  # undefined symbols. See
  # https://ghc.haskell.org/trac/ghc/ticket/12684. As a workaround,
  # disable bindnow for now.
  hardeningDisable = [ "bindnow" ];
}
