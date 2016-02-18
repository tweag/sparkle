#!/usr/bin/env bash

stack --nix build $1
stack --nix exec -- ghc -o libhsapp.so -dynamic -shared -lHSrts_thr-ghc7.10.3 $(./findLib.sh $1)
cd examples && stack --nix exec mvn package && cd ..
