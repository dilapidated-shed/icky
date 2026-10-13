module Tests

import Data.List
import Decimal
import Diagnostic
import Glyph
import Located
import Name
import Parse
import Protocol
import Scan
import Source
import SourceProtocol
import Syntax
import Token
import System
import System.File

private
fail : String -> IO a
fail message = do
  putStrLn ("FAIL: " ++ message)
  exitFailure

private
pass : String -> IO ()
pass name = putStrLn ("ok: " ++ name)

private
assert : String -> Bool -> IO ()
assert name True = pass name
assert name False = fail name

private
collectPieces : List (Maybe Piece) -> Maybe (List Piece)
collectPieces [] = Just []
collectPieces (piece :: rest) =
  case (piece, collectPieces rest) of
    (Just actual, Just actualRest) => Just (actual :: actualRest)
    _ => Nothing

private
expression : List (Maybe Piece) -> Maybe Expr
expression candidatePieces =
  case collectPieces candidatePieces of
    Just pieces => exprFromPieces pieces
    Nothing => Nothing

private
collectExpressions : List (List (Maybe Piece)) -> Maybe (List Expr)
collectExpressions [] = Just []
collectExpressions (pieces :: rest) =
  case (expression pieces, collectExpressions rest) of
    (Just actual, Just actualRest) => Just (actual :: actualRest)
    _ => Nothing

private
program : List (List (Maybe Piece)) -> Maybe Program
program expressions = map MkProgram (collectExpressions expressions)

private
one : List (Maybe Piece) -> Maybe Program
one pieces = program [pieces]

private
namePiece : String -> Maybe Piece
namePiece text = map (NounPiece . NameNoun) (nameFromString text)

private
naturalPiece : Nat -> Maybe Piece
naturalPiece value = Just (NounPiece (NaturalNoun value))

private
glyphPiece : Glyph -> Maybe Piece
glyphPiece glyph = Just (GlyphPiece glyph)

private
groupPiece : List (Maybe Piece) -> Maybe Piece
groupPiece pieces = map GroupPiece (expression pieces)

private
assertParses : String -> String -> Maybe Program -> IO ()
assertParses name source Nothing = fail (name ++ " — invalid expected fixture")
assertParses name source (Just expected) =
  case parse source of
    Right actual => assert name (actual == expected)
    Left diagnostics => fail (name ++ " — parse failed: " ++ show diagnostics)

private
findWarning : CompatibilitySpelling -> List WarningDiagnostic -> Maybe WarningDiagnostic
findWarning expected [] = Nothing
findWarning expected (diagnostic@(MkDiagnostic span (CompatibilitySpellingWarning actual)) :: rest) =
  if actual == expected then Just diagnostic else findWarning expected rest

private
assertParsesWithWarning : String -> String -> CompatibilitySpelling ->
                          Maybe Program -> IO ()
assertParsesWithWarning name source spelling Nothing =
  fail (name ++ " — invalid expected fixture")
assertParsesWithWarning name source spelling (Just expected) =
  case parseWithWarnings source of
    Left diagnostics => fail (name ++ " — parse failed: " ++ show diagnostics)
    Right (MkParseResult actual warnings) =>
      case (findWarning spelling warnings, parse source) of
        (Just warning, Right compatibilityProgram) =>
          assert name (actual == expected && compatibilityProgram == expected &&
                       diagnosticSeverity warning == Warning)
        (Nothing, _) => fail (name ++ " — expected structured compatibility warning")
        (_, Left diagnostics) =>
          fail (name ++ " — compatibility parse failed: " ++ show diagnostics)

private
assertFails : String -> String -> IO ()
assertFails name source =
  case parse source of
    Left _ => pass name
    Right actual => fail (name ++ " — unexpectedly parsed: " ++ show actual)

private
findFatal : DiagnosticKind Fatal -> List FatalDiagnostic -> Maybe FatalDiagnostic
findFatal expected [] = Nothing
findFatal expected (diagnostic@(MkDiagnostic span actual) :: rest) =
  if actual == expected then Just diagnostic else findFatal expected rest

private
assertFatalRenders : String -> String -> DiagnosticKind Fatal -> String -> IO ()
assertFatalRenders name source kind expected =
  case parse source of
    Right actual => fail (name ++ " — unexpectedly parsed: " ++ show actual)
    Left diagnostics =>
      case findFatal kind diagnostics of
        Just diagnostic =>
          assert name (diagnosticSeverity diagnostic == Fatal &&
                       renderDiagnostic diagnostic == expected)
        Nothing => fail (name ++ " — missing diagnostic kind in " ++ show diagnostics)

