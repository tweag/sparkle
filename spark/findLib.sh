DIR=$(pwd)

cd $(stack path --dist-dir)/build
TARGET=$PWD/$(ls | grep "spark" | grep ghc)
cd $DIR

echo $TARGET
