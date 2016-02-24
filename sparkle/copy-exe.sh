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
for i in $(ldd $DIR/bin/$1 | egrep -v '(libc|libpthread)' | awk '{print $3}' | grep '\.so')
do
    cp $i $TARGET_DIR
done
cp $DIR/bin/$1 $TARGET_DIR/hsapp
(cd $TARGET_DIR; zip app *)
install -D $TARGET_DIR/app.zip $2/app.zip
rm -rf $TARGET_DIR
