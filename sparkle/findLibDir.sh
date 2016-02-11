DIR=$(pwd)

cd $(stack path --dist-dir)/build
TARGETDIR=$PWD
cd $DIR

echo $TARGETDIR
