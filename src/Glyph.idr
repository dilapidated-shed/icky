module Glyph

%default total

public export
data Glyph
  = LeftArrow
  | RightArrow
  | DoubleLeftArrow
  | DoubleRightArrow
  | Equals
  | Target
  | UpArrow
  | DownArrow
  | MiddleDot
  | Composition

public export
glyphChar : Glyph -> Char
glyphChar LeftArrow = '←'
glyphChar RightArrow = '→'
glyphChar DoubleLeftArrow = '⇐'
glyphChar DoubleRightArrow = '⇒'
glyphChar Equals = '='
glyphChar Target = '⌖'
glyphChar UpArrow = '↥'
glyphChar DownArrow = '↧'
glyphChar MiddleDot = '·'
glyphChar Composition = '∘'

public export
glyphFromChar : Char -> Maybe Glyph
glyphFromChar '←' = Just LeftArrow
glyphFromChar '→' = Just RightArrow
glyphFromChar '⇐' = Just DoubleLeftArrow
glyphFromChar '⇒' = Just DoubleRightArrow
glyphFromChar '=' = Just Equals
glyphFromChar '⌖' = Just Target
glyphFromChar '↥' = Just UpArrow
glyphFromChar '↧' = Just DownArrow
glyphFromChar '·' = Just MiddleDot
glyphFromChar '∘' = Just Composition
glyphFromChar _ = Nothing

public export
reverseGlyph : Glyph -> Maybe Glyph
reverseGlyph LeftArrow = Just RightArrow
reverseGlyph RightArrow = Just LeftArrow
reverseGlyph DoubleLeftArrow = Just DoubleRightArrow
reverseGlyph DoubleRightArrow = Just DoubleLeftArrow
reverseGlyph UpArrow = Just DownArrow
reverseGlyph DownArrow = Just UpArrow
reverseGlyph _ = Nothing

public export
Eq Glyph where
  LeftArrow == LeftArrow = True
  RightArrow == RightArrow = True
  DoubleLeftArrow == DoubleLeftArrow = True
  DoubleRightArrow == DoubleRightArrow = True
  Equals == Equals = True
  Target == Target = True
  UpArrow == UpArrow = True
  DownArrow == DownArrow = True
  MiddleDot == MiddleDot = True
  Composition == Composition = True
  _ == _ = False

public export
Show Glyph where
  show glyph = pack [glyphChar glyph]
