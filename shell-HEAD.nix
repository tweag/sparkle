with import <nixpkgs> {};
import ./shell.nix { ghc = haskell.compiler.ghcHEAD; }
