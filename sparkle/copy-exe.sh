#!/bin/sh

set -e

if [ "$#" -ne 2 ]
then
    echo "Usage: copy-exe.sh <executable> <target-directory>"
    exit 1
fi

case $(uname -s) in
	Darwin)
		PLATFORM="Darwin"
        ;;
	Linux)
		PLATFORM="Linux"
		;;
	*)
		echo "Unsupported platform."
		exit 1
		;;
esac

DIR=$(${STACK_EXE:-stack} path --local-install-root)

# The following does not work with OS X's 'mktemp'
# TARGET_DIR=$(mktemp -d)
# Both OS X and Linux versions seem to support the following though:
if [ -z "$TMPDIR" ]; then
	TMPDIR='/tmp'
fi
TARGET_DIR=$(mktemp -d $TMPDIR/dirXXX)


# Copy dynlibs into target dir, but avoid sensitive "system" ones, for
# which we shouldn't override whatever version is already installed on
# the remote system.

echo $DIR/bin/$1
if [ "$PLATFORM" = "Darwin" ]
then
    # This command yields a bunch of entries with @rpath. Can't copy
    # dylibs if we don't know where they actually are. So we do nothing
    # for now.
    # LIBS=$(otool -L $DIR/bin/$1 | awk '{print $1}' | grep '\.dylib')
    echo "Warning: Not packing libraries on OS X."
else
	LIBS=$(ldd $DIR/bin/$1 | egrep -v '(libc|libpthread)' | awk '{print $3}' | grep '\.so')
	for i in $LIBS
	do
	    cp $i $TARGET_DIR
	done
fi

cp $DIR/bin/$1 $TARGET_DIR/hsapp
(cd $TARGET_DIR; zip app *)

# install's -D flag isn't supported on OS X...
# install -D $TARGET_DIR/app.zip $2/app.zip
# The following should be equivalent.
install -d $2
install $TARGET_DIR/app.zip $2/app.zip
rm -rf $TARGET_DIR
