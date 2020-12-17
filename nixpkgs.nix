args:
let pkgs = import (fetchTarball "https://github.com/tweag/nixpkgs/archive/e7ebd6be80d80000ea9efb62c589a827ba4c22dc.tar.gz") args;
  spark = pkgs.spark.override {
    # TODO: Some part/dependency of spark is unable to cope with newer
    # jdks. The apps/rdd-ops example would fail. Needs further investigation.
    jre = pkgs.openjdk8;
    # hadoop_2_8 allows spark to access s3 resources anonymously
    hadoop = pkgs.hadoop_2_8;
  };
in pkgs // { inherit spark; }