private
assertOnlyFatalRenders : String -> String -> DiagnosticKind Fatal -> String -> IO ()
assertOnlyFatalRenders name source expectedKind expectedRendering =
  case parse source of
    Left [diagnostic@(MkDiagnostic span actualKind)] =>
      assert name (actualKind == expectedKind &&
                   renderDiagnostic diagnostic == expectedRendering)
    Left diagnostics => fail (name ++ " — unexpected diagnostics: " ++ show diagnostics)
    Right actual => fail (name ++ " — unexpectedly parsed: " ++ show actual)

private
assertWarningRenders : String -> String -> CompatibilitySpelling -> String -> IO ()
assertWarningRenders name source spelling expected =
  case parseWithWarnings source of
    Left diagnostics => fail (name ++ " — parse failed: " ++ show diagnostics)
    Right (MkParseResult actual warnings) =>
      case findWarning spelling warnings of
        Just diagnostic => assert name (renderDiagnostic diagnostic == expected)
        Nothing => fail (name ++ " — missing warning in " ++ show warnings)

private
positionIs : Position -> Nat -> Nat -> Nat -> Bool
positionIs position expectedOffset expectedLine expectedColumn =
  offsetNumber (positionOffset position) == expectedOffset &&
  lineNumber (positionLine position) == expectedLine &&
  columnNumber (positionColumn position) == expectedColumn

private
spanIs : Span -> Nat -> Nat -> Nat -> Nat -> Nat -> Nat -> Bool
spanIs span startOffset startLine startColumn endOffset endLine endColumn =
  positionIs (spanStart span) startOffset startLine startColumn &&
  positionIs (spanEnd span) endOffset endLine endColumn

private
assertSourcePosition : IO ()
assertSourcePosition =
  case scan "a\n@" of
    Left [MkDiagnostic span (UnexpectedCharacter '@')] =>
      assert "source positions retain zero/one-based conventions"
        (spanIs span 2 2 1 3 2 2)
    Left diagnostics => fail ("source position — unexpected diagnostics: " ++ show diagnostics)
    Right tokens => fail ("source position — unexpectedly scanned: " ++ show tokens)

private
assertUnicodePosition : IO ()
assertUnicodePosition =
  case scan "← @" of
    Left [MkDiagnostic span (UnexpectedCharacter '@')] =>
      assert "source offsets continue to count Unicode characters"
        (spanIs span 2 1 3 3 1 4)
    Left diagnostics => fail ("Unicode position — unexpected diagnostics: " ++ show diagnostics)
    Right tokens => fail ("Unicode position — unexpectedly scanned: " ++ show tokens)

