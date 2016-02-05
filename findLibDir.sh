DIR=$(pwd)

cd $(stack path --local-install-root)/lib
GHCLIBS=$(ls | grep ghc)
cd $GHCLIBS
TARGETDIR=$PWD/$(ls | grep "$1")
cd $DIR

echo $TARGETDIR
