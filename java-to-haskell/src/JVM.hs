{-# LANGUAGE ForeignFunctionInterface #-}
import System.Exit

foreign import ccall "java.h run" run :: IO Int

main :: IO ()
main = run >>= \ret ->
  case ret of
    0 -> exitSuccess
    _ -> exitFailure
