module Parse

import Diagnostic
import Glyph
import Scan
import Syntax
import Token


public export
record ParseResult where
  constructor MkParseResult
  program : Program
  warnings : List Diagnostic

private
record SequenceResult where
  constructor MkSequenceResult
  pieces : List Piece
  rest : List Token
  diagnostics : List Diagnostic

private
lastPiece : List Piece -> Maybe Piece
lastPiece [] = Nothing
lastPiece [piece] = Just piece
lastPiece (_ :: pieces) = lastPiece pieces

mutual
  private
  endsInNoun : Expr -> Bool
  endsInNoun (MkExpr pieces) =
    case lastPiece pieces of
      Just (NounPiece _) => True
      Just (GroupPiece expr) => endsInNoun expr
      _ => False

  private
  validateNounLast : Span -> Expr -> List Diagnostic
  validateNounLast boundary expr =
    if endsInNoun expr
       then []
       else [MkDiagnostic boundary "expression must end in a noun"]

private
boundarySpan : List Token -> Span
boundarySpan [] =
  let position = MkPosition 0 1 1 in MkSpan position position
boundarySpan (MkToken _ span :: _) = span

mutual
  private
  parseSequence : Bool -> List Token -> SequenceResult
  parseSequence inGroup [] = MkSequenceResult [] [] []
  parseSequence inGroup tokens@(MkToken TEOF span :: rest) =
    MkSequenceResult [] tokens []
  parseSequence True tokens@(MkToken TRParen span :: rest) =
    MkSequenceResult [] tokens []
  parseSequence False tokens@(MkToken TNewline span :: rest) =
    MkSequenceResult [] tokens []
  parseSequence True (MkToken TNewline span :: rest) =
    parseSequence True rest
  parseSequence False (MkToken TRParen span :: rest) =
    let MkSequenceResult pieces remaining diagnostics = parseSequence False rest
        unexpected = MkDiagnostic span "unexpected ')'"
     in MkSequenceResult pieces remaining (unexpected :: diagnostics)
  parseSequence inGroup (MkToken TLParen openSpan :: rest) =
    let MkSequenceResult inside afterInside insideDiagnostics = parseSequence True rest
        innerExpr = MkExpr inside
        boundary = boundarySpan afterInside
        nounDiagnostics = validateNounLast boundary innerExpr
     in case afterInside of
          MkToken TRParen closeSpan :: afterClose =>
            let MkSequenceResult following remaining followingDiagnostics =
                  parseSequence inGroup afterClose
             in MkSequenceResult (GroupPiece innerExpr :: following)
                  remaining (insideDiagnostics ++ nounDiagnostics ++ followingDiagnostics)
          _ =>
            let missing = MkDiagnostic openSpan "missing ')'"
                MkSequenceResult following remaining followingDiagnostics =
                  parseSequence inGroup afterInside
             in MkSequenceResult (GroupPiece innerExpr :: following)
                  remaining (insideDiagnostics ++ nounDiagnostics ++ [missing] ++ followingDiagnostics)
  parseSequence inGroup (MkToken (TName name) span :: rest) =
    let MkSequenceResult pieces remaining diagnostics = parseSequence inGroup rest
     in MkSequenceResult (NounPiece (NameNoun name) :: pieces) remaining diagnostics
  parseSequence inGroup (MkToken (TNatural n) span :: rest) =
    let MkSequenceResult pieces remaining diagnostics = parseSequence inGroup rest
     in MkSequenceResult (NounPiece (NaturalNoun n) :: pieces) remaining diagnostics
  parseSequence inGroup (MkToken (TGlyph glyph) span :: rest) =
    let MkSequenceResult pieces remaining diagnostics = parseSequence inGroup rest
     in MkSequenceResult (GlyphPiece glyph :: pieces) remaining diagnostics

private
parseProgram : List Token -> List Expr -> List Diagnostic -> Either (List Diagnostic) Program
parseProgram [] expressions diagnostics =
  case reverse diagnostics of
    [] => Right (MkProgram (reverse expressions))
    errors => Left errors
parseProgram (MkToken TEOF span :: rest) expressions diagnostics =
  case reverse diagnostics of
    [] => Right (MkProgram (reverse expressions))
    errors => Left errors
parseProgram (MkToken TNewline span :: rest) expressions diagnostics =
  parseProgram rest expressions diagnostics
parseProgram tokens expressions diagnostics =
  let MkSequenceResult pieces rest sequenceDiagnostics = parseSequence False tokens
      expr = MkExpr pieces
      nounDiagnostics = validateNounLast (boundarySpan rest) expr
      allDiagnostics = reverse nounDiagnostics ++ reverse sequenceDiagnostics ++ diagnostics
   in case pieces of
        [] => parseProgram rest expressions allDiagnostics
        _ => parseProgram rest (expr :: expressions) allDiagnostics

public export
parseWithWarnings : String -> Either (List Diagnostic) ParseResult
parseWithWarnings source =
  case scanWithWarnings source of
    Left diagnostics => Left diagnostics
    Right (MkScanResult tokens warnings) =>
      case parseProgram tokens [] [] of
        Left diagnostics => Left diagnostics
        Right program => Right (MkParseResult program warnings)

public export
parse : String -> Either (List Diagnostic) Program
parse source =
  case parseWithWarnings source of
    Left diagnostics => Left diagnostics
    Right (MkParseResult program warnings) => Right program
