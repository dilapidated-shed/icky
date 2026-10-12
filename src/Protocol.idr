module Protocol

import Decimal
import Diagnostic
import Glyph
import Located
import Name
import Parse
import Source
import Syntax

%default total

-- v1 is a canonical line-oriented, tab-separated protocol, not JSON or an
-- ad hoc dump of Show instances. Names have the scanner's ASCII-only syntax
-- and glyphs are single enumerated characters, so neither contains a tab.
public export
protocolHeader : String
protocolHeader = "ICKY-LOCATED\t1\tchar-offset"

private
spanFields : Span -> String
spanFields span =
  let start = spanStart span
      finish = spanEnd span
   in show (offsetNumber (positionOffset start)) ++ "\t" ++
      show (lineNumber (positionLine start)) ++ "\t" ++
      show (columnNumber (positionColumn start)) ++ "\t" ++
      show (offsetNumber (positionOffset finish)) ++ "\t" ++
      show (lineNumber (positionLine finish)) ++ "\t" ++
      show (columnNumber (positionColumn finish))

private
childPath : String -> Nat -> String
childPath path ordinal = path ++ "." ++ show ordinal

mutual
  private
  covering
  expressionRows : String -> LocatedExpr -> List String
  expressionRows path (MkLocatedExpr span leading final) =
    ("expr\t" ++ path ++ "\t" ++ spanFields span) ::
      (pieceRows path 0 leading ++ finalRows path (length leading) final)

  private
  covering
  pieceRows : String -> Nat -> List LocatedPiece -> List String
  pieceRows path index [] = []
  pieceRows path index (piece :: remaining) =
    onePieceRows (childPath path index) piece ++
    pieceRows path (S index) remaining

  private
  covering
  onePieceRows : String -> LocatedPiece -> List String
  onePieceRows path (LocatedNoun span (NameNoun name)) =
    ["name\t" ++ path ++ "\t" ++ spanFields span ++ "\t" ++ nameText name]
  onePieceRows path (LocatedNoun span (NaturalNoun value)) =
    ["natural\t" ++ path ++ "\t" ++ spanFields span ++ "\t" ++ show value]
  onePieceRows path (LocatedGlyph span glyph) =
    ["glyph\t" ++ path ++ "\t" ++ spanFields span ++ "\t" ++ show glyph]
  onePieceRows path (LocatedGroup span expression) =
    ("group\t" ++ path ++ "\t" ++ spanFields span) ::
      expressionRows path expression

  private
  covering
  finalRows : String -> Nat -> LocatedFinalPiece -> List String
  finalRows path index (LocatedFinalNoun span noun) =
    onePieceRows (childPath path index) (LocatedNoun span noun)
  finalRows path index (LocatedFinalGroup span expression) =
    onePieceRows (childPath path index) (LocatedGroup span expression)

private
covering
programRows : Nat -> List LocatedExpr -> List String
programRows index [] = []
programRows index (expression :: remaining) =
  expressionRows (show index) expression ++
  programRows (S index) remaining

private
warningCode : CompatibilitySpelling -> String
warningCode AsciiFatArrow = "ascii-fat-arrow"
warningCode AsciiPipeline = "ascii-pipeline"
warningCode MagrittrPipeline = "magrittr-pipeline"

private
warningRow : WarningDiagnostic -> String
warningRow (MkDiagnostic span (CompatibilitySpellingWarning spelling)) =
  "warning\t" ++ spanFields span ++ "\t" ++ warningCode spelling

private
fatalCode : DiagnosticKind Fatal -> String
fatalCode (UnexpectedCharacter c) =
  "unexpected-character\t" ++ show (pack [c])
fatalCode UnexpectedCloseParenthesis = "unexpected-close-parenthesis"
fatalCode MissingCloseParenthesis = "missing-close-parenthesis"
fatalCode ExpressionMustEndInNoun = "expression-must-end-in-noun"

private
fatalRow : FatalDiagnostic -> String
fatalRow (MkDiagnostic span kind) =
  "fatal\t" ++ spanFields span ++ "\t" ++ fatalCode kind

private
joinRows : List String -> String
joinRows [] = ""
joinRows (row :: rest) = row ++ "\n" ++ joinRows rest

-- Serialize only from the *actual ICKY parser result*. A rejected input
-- produces no successful AST rows. No consumer may silently synthesize them.
public export
covering
renderLocatedResult : Either (List FatalDiagnostic) LocatedParseResult -> String
renderLocatedResult (Left diagnostics) =
  joinRows (protocolHeader :: ("error\t" ++ show (length diagnostics)) ::
           map fatalRow diagnostics)
