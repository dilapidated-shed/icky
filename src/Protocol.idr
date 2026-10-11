module Protocol

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
