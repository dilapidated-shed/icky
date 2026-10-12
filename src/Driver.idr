module Driver

import Diagnostic
import Parse
import Protocol
import SourceProtocol
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

-- v3 owns the parser/source pairing and emits exact UTF-8 identity bytes.
-- Its separate entrypoint leaves every existing v1/v2 caller unchanged.
runSourceFile : String -> IO ()
runSourceFile path = do
  input <- readFile path
  case input of
    Left err => do
      putStrLn sourceProtocolHeader
      putStrLn ("io-error\t" ++ show err)
      exitFailure
    Right source =>
      case parseSourceLocated source of
        Left failure => do
          putStrLn sourceProtocolHeader
          putStrLn ("protocol-error\t" ++ show failure)
          exitFailure
        Right boundInput =>
          case renderSourceLocated boundInput of
            Left failure => do
              putStrLn sourceProtocolHeader
              putStrLn ("protocol-error\t" ++ show failure)
              exitFailure
            Right records => do
              putStr records
              case sourceLocatedSyntax boundInput of
                Left diagnostics => exitFailure
                Right parsed => pure ()

main : IO ()
main = do
  args <- getArgs
  case args of
    [program, "--identity"] => putStrLn protocolHeader
    [program, "--identity-v3"] => putStrLn sourceProtocolHeader
    [program, "--parse-v3", sourcePath] => runSourceFile sourcePath
    [program, "--identity-v2"] => putStrLn protocolHeaderV2
    [program, "--parse", sourcePath] => runFile False sourcePath
    [program, "--parse-v2", sourcePath] => runFile True sourcePath
    _ => do
      putStrLn "usage: icky-parser --identity | --identity-v2 | --identity-v3 | --parse SOURCE_FILE | --parse-v2 SOURCE_FILE | --parse-v3 SOURCE_FILE"
      exitFailure
