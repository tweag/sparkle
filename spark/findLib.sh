DIR=$(pwd)

cd $(stack path --local-install-root)/lib
cd $(ls | grep ghc)
cd $(ls | grep spark)

TARGET=$PWD/$(ls | grep "spark" | grep ghc)
cd $DIR

echo $TARGET