private
assertLocatedSyntax : IO ()
assertLocatedSyntax = do
  let source = "← image\n⌖ (↥ image)\nimage |> resize"
  case parseLocatedWithWarnings source of
    Left diagnostics => fail ("located parse failed: " ++ show diagnostics)
    Right (MkLocatedParseResult located warnings) =>
      case located of
        MkLocatedProgram [ first, grouped, compatibility ] => do
          case first of
            MkLocatedExpr whole
              [LocatedGlyph arrowSpan LeftArrow]
              (LocatedFinalNoun nounSpan (NameNoun name)) =>
                assert "glyph/noun and expression spans retain literal positions"
                  (spanIs arrowSpan 0 1 1 1 1 2 &&
                   spanIs nounSpan 2 1 3 7 1 8 &&
                   spanIs whole 0 1 1 7 1 8 &&
                   nameText name == "image")
            _ => fail "located first expression lost typed pieces"

          case grouped of
            MkLocatedExpr whole
              [LocatedGlyph symbolSpan Target]
              (LocatedFinalGroup groupSpan inner) =>
                case inner of
                  MkLocatedExpr innerSpan
                    [LocatedGlyph upSpan UpArrow]
                    (LocatedFinalNoun nameSpan (NameNoun name)) =>
                      assert "group retains full parentheses separately from inner AST"
                        (spanIs symbolSpan 8 2 1 9 2 2 &&
                         spanIs groupSpan 10 2 3 19 2 12 &&
                         spanIs innerSpan 11 2 4 18 2 11 &&
                         spanIs upSpan 11 2 4 12 2 5 &&
                         spanIs nameSpan 13 2 6 18 2 11 &&
                         spanIs whole 8 2 1 19 2 12 &&
                         nameText name == "image")
                  _ => fail "nested group lost located child pieces"
            _ => fail "located second expression lost a grouped final piece"

          case compatibility of
            MkLocatedExpr whole
              [LocatedNoun firstSpan (NameNoun firstName),
               LocatedGlyph aliasSpan MiddleDot]
              (LocatedFinalNoun lastSpan (NameNoun lastName)) =>
                assert "compatibility token retains its actual written span"
                  (spanIs firstSpan 20 3 1 25 3 6 &&
                   spanIs aliasSpan 26 3 7 28 3 9 &&
                   spanIs lastSpan 29 3 10 35 3 16 &&
                   spanIs whole 20 3 1 35 3 16 &&
                   nameText firstName == "image" &&
                   nameText lastName == "resize")
            _ => fail "located third expression lost compatibility token"

          case warnings of
            [MkDiagnostic span (CompatibilitySpellingWarning AsciiPipeline)] =>
              assert "located warnings keep scanner spans"
                (spanIs span 26 3 7 28 3 9)
            _ => fail "located parse changed the structured warning"

          case (parse source, parseWithWarnings source) of
            (Right prior, Right (MkParseResult priorWithWarnings priorWarnings)) =>
              assert "located erasure exactly matches legacy parse and warnings"
                (eraseLocatedProgram located == prior &&
                 prior == priorWithWarnings &&
                 warnings == priorWarnings)
            _ => fail "located change rejected legacy-valid source"
        _ => fail "located parser changed expression count or source order"

private
assertProtocol : IO ()
assertProtocol = do
  let first = protocolHeader ++ "\n" ++
              "ok\t1\n" ++
              "expr\t0\t0\t1\t1\t7\t1\t8\n" ++
              "glyph\t0.0\t0\t1\t1\t1\t1\t2\t←\n" ++
              "name\t0.1\t2\t1\t3\t7\t1\t8\timage\n"
  assert "versioned protocol preserves literal glyph and character spans"
    (renderLocatedResult (parseLocatedWithWarnings "← image") == first)

  let nested = protocolHeader ++ "\n" ++
               "ok\t1\n" ++
               "expr\t0\t0\t1\t1\t11\t1\t12\n" ++
               "glyph\t0.0\t0\t1\t1\t1\t1\t2\t⌖\n" ++
               "group\t0.1\t2\t1\t3\t11\t1\t12\n" ++
               "expr\t0.1\t3\t1\t4\t10\t1\t11\n" ++
               "glyph\t0.1.0\t3\t1\t4\t4\t1\t5\t↥\n" ++
               "name\t0.1.1\t5\t1\t6\t10\t1\t11\timage\n"
  assert "versioned protocol nests group spans and children in source order"
    (renderLocatedResult (parseLocatedWithWarnings "⌖ (↥ image)") == nested)

  let aliased = protocolHeader ++ "\n" ++
                "ok\t1\n" ++
                "expr\t0\t0\t1\t1\t15\t1\t16\n" ++
                "name\t0.0\t0\t1\t1\t5\t1\t6\timage\n" ++
                "glyph\t0.1\t6\t1\t7\t8\t1\t9\t·\n" ++
                "name\t0.2\t9\t1\t10\t15\t1\t16\tresize\n" ++
                "warning\t6\t1\t7\t8\t1\t9\tascii-pipeline\n"
  assert "compatibility glyph is semantic token; warning retains written alias"
    (renderLocatedResult (parseLocatedWithWarnings "image |> resize") == aliased)

  let failed = protocolHeader ++ "\n" ++
               "error\t1\n" ++
               "fatal\t0\t1\t1\t1\t1\t2\tunexpected-character\t\"@\"\n"
  assert "invalid source produces only deterministic fatal protocol records"
    (renderLocatedResult (parseLocatedWithWarnings "@") == failed)

