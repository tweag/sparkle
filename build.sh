#!/usr/bin/env bash

stack build $1
stack exec -- ghc -o libHaskellRTS.so -dynamic -shared -lHSrts_thr-ghc7.10.3 $(./findLib.sh $1)
cd examples && stack exec mvn package && cd ..
