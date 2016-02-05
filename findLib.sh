DIR=$(pwd)

TARGETDIR=$(./findLibDir.sh "$1")
TARGET=$TARGETDIR/$(ls "$TARGETDIR" | grep "$1" | grep ghc)
cd $DIR

echo $TARGET