private
assertSourceSpelling : IO ()
assertSourceSpelling = do
  let source = "← 010"
  let expected = protocolHeaderV2 ++ "\n" ++
                 "ok\t1\n" ++
                 "expr\t0\t0\t1\t1\t5\t1\t6\n" ++
                 "glyph\t0.0\t0\t1\t1\t1\t1\t2\t←\n" ++
                 "natural\t0.1\t2\t1\t3\t5\t1\t6\t10\n" ++
                 "spelling\t0.1\t2\t1\t3\t5\t1\t6\t010\n"
  assert "v2 preserves literal 010 despite natural value 10 after Unicode glyph"
    (renderLocatedResultV2 source (parseLocatedWithWarnings source) ==
     Right expected)

  case renderLocatedResultV2 "← 10" (parseLocatedWithWarnings source) of
    Left problem => assert "v2 rejects a source/AST spelling or span mismatch"
                      (problem == "SOURCE_SPELLING_MISMATCH\t0.1")
    Right records => fail "v2 accepted source bytes inconsistent with parsed source"

private
assertLocatedRefusal : String -> String -> IO ()
assertLocatedRefusal name source =
  case (parseLocated source, parse source) of
    (Left locatedDiagnostics, Left legacyDiagnostics) =>
      assert name (locatedDiagnostics == legacyDiagnostics)
    _ => fail (name ++ " — located and legacy rejection disagree")

private
assertSourceRecords : String -> String -> String -> IO ()
assertSourceRecords name source expected =
  case parseSourceLocated source of
    Left failure => fail (name ++ " — source binding failed: " ++ show failure)
    Right boundInput =>
      case renderSourceLocated boundInput of
        Left failure => fail (name ++ " — source serialization failed: " ++ show failure)
        Right actual =>
          if actual == sourceProtocolHeader ++ "\n" ++ expected
             then pass name
             else fail (name ++ "\nEXPECTED RECORDS:\n" ++ sourceProtocolHeader ++
                        "\n" ++ expected ++ "ACTUAL RECORDS:\n" ++ actual)

