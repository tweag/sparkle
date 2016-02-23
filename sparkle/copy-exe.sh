#!/bin/sh

DIR=$(${STACK_EXE:-stack} path --local-install-root)
TARGET_DIR=$(mktemp -d)
for i in $(ldd $DIR/bin/$1 | awk '{print $3}')
do
    cp $i $TARGET_DIR
done
cp $DIR/bin/$1 $TARGET_DIR/hsapp
(cd $TARGET_DIR; ls $TARGET_DIR; zip app *)
[ -d $2 ] || mkdir $2 # make sure src/main/resources exists
install $TARGET_DIR/app.zip $2/app.zip
rm -rf $TARGET_DIR
