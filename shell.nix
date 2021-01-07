{ pkgs ? import ./nixpkgs.nix {} }:

with pkgs;

mkShell {
  buildInputs = [
    bazel
    binutils
    cacert
    gcc
    git
    nix
    openjdk8
    python3
    pax-utils
    stack
    unzip
    which
    zip
    # packages for convenience
    less
  ];
  hardeningDisable = [ "bindnow" ];
  LANG = "en_US.utf8";
  NIXPKGS_ALLOW_INSECURE = 1;
  BAZEL_USE_CPP_ONLY_TOOLCHAIN=1;
}
