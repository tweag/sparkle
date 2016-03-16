#!/bin/sh

set -e

if [ "$#" -ne 2 ]
then
    echo "Usage: copy-exe.sh <executable> <target-directory>"
    exit 1
fi

DIR=$(${STACK_EXE:-stack} path --local-install-root)
TARGET_DIR=$(mktemp -d)
# Copy dynlibs into target dir, but avoid sensitive "system" ones, for
# which we shouldn't override whatever version is already installed on
# the remote system.
if [ $(uname -s) = Darwin ]
then
    >&2 echo "WARNING: JAR not self contained on OS X (shared libraries not copied)."
else
    for i in $(ldd $DIR/bin/$1 | egrep -v '(libc|libpthread)' | awk '{print $3}' | grep '\.so')
    do
	cp $i $TARGET_DIR
    done
fi
cp $DIR/bin/$1 $TARGET_DIR/hsapp
(cd $TARGET_DIR; zip app *)

# Could use install -D instead. But OS X doesn't support it.
mkdir -p $2
install $TARGET_DIR/app.zip $2/app.zip
rm -rf $TARGET_DIR
