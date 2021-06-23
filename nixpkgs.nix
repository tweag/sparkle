# Trying to workaround
# https://github.com/NixOS/nixpkgs/issues/105573
#
# by going to a commit before the one introducing the regression.
args:
let pkgs = import (fetchTarball "https://github.com/tweag/nixpkgs/archive/46113713d4f25579e07b78116a61ab6f178f4153.tar.gz") args;

    spark = pkgs.spark.override {
      # TODO: Some part/dependency of spark is unable to cope with newer
      # jdks. The apps/rdd-ops example would fail. Needs further investigation.
      jre = pkgs.openjdk8;
      # hadoop_2_8 allows spark to access s3 resources anonymously
      hadoop = pkgs.hadoop_2_8;
    };

    stack_ignore_global_hints = pkgs.writeScriptBin "stack" ''
      #!${pkgs.stdenv.shell}
      # Skips the --global-hints parameter to stack. This is
      # necessary when using an unreleased compiler whose hints
      # aren't available yet.
      set -euo pipefail

      declare -a args
      for a in "''$@"
      do
          if [[ "$a" != "--global-hints" ]]
          then
              args+=("$a")
          fi
      done
      # Passing --no-nix is necessary on nixos to stop stack from
      # looking for nixpkgs.
      # --system-ghc is also necessary to pick the unreleased compiler
      # from the PATH.
      exec ${pkgs.stack}/bin/stack --no-nix --system-ghc ''${args[@]}
      '';
 in pkgs // { inherit stack_ignore_global_hints; inherit spark; }
