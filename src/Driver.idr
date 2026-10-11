module Driver

import Parse
import Protocol
import System
import System.File

-- The compiler-facing boundary is explicit: a successful invocation
-- actually invokes ICKY's located parser. No fallback to GCC/ASCII parsing.
runFile : String -> IO ()
runFile path = do
  input <- readFile path
  case input of
    Left err => do
      putStrLn protocolHeader
      putStrLn ("io-error\t" ++ show err)
      exitFailure
    Right source => do
      let result = parseLocatedWithWarnings source
      putStr (renderLocatedResult result)
      case result of
        Left diagnostics => exitFailure
        Right parsed => pure ()

main : IO ()
main = do
  args <- getArgs
  case args of
    [program, "--identity"] => putStrLn protocolHeader
    [program, "--parse", sourcePath] => runFile sourcePath
    _ => do
      putStrLn "usage: icky-parser --identity | --parse SOURCE_FILE"
      exitFailure
