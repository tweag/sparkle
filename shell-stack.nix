{ nixpkgs ?  import ./nixpkgs.nix {}
, ghc ? nixpkgs.haskell.compiler.ghc884 # Default needed for Docker build.
}:

with nixpkgs;

let
  openjdk = openjdk8;
  jvmlibdir =
    if stdenv.isLinux
    then "${openjdk}/lib/openjdk/jre/lib/amd64/server"
    else "${openjdk}/jre/lib/server";
  # spark 2.4.4 is build with openjdk14 by default,
  # which causes the rddops example to fail. 
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
