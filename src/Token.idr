module Token

import Diagnostic
import Glyph

%default total

public export
data TokenKind
  = TName String
  | TNatural Nat
  | TGlyph Glyph
  | TLParen
  | TRParen
  | TNewline
  | TEOF

public export
record Token where
  constructor MkToken
  kind : TokenKind
  span : Span

public export
Eq TokenKind where
  (TName a) == (TName b) = a == b
  (TNatural a) == (TNatural b) = a == b
  (TGlyph a) == (TGlyph b) = a == b
  TLParen == TLParen = True
  TRParen == TRParen = True
  TNewline == TNewline = True
  TEOF == TEOF = True
  _ == _ = False

public export
Eq Token where
  (MkToken ak as) == (MkToken bk bs) = ak == bk && as == bs

public export
Show TokenKind where
  show (TName name) = "name " ++ show name
  show (TNatural n) = "natural " ++ show n
  show (TGlyph glyph) = "glyph " ++ show glyph
  show TLParen = "("
  show TRParen = ")"
  show TNewline = "newline"
  show TEOF = "end of input"

public export
Show Token where
  show (MkToken kind span) = show span ++ " " ++ show kind
