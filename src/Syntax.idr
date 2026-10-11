module Syntax

import Glyph
import Name

%default total

public export
data Noun
  = NameNoun Name
  | NaturalNoun Nat

mutual
  public export
  record Expr where
    constructor MkExpr
    leadingPieces : List Piece
    finalPiece : FinalPiece

  public export
  data Piece
    = NounPiece Noun
    | GlyphPiece Glyph
    | GroupPiece Expr

  public export
  data FinalPiece
    = FinalNoun Noun
    | FinalGroup Expr

private
finalAsPiece : FinalPiece -> Piece
finalAsPiece (FinalNoun noun) = NounPiece noun
finalAsPiece (FinalGroup expression) = GroupPiece expression

public export
covering
exprPieces : Expr -> List Piece
exprPieces (MkExpr leading final) = leading ++ [finalAsPiece final]

private
splitLast : List a -> Maybe (List a, a)
splitLast [] = Nothing
splitLast [last] = Just ([], last)
splitLast (first :: rest) =
  case splitLast rest of
    Just (leading, last) => Just (first :: leading, last)
    Nothing => Nothing

public export
covering
exprFromPieces : List Piece -> Maybe Expr
exprFromPieces pieces =
  case splitLast pieces of
    Just (leading, NounPiece noun) => Just (MkExpr leading (FinalNoun noun))
    Just (leading, GroupPiece expression) => Just (MkExpr leading (FinalGroup expression))
    _ => Nothing

public export
record Program where
  constructor MkProgram
  expressions : List Expr

public export
Eq Noun where
  (NameNoun a) == (NameNoun b) = a == b
  (NaturalNoun a) == (NaturalNoun b) = a == b
  _ == _ = False

mutual
  public export
  covering
  Eq Expr where
    (MkExpr al af) == (MkExpr bl bf) = al == bl && af == bf

  public export
  covering
  Eq Piece where
    (NounPiece a) == (NounPiece b) = a == b
    (GlyphPiece a) == (GlyphPiece b) = a == b
    (GroupPiece a) == (GroupPiece b) = a == b
    _ == _ = False

  public export
  covering
  Eq FinalPiece where
    (FinalNoun a) == (FinalNoun b) = a == b
    (FinalGroup a) == (FinalGroup b) = a == b
    _ == _ = False

public export
covering
Eq Program where
  (MkProgram a) == (MkProgram b) = a == b

public export
Show Noun where
  show (NameNoun name) = nameText name
  show (NaturalNoun n) = show n

mutual
  private
  covering
  showPieces : List Piece -> String
  showPieces [] = ""
  showPieces [piece] = show piece
  showPieces (piece :: pieces) = show piece ++ " " ++ showPieces pieces

  public export
  covering
  Show Expr where
    show expression = showPieces (exprPieces expression)

  public export
  covering
  Show Piece where
    show (NounPiece noun) = show noun
    show (GlyphPiece glyph) = show glyph
    show (GroupPiece expr) = "(" ++ show expr ++ ")"

  public export
  covering
  Show FinalPiece where
    show = show . finalAsPiece

public export
covering
Show Program where
  show (MkProgram expressions) = show expressions