private
assertSourceProtocol : IO ()
assertSourceProtocol = do
  case parseSourceLocated "x ← 010" of
    Left failure => fail "source binding refused supported input"
    Right boundInput => do
      assert "source binding retains the exact parser input"
        (sourceLocatedText boundInput == "x ← 010")
      assert "source binding preserves the existing located parser result"
        (renderLocatedResult (sourceLocatedSyntax boundInput) ==
         renderLocatedResult (parseLocatedWithWarnings "x ← 010"))

  assertSourceRecords "source protocol preserves leading zeroes with decimal value"
    "010"
    ("source\t3\t3\t303130\n" ++
     "ok\t1\nexpr\t0\t0\t1\t1\t3\t1\t4\t0\t3\n" ++
     "natural\t0.0\t0\t1\t1\t3\t1\t4\t0\t3\t10\t303130\n")
  assertSourceRecords "source protocol distinguishes equal-valued written numerals"
    "10"
    ("source\t2\t2\t3130\n" ++
     "ok\t1\nexpr\t0\t0\t1\t1\t2\t1\t3\t0\t2\n" ++
     "natural\t0.0\t0\t1\t1\t2\t1\t3\t0\t2\t10\t3130\n")
  assertSourceRecords "source protocol separates glyph character and UTF-8 byte spans"
    "x ← 010"
    ("source\t7\t9\t7820e2869020303130\n" ++
     "ok\t1\nexpr\t0\t0\t1\t1\t7\t1\t8\t0\t9\n" ++
     "name\t0.0\t0\t1\t1\t1\t1\t2\t0\t1\tx\t78\n" ++
     "glyph\t0.1\t2\t1\t3\t3\t1\t4\t2\t5\t←\te28690\n" ++
     "natural\t0.2\t4\t1\t5\t7\t1\t8\t6\t9\t10\t303130\n")
  assertSourceRecords "source protocol retains written aliases and warning bytes"
    "x |> 010"
    ("source\t8\t8\t78207c3e20303130\n" ++
     "ok\t1\nexpr\t0\t0\t1\t1\t8\t1\t9\t0\t8\n" ++
     "name\t0.0\t0\t1\t1\t1\t1\t2\t0\t1\tx\t78\n" ++
     "glyph\t0.1\t2\t1\t3\t4\t1\t5\t2\t4\t·\t7c3e\n" ++
     "natural\t0.2\t5\t1\t6\t8\t1\t9\t5\t8\t10\t303130\n" ++
     "warning\t2\t1\t3\t4\t1\t5\t2\t4\tascii-pipeline\t7c3e\n")
  assertSourceRecords "source protocol retains two-byte multiplication glyph intervals"
    "x × 10"
    ("source\t6\t7\t7820c397203130\n" ++
     "ok\t1\nexpr\t0\t0\t1\t1\t6\t1\t7\t0\t7\n" ++
     "name\t0.0\t0\t1\t1\t1\t1\t2\t0\t1\tx\t78\n" ++
     "glyph\t0.1\t2\t1\t3\t3\t1\t4\t2\t4\t×\tc397\n" ++
     "natural\t0.2\t4\t1\t5\t6\t1\t7\t5\t7\t10\t3130\n")
  assertSourceRecords "source protocol binds comments and four-byte Unicode to later spans"
    "⍝😀\nx"
    ("source\t4\t9\te28d9df09f98800a78\n" ++
     "ok\t1\nexpr\t0\t3\t2\t1\t4\t2\t2\t8\t9\n" ++
     "name\t0.0\t3\t2\t1\t4\t2\t2\t8\t9\tx\t78\n")
  assertSourceRecords "source protocol preserves tabs and CRLF without normalization"
    "x\t\r\n010"
    ("source\t7\t7\t78090d0a303130\n" ++
     "ok\t2\nexpr\t0\t0\t1\t1\t1\t1\t2\t0\t1\n" ++
     "name\t0.0\t0\t1\t1\t1\t1\t2\t0\t1\tx\t78\n" ++
     "expr\t1\t4\t2\t1\t7\t2\t4\t4\t7\n" ++
     "natural\t1.0\t4\t2\t1\t7\t2\t4\t4\t7\t10\t303130\n")
  assertSourceRecords "source protocol checks nested group intervals against the input"
    "((010))"
    ("source\t7\t7\t28283031302929\n" ++
     "ok\t1\nexpr\t0\t0\t1\t1\t7\t1\t8\t0\t7\n" ++
     "group\t0.0\t0\t1\t1\t7\t1\t8\t0\t7\n" ++
     "expr\t0.0\t1\t1\t2\t6\t1\t7\t1\t6\n" ++
     "group\t0.0.0\t1\t1\t2\t6\t1\t7\t1\t6\n" ++
     "expr\t0.0.0\t2\t1\t3\t5\t1\t6\t2\t5\n" ++
     "natural\t0.0.0.0\t2\t1\t3\t5\t1\t6\t2\t5\t10\t303130\n")
  assertSourceRecords "source protocol refusal contains input identity and no successful AST"
    "@"
    ("source\t1\t1\t40\nerror\t1\n" ++
     "fatal\t0\t1\t1\t1\t1\t2\t0\t1\tunexpected-character\t\"@\"\t40\n")
  assertSourceRecords "source protocol preserves the empty input identity"
    "" "source\t0\t0\t\nok\t0\n"
  assertSourceRecords "source protocol refuses an unsupported neighboring arrow"
    "↚ x"
    ("source\t3\t5\te2869a2078\nerror\t1\n" ++
     "fatal\t0\t1\t1\t1\t1\t2\t0\t3\tunexpected-character\t\"\\8602\"\te2869a\n")

private
isAbsent : Maybe a -> Bool
isAbsent Nothing = True
isAbsent (Just value) = False

private
runParserArguments : List String -> IO (Int, String)
runParserArguments arguments = do
  opened <- System.File.Process.Escaped.popen
              ("./build/exec/icky-parser" :: arguments) Read
  case opened of
    Left problem => fail ("actual parser executable could not start: " ++ show problem)
    Right pipe => do
      output <- fRead pipe
      exitCode <- pclose pipe
      case output of
        Left problem => fail ("actual parser output could not be read: " ++ show problem)
        Right records => pure (exitCode, records)

private
writeParserFixture : String -> String -> IO ()
writeParserFixture path source = do
  written <- writeFile path source
  case written of
    Left problem => fail ("parser fixture could not be written: " ++ show problem)
    Right () => pure ()

