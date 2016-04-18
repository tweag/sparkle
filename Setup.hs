import Distribution.Simple
import System.Process
import System.Exit

main = defaultMainWithHooks simpleUserHooks { postBuild = buildJavaSource }

buildJavaSource _ _ _ _ = do
    executeShellCommand "gradle build"
    return ()

executeShellCommand cmd = system cmd >>= check
  where
    check ExitSuccess = return ()
    check (ExitFailure n) =
        error $ "Command " ++ cmd ++ " exited with failure code " ++ show n
