module Tests

import Decimal
import Diagnostic
import Glyph
import Name
import Parse
import Scan
import Source
import Syntax
import Token
import System

private
fail : String -> IO ()
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
isAbsent : Maybe a -> Bool
isAbsent Nothing = True
isAbsent (Just value) = False

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
    "← → ⇐ ⇒ = ⌖ ↥ ↧ · ∘ image"
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
