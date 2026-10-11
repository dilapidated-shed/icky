module Located

import Glyph
import Source
import Syntax

%default total

-- Successful syntax preserves typed noun-ending expressions, while the
-- parallel located representation attaches actual scanner spans to each
-- retained piece. Group spans include the parentheses; child expression
-- spans cover only the contents.

mutual
  public export
  record LocatedExpr where
    constructor MkLocatedExpr
    locatedSpan : Span
    locatedLeading : List LocatedPiece
    locatedFinal : LocatedFinalPiece

  public export
  data LocatedPiece
    = LocatedNoun Span Noun
    | LocatedGlyph Span Glyph
    | LocatedGroup Span LocatedExpr

  public export
  data LocatedFinalPiece
    = LocatedFinalNoun Span Noun
    | LocatedFinalGroup Span LocatedExpr

public export
record LocatedProgram where
  constructor MkLocatedProgram
  locatedExpressions : List LocatedExpr

public export
pieceSpan : LocatedPiece -> Span
pieceSpan (LocatedNoun span noun) = span
pieceSpan (LocatedGlyph span glyph) = span
pieceSpan (LocatedGroup span expression) = span

public export
finalSpan : LocatedFinalPiece -> Span
finalSpan (LocatedFinalNoun span noun) = span
finalSpan (LocatedFinalGroup span expression) = span

private
splitLast : List a -> Maybe (List a, a)
splitLast [] = Nothing
splitLast [last] = Just ([], last)
splitLast (first :: rest) =
  case splitLast rest of
    Just (leading, last) => Just (first :: leading, last)
    Nothing => Nothing

-- The constructor chooses the expression span from the written first and
-- last pieces, rather than trusting an independent guessed source interval.
public export
exprFromLocatedPieces : List LocatedPiece -> Maybe LocatedExpr
exprFromLocatedPieces [] = Nothing
exprFromLocatedPieces (first :: rest) =
  case splitLast (first :: rest) of
    Just (leading, LocatedNoun span noun) =>
      Just (MkLocatedExpr
             (spanBetween (spanStart (pieceSpan first)) (spanEnd span))
             leading (LocatedFinalNoun span noun))
    Just (leading, LocatedGroup span expression) =>
      Just (MkLocatedExpr
             (spanBetween (spanStart (pieceSpan first)) (spanEnd span))
             leading (LocatedFinalGroup span expression))
    _ => Nothing

mutual
  public export
  covering
  eraseLocatedExpr : LocatedExpr -> Expr
  eraseLocatedExpr (MkLocatedExpr span leading final) =
    MkExpr (map eraseLocatedPiece leading) (eraseLocatedFinal final)

  public export
  covering
  eraseLocatedPiece : LocatedPiece -> Piece
  eraseLocatedPiece (LocatedNoun span noun) = NounPiece noun
  eraseLocatedPiece (LocatedGlyph span glyph) = GlyphPiece glyph
  eraseLocatedPiece (LocatedGroup span expression) =
    GroupPiece (eraseLocatedExpr expression)

  public export
  covering
  eraseLocatedFinal : LocatedFinalPiece -> FinalPiece
  eraseLocatedFinal (LocatedFinalNoun span noun) = FinalNoun noun
  eraseLocatedFinal (LocatedFinalGroup span expression) =
    FinalGroup (eraseLocatedExpr expression)

public export
covering
eraseLocatedProgram : LocatedProgram -> Program
eraseLocatedProgram (MkLocatedProgram expressions) =
  MkProgram (map eraseLocatedExpr expressions)
