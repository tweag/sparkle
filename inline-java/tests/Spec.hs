import Test.Hspec
import Language.Java (withJVM)
import qualified Language.JavaSpec as JS

main :: IO ()
main = withJVM [] $ hspec JS.spec
