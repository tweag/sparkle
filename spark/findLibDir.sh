DIR=$(pwd)

cd $(stack path --local-install-root)/lib
cd $(ls | grep ghc)
cd $(ls | grep spark)

TARGETDIR=$PWD
cd $DIR

echo $TARGETDIR
