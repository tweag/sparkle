DIR=$(pwd)

cd $(stack path --local-install-root)/lib
cd $(ls | grep ghc)
cd $(ls | grep hs-invoke)

TARGET=$PWD/$(ls | grep "hs-invoke" | grep ghc)
cd $DIR

echo "Please issue the following command:"
echo "  cp $TARGET libHelloInvoke.${TARGET##*.}"
