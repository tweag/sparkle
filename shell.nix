{ nixpkgs ? import <nixpkgs> {}}:

with nixpkgs;
with stdenv.lib;

# XXX: Copied from https://github.com/NixOS/nixpkgs/pull/11687.
# Remove when merged.
let
  haskell = { buildStackProject =
    (with pkgs;
      { buildInputs ? []
      , extraArgs ? []
      , LD_LIBRARY_PATH ? ""
      , ...
      }@args:

      stdenv.mkDerivation (args // {

        buildInputs =
          buildInputs ++
          optional stdenv.isLinux glibcLocales ++
          [ ghc pkgconfig ];
  
      STACK_IN_NIX_SHELL=1;
      STACK_IN_NIX_EXTRA_ARGS =
        concatMap (pkg: ["--extra-lib-dirs=${pkg}/lib"
                         "--extra-include-dirs=${pkg}/include"]) buildInputs ++
                  extraArgs;

      # XXX: workaround for https://ghc.haskell.org/trac/ghc/ticket/11042.
      LD_LIBRARY_PATH = "${makeLibraryPath buildInputs}:${LD_LIBRARY_PATH}";

      preferLocalBuild = true;

      configurePhase = args.configurePhase or "stack setup";

      buildPhase = args.buildPhase or "stack build";

      checkPhase = args.checkPhase or "stack test";

      doCheck = args.doCheck or true;

      installPhase = args.installPhase or ''
        stack --local-bin-path=$out/bin build --copy-bins
      '';
}));};

  spark = import ./spark-1.6.0.nix { inherit (nixpkgs) stdenv fetchurl makeWrapper jre pythonPackages mesos; mesosSupport = false; };

  jvmlibdir =
    if stdenv.isLinux
      then "${openjdk}/lib/openjdk/jre/lib/amd64/server"
      else "${openjdk}/jre/lib/server";

in

haskell.buildStackProject {
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
  LD_LIBRARY_PATH = jvmlibdir;
}