private
assertSourceExecutable : IO ()
assertSourceExecutable = do
  (identityExit, identityRecords) <- runParserArguments ["--identity-v3"]
  assert "actual v3 executable reports its source-preserving protocol identity"
    (identityExit == 0 && identityRecords == sourceProtocolHeader ++ "\n")

  writeParserFixture "build/source-fidelity-positive.txt" "x ← 010"
  (positiveExit, positiveRecords) <- runParserArguments
    ["--parse-v3", "build/source-fidelity-positive.txt"]
  let expected = sourceProtocolHeader ++ "\n" ++
                 "source\t7\t9\t7820e2869020303130\n" ++
                 "ok\t1\nexpr\t0\t0\t1\t1\t7\t1\t8\t0\t9\n" ++
                 "name\t0.0\t0\t1\t1\t1\t1\t2\t0\t1\tx\t78\n" ++
                 "glyph\t0.1\t2\t1\t3\t3\t1\t4\t2\t5\t←\te28690\n" ++
                 "natural\t0.2\t4\t1\t5\t7\t1\t8\t6\t9\t10\t303130\n"
  assert "actual v3 executable retains exact input bytes numeral spelling and byte spans"
    (positiveExit == 0 && positiveRecords == expected)

  writeParserFixture "build/source-fidelity-negative.txt" "@"
  (negativeExit, negativeRecords) <- runParserArguments
    ["--parse-v3", "build/source-fidelity-negative.txt"]
  assert "actual v3 executable refuses malformed syntax with nonzero exit"
    (negativeExit /= 0 && negativeRecords ==
     sourceProtocolHeader ++ "\nsource\t1\t1\t40\nerror\t1\n" ++
     "fatal\t0\t1\t1\t1\t1\t2\t0\t1\tunexpected-character\t\"@\"\t40\n")

  (missingExit, missingRecords) <- runParserArguments
    ["--parse-v3", "build/source-fidelity-absent-input.txt"]
  let expectedPrefix = unpack (sourceProtocolHeader ++ "\nio-error\t")
  assert "actual v3 executable refuses missing input with nonzero exit"
    (missingExit /= 0 && take (length expectedPrefix) (unpack missingRecords) == expectedPrefix)

