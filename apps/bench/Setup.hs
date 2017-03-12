import Distribution.Simple
import Language.Java.Inline.Cabal

main = defaultMainWithHooks (gradleHooks simpleUserHooks)
