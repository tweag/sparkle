import Distribution.Simple
import Language.Java.Inline.Cabal
import qualified Language.Java.Streaming.Jars (getJars)

main = do
    jars <- Language.Java.Streaming.Jars.getJars
    defaultMainWithHooks
      $ addJarsToClasspath jars
      $ gradleHooks simpleUserHooks
