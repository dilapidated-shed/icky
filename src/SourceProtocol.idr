module SourceProtocol

import Data.List
import Diagnostic
import Glyph
import Located
import Name
import Parse
import Protocol
import Source
import Syntax

%default total

public export
data SourceProtocolFailure = InvalidUnicodeScalar | InconsistentSourceSpan | InconsistentLiteralSpelling String

-- Only this module may bind a parser result to an input. The public factory
-- invokes the maintained ICKY parser on the very String stored here.
export
data SourceLocatedResult = BoundSource String (Either (List FatalDiagnostic) LocatedParseResult)

public export
sourceProtocolHeader : String
sourceProtocolHeader = "ICKY-LOCATED\t3\tchar-and-utf8-byte-offset"

private
isUnicodeScalar : Char -> Bool
isUnicodeScalar character =
  let codePoint = ord character
   in codePoint >= 0 && codePoint <= 1114111 &&
      (codePoint < 55296 || codePoint > 57343)

export
covering
parseSourceLocated : String -> Either SourceProtocolFailure SourceLocatedResult
parseSourceLocated source =
  if all isUnicodeScalar (unpack source)
     then Right (BoundSource source (parseLocatedWithWarnings source))
     else Left InvalidUnicodeScalar

export
sourceLocatedText : SourceLocatedResult -> String
sourceLocatedText (BoundSource source result) = source

export
sourceLocatedSyntax : SourceLocatedResult -> Either (List FatalDiagnostic) LocatedParseResult
sourceLocatedSyntax (BoundSource source result) = result

private
utf8Bytes : Char -> List Int
utf8Bytes character =
  let codePoint = ord character
   in if codePoint < 128 then [codePoint]
      else if codePoint < 2048 then
        [192 + codePoint `div` 64, 128 + codePoint `mod` 64]
      else if codePoint < 65536 then
        [224 + codePoint `div` 4096,
         128 + (codePoint `div` 64) `mod` 64,
         128 + codePoint `mod` 64]
      else
        [240 + codePoint `div` 262144,
         128 + (codePoint `div` 4096) `mod` 64,
         128 + (codePoint `div` 64) `mod` 64,
         128 + codePoint `mod` 64]

private
hexadecimalDigit : Int -> Char
hexadecimalDigit value =
  if value < 10 then chr (ord '0' + value)
                else chr (ord 'a' + value - 10)

private
byteHexadecimal : Int -> String
byteHexadecimal value =
  pack [hexadecimalDigit (value `div` 16), hexadecimalDigit (value `mod` 16)]

private
utf8Hexadecimal : List Char -> String
utf8Hexadecimal characters =
  foldr (++) "" (map byteHexadecimal (concat (map utf8Bytes characters)))

private
utf8Length : List Char -> Nat
utf8Length characters = length (concat (map utf8Bytes characters))

private
sourceRow : String -> String
sourceRow source =
  let characters = unpack source
   in "source\t" ++ show (length characters) ++ "\t" ++
      show (utf8Length characters) ++ "\t" ++ utf8Hexadecimal characters

-- The six legacy coordinates precede two half-open UTF-8 byte offsets.
-- A slice is taken only after bounds and all line/column fields agree with
-- the exact input. No AST can be paired with some caller-supplied new text.
private
spanSourceFields : String -> Span -> Maybe (String, String)
spanSourceFields source span =
  let characters = unpack source
      start = spanStart span
      finish = spanEnd span
      startingOffset = offsetNumber (positionOffset start)
      finishingOffset = offsetNumber (positionOffset finish)
      precedingStart = take startingOffset characters
      precedingFinish = take finishingOffset characters
   in if startingOffset <= finishingOffset && finishingOffset <= length characters &&
         advancePositions sourceStart precedingStart == start &&
         advancePositions sourceStart precedingFinish == finish
      then Just
        (show startingOffset ++ "\t" ++ show (lineNumber (positionLine start)) ++ "\t" ++
         show (columnNumber (positionColumn start)) ++ "\t" ++ show finishingOffset ++ "\t" ++
         show (lineNumber (positionLine finish)) ++ "\t" ++
         show (columnNumber (positionColumn finish)) ++ "\t" ++
         show (utf8Length precedingStart) ++ "\t" ++ show (utf8Length precedingFinish),
         utf8Hexadecimal (take (finishingOffset - startingOffset)
                              (drop startingOffset characters)))
      else Nothing

private
childPath : String -> Nat -> String
childPath path ordinal = path ++ "." ++ show ordinal

