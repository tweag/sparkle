{-# LANGUAGE ForeignFunctionInterface #-}
import System.Exit
import A

foreign import ccall "java.h run" run :: IO Int

main :: IO ()
main = run >>= \ret ->
  case ret of
    0 -> exitSuccess
    _ -> exitFailure