renderLocatedResult (Right (MkLocatedParseResult (MkLocatedProgram expressions) warnings)) =
  joinRows (protocolHeader :: ("ok\t" ++ show (length expressions)) ::
           (programRows 0 expressions ++ map warningRow warnings))


-- Version 2 extends the same located AST; it does not parse the source again.
-- The extra spelling rows disambiguate 010 from 10 for consumers which need
-- source fidelity. Version 1 remains unchanged for its existing consumers.
-- The caller must still bind the original input bytes independently: these
-- Char offsets are not GCC preprocessing maps or UTF-8 byte positions.
public export
protocolHeaderV2 : String
protocolHeaderV2 = "ICKY-LOCATED\t2\tchar-offset"

mutual
  private
  covering
  naturalOccurrences : String -> LocatedExpr -> List (String, Span, Nat)
  naturalOccurrences path (MkLocatedExpr span leading final) =
    leadingNaturals path 0 leading ++
    finalNaturals (childPath path (length leading)) final

  private
  covering
  leadingNaturals : String -> Nat -> List LocatedPiece -> List (String, Span, Nat)
  leadingNaturals path index [] = []
  leadingNaturals path index (piece :: rest) =
    pieceNaturals (childPath path index) piece ++
    leadingNaturals path (S index) rest

  private
  covering
  pieceNaturals : String -> LocatedPiece -> List (String, Span, Nat)
  pieceNaturals path (LocatedNoun span (NaturalNoun value)) =
    [(path, span, value)]
  pieceNaturals path (LocatedNoun span (NameNoun name)) = []
  pieceNaturals path (LocatedGlyph span glyph) = []
  pieceNaturals path (LocatedGroup span expression) =
    naturalOccurrences path expression

  private
  covering
  finalNaturals : String -> LocatedFinalPiece -> List (String, Span, Nat)
  finalNaturals path (LocatedFinalNoun span (NaturalNoun value)) =
    [(path, span, value)]
  finalNaturals path (LocatedFinalNoun span (NameNoun name)) = []
  finalNaturals path (LocatedFinalGroup span expression) =
    naturalOccurrences path expression

private
covering
programNaturals : Nat -> List LocatedExpr -> List (String, Span, Nat)
programNaturals index [] = []
programNaturals index (expression :: rest) =
  naturalOccurrences (show index) expression ++
  programNaturals (S index) rest

-- This is a checked source *slice*, not a competing number scanner.
-- Decimal.takeDecimalPrefix performs the existing typed lexical recognition.
private
literalAt : String -> Span -> Nat -> Maybe String
literalAt source span expectedValue =
  let start = offsetNumber (positionOffset (spanStart span))
      finish = offsetNumber (positionOffset (spanEnd span))
      chars = unpack source
   in if finish < start || finish > length chars
        then Nothing
        else let written = pack (take (finish - start) (drop start chars))
              in case takeDecimalPrefix (unpack written) of
                   Just (numeral, []) =>
                     if decimalValue numeral == expectedValue &&
                        decimalText numeral == written
                       then Just written
                       else Nothing
                   _ => Nothing

private
checkedSpellings : String -> List (String, Span, Nat) ->
                   Either String (List String)
checkedSpellings source [] = Right []
checkedSpellings source ((path, span, value) :: rest) =
  case literalAt source span value of
    Nothing => Left ("SOURCE_SPELLING_MISMATCH\t" ++ path)
    Just written =>
      case checkedSpellings source rest of
        Left problem => Left problem
        Right rows =>
          Right (("spelling\t" ++ path ++ "\t" ++ spanFields span ++
                  "\t" ++ written) :: rows)

-- A refusal is never represented as a successful tree. The extra records
-- are validated against the same source passed to parseLocatedWithWarnings.
public export
covering
renderLocatedResultV2 : String ->
                        Either (List FatalDiagnostic) LocatedParseResult ->
                        Either String String
renderLocatedResultV2 source (Left diagnostics) =
  Right (joinRows (protocolHeaderV2 ::
                  ("error\t" ++ show (length diagnostics)) ::
                  map fatalRow diagnostics))
renderLocatedResultV2 source
  (Right (MkLocatedParseResult (MkLocatedProgram expressions) warnings)) =
  case checkedSpellings source (programNaturals 0 expressions) of
    Left problem => Left problem
    Right rows =>
      Right (joinRows (protocolHeaderV2 ::
                      ("ok\t" ++ show (length expressions)) ::
                      (programRows 0 expressions ++
                       map warningRow warnings ++ rows)))