mutual
  private
  covering
  expressionRows : String -> String -> LocatedExpr -> Maybe (List String)
  expressionRows source path (MkLocatedExpr span leading final) = do
    (fields, spelling) <- spanSourceFields source span
    leadingRows <- pieceRows source path 0 leading
    endingRows <- finalRows source path (length leading) final
    pure (("expr\t" ++ path ++ "\t" ++ fields) :: (leadingRows ++ endingRows))

  private
  covering
  pieceRows : String -> String -> Nat -> List LocatedPiece -> Maybe (List String)
  pieceRows source path ordinal [] = Just []
  pieceRows source path ordinal (piece :: remaining) = do
    firstRows <- onePieceRows source (childPath path ordinal) piece
    remainingRows <- pieceRows source path (S ordinal) remaining
    pure (firstRows ++ remainingRows)

  private
  covering
  onePieceRows : String -> String -> LocatedPiece -> Maybe (List String)
  onePieceRows source path (LocatedNoun span (NameNoun name)) = do
    (fields, spelling) <- spanSourceFields source span
    pure ["name\t" ++ path ++ "\t" ++ fields ++ "\t" ++ nameText name ++ "\t" ++ spelling]
  onePieceRows source path (LocatedNoun span (NaturalNoun value)) = do
    (fields, spelling) <- spanSourceFields source span
    pure ["natural\t" ++ path ++ "\t" ++ fields ++ "\t" ++ show value ++ "\t" ++ spelling]
  onePieceRows source path (LocatedGlyph span glyph) = do
    (fields, spelling) <- spanSourceFields source span
    pure ["glyph\t" ++ path ++ "\t" ++ fields ++ "\t" ++ show glyph ++ "\t" ++ spelling]
  onePieceRows source path (LocatedGroup span expression) = do
    (fields, spelling) <- spanSourceFields source span
    nestedRows <- expressionRows source path expression
    pure (("group\t" ++ path ++ "\t" ++ fields) :: nestedRows)

  private
  covering
  finalRows : String -> String -> Nat -> LocatedFinalPiece -> Maybe (List String)
  finalRows source path ordinal (LocatedFinalNoun span noun) =
    onePieceRows source (childPath path ordinal) (LocatedNoun span noun)
  finalRows source path ordinal (LocatedFinalGroup span expression) =
    onePieceRows source (childPath path ordinal) (LocatedGroup span expression)

private
covering
programRows : String -> Nat -> List LocatedExpr -> Maybe (List String)
programRows source ordinal [] = Just []
programRows source ordinal (expression :: remaining) = do
  firstRows <- expressionRows source (show ordinal) expression
  remainingRows <- programRows source (S ordinal) remaining
  pure (firstRows ++ remainingRows)

private
warningCode : CompatibilitySpelling -> String
warningCode AsciiFatArrow = "ascii-fat-arrow"
warningCode AsciiPipeline = "ascii-pipeline"
warningCode MagrittrPipeline = "magrittr-pipeline"

private
warningRow : String -> WarningDiagnostic -> Maybe String
warningRow source (MkDiagnostic span (CompatibilitySpellingWarning spelling)) = do
  (fields, written) <- spanSourceFields source span
  pure ("warning\t" ++ fields ++ "\t" ++ warningCode spelling ++ "\t" ++ written)

private
fatalCode : DiagnosticKind Fatal -> String
fatalCode (UnexpectedCharacter character) = "unexpected-character\t" ++ show (pack [character])
fatalCode UnexpectedCloseParenthesis = "unexpected-close-parenthesis"
fatalCode MissingCloseParenthesis = "missing-close-parenthesis"
fatalCode ExpressionMustEndInNoun = "expression-must-end-in-noun"

private
fatalRow : String -> FatalDiagnostic -> Maybe String
fatalRow source (MkDiagnostic span kind) = do
  (fields, written) <- spanSourceFields source span
  pure ("fatal\t" ++ fields ++ "\t" ++ fatalCode kind ++ "\t" ++ written)

private
joinRows : List String -> String
joinRows [] = ""
joinRows (row :: remaining) = row ++ "\n" ++ joinRows remaining

private
covering
resultRows : String -> Either (List FatalDiagnostic) LocatedParseResult -> Maybe (List String)
resultRows source (Left diagnostics) = do
  rows <- traverse (fatalRow source) diagnostics
  pure (("error\t" ++ show (length diagnostics)) :: rows)
resultRows source (Right (MkLocatedParseResult (MkLocatedProgram expressions) warnings)) = do
  syntaxRows <- programRows source 0 expressions
  warningRows <- traverse (warningRow source) warnings
  pure (("ok\t" ++ show (length expressions)) :: (syntaxRows ++ warningRows))

export
covering
renderSourceLocated : SourceLocatedResult -> Either SourceProtocolFailure String
renderSourceLocated (BoundSource source result) =
  case renderLocatedResultV2 source result of
    Left problem => Left (InconsistentLiteralSpelling problem)
    Right checkedSpelling =>
      case resultRows source result of
        Nothing => Left InconsistentSourceSpan
        Just rows => Right (joinRows (sourceProtocolHeader :: sourceRow source :: rows))

public export
Show SourceProtocolFailure where
  show InvalidUnicodeScalar = "invalid-unicode-scalar"
  show InconsistentSourceSpan = "inconsistent-source-span"
  show (InconsistentLiteralSpelling problem) = "inconsistent-literal-spelling: " ++ problem