main : IO ()
main = do
  case nameFromString "image_2" of
    Just name => assert "validated name retains source text" (nameText name == "image_2")
    Nothing => fail "validated name — accepted spelling was refused"
  assert "invalid name start is refused" (isAbsent (nameFromString "@image"))
  assert "digit cannot start a name" (isAbsent (nameFromString "2image"))

  assert "invalid decimal character has no digit value"
    (decimalDigit 'x' == Nothing)
  assert "decimal digit recognition is explicit"
    (decimalDigit '7' == Just SevenDigit && digitValue SevenDigit == 7)
  assert "decimal numeral cannot be empty"
    (isAbsent (takeDecimalPrefix []))
  case takeDecimalPrefix (unpack "407x") of
    Just (numeral, ['x']) =>
      assert "nonempty decimal numeral converts from digits only"
        (decimalValue numeral == 407 && decimalText numeral == "407")
    _ => fail "decimal numeral — prefix recognition changed"

  assert "empty list cannot construct a successful expression"
    (isAbsent (exprFromPieces []))
  assert "glyph-only list cannot construct a successful expression"
    (isAbsent (exprFromPieces [GlyphPiece Target]))
  case nameFromString "image" of
    Just image =>
      assert "trailing glyph cannot construct a successful expression"
        (isAbsent (exprFromPieces [NounPiece (NameNoun image), GlyphPiece Target]))
    Nothing => fail "expression boundary — accepted fixture name was refused"

  assertParses "empty source remains an empty program" "" (program [])

  assertParses "name is a noun"
    "image"
    (one [namePiece "image"])

  assertParses "leading underscore remains accepted in a name"
    "_image2"
    (one [namePiece "_image2"])

  assertParses "natural is a noun"
    "42"
    (one [naturalPiece 42])

  assertParses "act-first prefix-shaped order is preserved"
    "⌖ image"
    (one [glyphPiece Target, namePiece "image"])

  assertParses "value-first pipeline-shaped order is preserved"
    "image · resize"
    (one [namePiece "image", glyphPiece MiddleDot, namePiece "resize"])

  assertParses "composition ring is preserved"
    "f ∘ g"
    (one [namePiece "f", glyphPiece Composition, namePiece "g"])

  assertParses "arrow directions are paired"
    "← → ⇐ ⇒ ↥ ↧ image"
    (one [ glyphPiece LeftArrow
         , glyphPiece RightArrow
         , glyphPiece DoubleLeftArrow
         , glyphPiece DoubleRightArrow
         , glyphPiece UpArrow
         , glyphPiece DownArrow
         , namePiece "image"
         ])

  assert "reverse glyph remains an explicit surface pairing"
    (reverseGlyph LeftArrow == Just RightArrow &&
     reverseGlyph RightArrow == Just LeftArrow &&
     reverseGlyph Composition == Nothing)

  assertParsesWithWarning "ASCII fat arrow remains accepted"
    "result => next" AsciiFatArrow
    (one [namePiece "result", glyphPiece DoubleRightArrow, namePiece "next"])

  assertParsesWithWarning "ASCII pipeline remains accepted"
    "image |> resize" AsciiPipeline
    (one [namePiece "image", glyphPiece MiddleDot, namePiece "resize"])

  assertParsesWithWarning "Magrittr pipeline remains accepted"
    "image %>% resize" MagrittrPipeline
    (one [namePiece "image", glyphPiece MiddleDot, namePiece "resize"])

  assertParses "source order is preserved"
    "← ↥ image"
    (one [glyphPiece LeftArrow, glyphPiece UpArrow, namePiece "image"])

  assertParses "all source glyphs are preserved"
    "← → ⇐ ⇒ = ⌖ ↥ ↧ · ∘ ÷ × √ ² ³ ≠ ≟ λ ∞ − – image"
    (one [ glyphPiece LeftArrow
         , glyphPiece RightArrow
         , glyphPiece DoubleLeftArrow
         , glyphPiece DoubleRightArrow
         , glyphPiece Equals
         , glyphPiece Target
         , glyphPiece UpArrow
         , glyphPiece DownArrow
         , glyphPiece MiddleDot
         , glyphPiece Composition
         , glyphPiece Division
         , glyphPiece Multiplication
         , glyphPiece SquareRoot
         , glyphPiece SuperscriptTwo
         , glyphPiece SuperscriptThree
         , glyphPiece NotEqual
         , glyphPiece DecidableEqual
         , glyphPiece Lambda
         , glyphPiece Infinity
         , glyphPiece Minus
         , glyphPiece EnDash
         , namePiece "image"
         ])

  assertParses "comment runs to newline"
    "⌖ image ⍝ ignored\nother"
    (program [ [glyphPiece Target, namePiece "image"]
             , [namePiece "other"]
             ])

  assertParses "group is syntax, not semantics"
    "⌖ (↥ image)"
    (one [ glyphPiece Target
         , groupPiece [glyphPiece UpArrow, namePiece "image"]
         ])

  assertFails "glyph-only expression violates noun-last" "⌖"
  assertFails "trailing glyph violates noun-last" "image ⌖"
  assertFails "group must end in noun" "(image ⌖)"
  assertFails "unexpected character is lexical error" "@ image"
  assertFails "unmatched close parenthesis" "image)"
  assertFails "missing close parenthesis" "(⌖ image"
  assertFails "name recognition is not broadened to Unicode" "é"
  assertFails "C thin arrow is not a compatibility alias" "image -> resize"
  assertFails "C less-than-or-equal is not a compatibility alias" "image <= resize"
  assertFails "C greater-than-or-equal is not a compatibility alias" "image >= resize"
  assertFails "C left shift is not a compatibility alias" "image << resize"
  assertFails "C right shift is not a compatibility alias" "image >> resize"

  assertFatalRenders "unexpected character diagnostic is structured"
    "@ image" (UnexpectedCharacter '@')
    "1:1-1:2: unexpected character \"@\""
  assertFatalRenders "missing parenthesis diagnostic is structured"
    "(⌖ image" MissingCloseParenthesis
    "1:1-1:2: missing ')'"
  assertFatalRenders "noun-last diagnostic is structured"
    "image ⌖" ExpressionMustEndInNoun
    "1:8-1:8: expression must end in a noun"
  assertFatalRenders "unexpected close diagnostic is structured"
    "image)" UnexpectedCloseParenthesis
    "1:6-1:7: unexpected ')'"
  assertOnlyFatalRenders "invalid prefix group does not poison noun-ending context"
    "((⌖) image)" ExpressionMustEndInNoun
    "1:4-1:5: expression must end in a noun"
  assertWarningRenders "compatibility warning renders separately"
    "image |> resize" AsciiPipeline
    "1:7-1:9: ASCII '|>' accepted; prefer '·'"

  assertSourcePosition
  assertUnicodePosition
  assertLocatedSyntax
  assertProtocol
  assertSourceSpelling
  assertSourceProtocol
  assertSourceExecutable
  assertLocatedRefusal "located invalid glyph suffix matches legacy" "image ⌖"
  assertLocatedRefusal "located invalid C thin-arrow matches legacy" "image -> resize"
  assertLocatedRefusal "located malformed group matches legacy" "(⌖ image"
