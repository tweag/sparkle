args:
let pkgs = import (fetchTarball "https://github.com/tweag/nixpkgs/archive/a3a3dda3bacf61e8a39258a0ed9c924eeca8e293.tar.gz") args;
  spark = pkgs.spark.override {
    # TODO: Some part/dependency of spark is unable to cope with newer
    # jdks. The apps/rdd-ops example would fail. Needs further investigation.
    jre = pkgs.openjdk8;
    # hadoop_2_8 allows spark to access s3 resources anonymously
    hadoop = pkgs.hadoop_2_8;
  };
in pkgs // { inherit spark; }
