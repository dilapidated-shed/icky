module Glyph

%default total

public export
data Glyph
  = LeftArrow
  | Equals
  | Target
  | UpArrow
  | MiddleDot

public export
glyphChar : Glyph -> Char
glyphChar LeftArrow = '←'
glyphChar Equals = '='
glyphChar Target = '⌖'
glyphChar UpArrow = '↥'
glyphChar MiddleDot = '·'

public export
glyphFromChar : Char -> Maybe Glyph
glyphFromChar '←' = Just LeftArrow
glyphFromChar '=' = Just Equals
glyphFromChar '⌖' = Just Target
glyphFromChar '↥' = Just UpArrow
glyphFromChar '·' = Just MiddleDot
glyphFromChar _ = Nothing

public export
Eq Glyph where
  LeftArrow == LeftArrow = True
  Equals == Equals = True
  Target == Target = True
  UpArrow == UpArrow = True
  MiddleDot == MiddleDot = True
  _ == _ = False

public export
Show Glyph where
  show glyph = pack [glyphChar glyph]
