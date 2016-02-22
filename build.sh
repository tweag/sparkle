#!/usr/bin/env bash

stack --nix build $1
cp $(stack --nix path --local-install-root)/bin/sparkle-example-$1 libhsapp.so
(cd sparkle; stack --nix exec mvn package)
