#!/bin/bash

stack build $1
stack exec -- ghc -o libHaskellRTS.so -dynamic -shared -lHSrts_thr-ghc7.10.2 $(./findLib.sh $1)
cd examples && stack exec mvn package && cd ..
