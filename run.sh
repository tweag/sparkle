#!/usr/bin/env bash

stack --nix exec spark-submit -- --class SparkMain --driver-library-path .:$(./findLibDir.sh "$1") --master local[1] examples/target/sparkle-1.0-jar-with-dependencies.jar
