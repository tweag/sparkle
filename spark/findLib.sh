DIR=$(pwd)

cd $(stack path --dist-dir)/build
TARGET=$PWD/$(ls | grep "$1" | grep ghc)
cd $DIR

echo $TARGET
