#!/usr/bin/env python

import os
import sys
from subprocess import call

args = []
for i in range(1, len(sys.argv)):
    # Quote all arguments, just in case they were so originally.
    args.append("\"%s\"" % sys.argv[i])
    # XXX hack: If calling Stack have to pass env var as arguments.
    if sys.argv[i] == 'stack':
        args.append('$STACK_IN_NIX_EXTRA_ARGS')

command = ["nix-shell", "/shell.nix", "--run"] + [' '.join(args)]

call(command)
