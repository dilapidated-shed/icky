module Syntax

import Glyph

%default total

public export
data Noun
  = NameNoun String
  | NaturalNoun Nat

mutual
  public export
  record Expr where
    constructor MkExpr
    pieces : List Piece

  public export
  data Piece
    = NounPiece Noun
    | GlyphPiece Glyph
    | GroupPiece Expr

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
    (MkExpr a) == (MkExpr b) = a == b

  public export
  covering
  Eq Piece where
    (NounPiece a) == (NounPiece b) = a == b
    (GlyphPiece a) == (GlyphPiece b) = a == b
    (GroupPiece a) == (GroupPiece b) = a == b
    _ == _ = False

public export
covering
Eq Program where
  (MkProgram a) == (MkProgram b) = a == b

public export
Show Noun where
  show (NameNoun name) = name
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
    show (MkExpr pieces) = showPieces pieces

  public export
  covering
  Show Piece where
    show (NounPiece noun) = show noun
    show (GlyphPiece glyph) = show glyph
    show (GroupPiece expr) = "(" ++ show expr ++ ")"

public export
covering
Show Program where
  show (MkProgram expressions) = show expressions
