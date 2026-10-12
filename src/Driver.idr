module Driver

import Diagnostic
import Parse
import Protocol
import System
import System.File

-- The compiler-facing boundary is explicit: a successful invocation
-- actually invokes ICKY's located parser. No fallback to GCC/ASCII parsing.
runFile : Bool -> String -> IO ()
runFile includeSpelling path = do
  input <- readFile path
  case input of
    Left err => do
      putStrLn (if includeSpelling then protocolHeaderV2 else protocolHeader)
      putStrLn ("io-error\t" ++ show err)
      exitFailure
    Right source => do
      let result = parseLocatedWithWarnings source
      if includeSpelling
        then case renderLocatedResultV2 source result of
               Left problem => do
                 putStrLn protocolHeaderV2
                 putStrLn ("internal-source-mismatch\t" ++ problem)
                 exitFailure
               Right records => putStr records
        else putStr (renderLocatedResult result)
      case result of
        Left diagnostics => exitFailure
        Right parsed => pure ()

main : IO ()
main = do
  args <- getArgs
  case args of
    [program, "--identity"] => putStrLn protocolHeader
    [program, "--identity-v2"] => putStrLn protocolHeaderV2
    [program, "--parse", sourcePath] => runFile False sourcePath
    [program, "--parse-v2", sourcePath] => runFile True sourcePath
    _ => do
      putStrLn "usage: icky-parser --identity | --identity-v2 | --parse SOURCE_FILE | --parse-v2 SOURCE_FILE"
      exitFailure
