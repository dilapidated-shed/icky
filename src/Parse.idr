module Parse

import Diagnostic
import Glyph
import Scan
import Source
import Syntax
import Token


public export
record ParseResult where
  constructor MkParseResult
  program : Program
  warnings : List WarningDiagnostic

private
data SequenceContext = TopLevel | InsideGroup

private
data ParsedEnding = EndsWithNoun | DoesNotEndWithNoun

private
data ParsedPiece
  = ParsedNoun Noun
  | ParsedGlyph Glyph
  | ParsedGroup ParsedEnding (Maybe Expr)

private
record SequenceResult where
  constructor MkSequenceResult
  pieces : List ParsedPiece
  rest : List Token
  diagnostics : List FatalDiagnostic

private
lastParsedPiece : List ParsedPiece -> Maybe ParsedPiece
lastParsedPiece [] = Nothing
lastParsedPiece [piece] = Just piece
lastParsedPiece (_ :: pieces) = lastParsedPiece pieces

private
parsedEnding : List ParsedPiece -> ParsedEnding
parsedEnding pieces =
  case lastParsedPiece pieces of
    Just (ParsedNoun _) => EndsWithNoun
    Just (ParsedGroup ending expression) => ending
    _ => DoesNotEndWithNoun

private
validateNounLast : Span -> List ParsedPiece -> List FatalDiagnostic
validateNounLast boundary pieces =
  case parsedEnding pieces of
    EndsWithNoun => []
    DoesNotEndWithNoun => [MkDiagnostic boundary ExpressionMustEndInNoun]

private
parsedPiece : ParsedPiece -> Maybe Piece
parsedPiece (ParsedNoun noun) = Just (NounPiece noun)
parsedPiece (ParsedGlyph glyph) = Just (GlyphPiece glyph)
parsedPiece (ParsedGroup ending (Just expression)) = Just (GroupPiece expression)
parsedPiece (ParsedGroup ending Nothing) = Nothing

private
parsedPieces : List ParsedPiece -> Maybe (List Piece)
parsedPieces [] = Just []
parsedPieces (piece :: rest) =
  case (parsedPiece piece, parsedPieces rest) of
    (Just converted, Just convertedRest) => Just (converted :: convertedRest)
    _ => Nothing

private
parsedExpression : List ParsedPiece -> Maybe Expr
parsedExpression pieces =
  case parsedPieces pieces of
    Just converted => exprFromPieces converted
    Nothing => Nothing

private
boundarySpan : List Token -> Span
boundarySpan [] = pointSpan sourceStart
boundarySpan (MkToken _ span :: _) = span

mutual
  private
  parseSequence : SequenceContext -> List Token -> SequenceResult
  parseSequence context [] = MkSequenceResult [] [] []
  parseSequence context tokens@(MkToken TEOF span :: rest) =
    MkSequenceResult [] tokens []
  parseSequence InsideGroup tokens@(MkToken TRParen span :: rest) =
    MkSequenceResult [] tokens []
  parseSequence TopLevel tokens@(MkToken TNewline span :: rest) =
    MkSequenceResult [] tokens []
  parseSequence InsideGroup (MkToken TNewline span :: rest) =
    parseSequence InsideGroup rest
  parseSequence TopLevel (MkToken TRParen span :: rest) =
    let MkSequenceResult pieces remaining diagnostics = parseSequence TopLevel rest
        unexpected = MkDiagnostic span UnexpectedCloseParenthesis
     in MkSequenceResult pieces remaining (unexpected :: diagnostics)
  parseSequence context (MkToken TLParen openSpan :: rest) =
    let MkSequenceResult inside afterInside insideDiagnostics =
          parseSequence InsideGroup rest
        boundary = boundarySpan afterInside
        nounDiagnostics = validateNounLast boundary inside
        innerEnding = parsedEnding inside
        innerExpression = parsedExpression inside
     in case afterInside of
          MkToken TRParen closeSpan :: afterClose =>
            let MkSequenceResult following remaining followingDiagnostics =
                  parseSequence context afterClose
             in MkSequenceResult (ParsedGroup innerEnding innerExpression :: following)
                  remaining (insideDiagnostics ++ nounDiagnostics ++ followingDiagnostics)
          _ =>
            let missing = MkDiagnostic openSpan MissingCloseParenthesis
                MkSequenceResult following remaining followingDiagnostics =
                  parseSequence context afterInside
             in MkSequenceResult (ParsedGroup innerEnding innerExpression :: following)
                  remaining (insideDiagnostics ++ nounDiagnostics ++ [missing] ++ followingDiagnostics)
  parseSequence context (MkToken (TName name) span :: rest) =
    let MkSequenceResult pieces remaining diagnostics = parseSequence context rest
     in MkSequenceResult (ParsedNoun (NameNoun name) :: pieces) remaining diagnostics
  parseSequence context (MkToken (TNatural n) span :: rest) =
    let MkSequenceResult pieces remaining diagnostics = parseSequence context rest
     in MkSequenceResult (ParsedNoun (NaturalNoun n) :: pieces) remaining diagnostics
  parseSequence context (MkToken (TGlyph glyph) span :: rest) =
    let MkSequenceResult pieces remaining diagnostics = parseSequence context rest
     in MkSequenceResult (ParsedGlyph glyph :: pieces) remaining diagnostics

private
parseProgram : List Token -> List Expr -> List FatalDiagnostic ->
               Either (List FatalDiagnostic) Program
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
  let MkSequenceResult pieces rest sequenceDiagnostics = parseSequence TopLevel tokens
      expression = parsedExpression pieces
      nounDiagnostics = validateNounLast (boundarySpan rest) pieces
      allDiagnostics = reverse nounDiagnostics ++ reverse sequenceDiagnostics ++ diagnostics
   in case (pieces, expression) of
        ([], _) => parseProgram rest expressions allDiagnostics
        (_, Just expr) => parseProgram rest (expr :: expressions) allDiagnostics
        (_, Nothing) => parseProgram rest expressions allDiagnostics

public export
parseWithWarnings : String -> Either (List FatalDiagnostic) ParseResult
parseWithWarnings source =
  case scanWithWarnings source of
    Left diagnostics => Left diagnostics
    Right (MkScanResult tokens warnings) =>
      case parseProgram tokens [] [] of
        Left diagnostics => Left diagnostics
        Right program => Right (MkParseResult program warnings)

public export
parse : String -> Either (List FatalDiagnostic) Program
parse source =
  case parseWithWarnings source of
    Left diagnostics => Left diagnostics
    Right (MkParseResult program warnings) => Right program
