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
  | Division
  | Multiplication
  | SquareRoot
  | SuperscriptTwo
  | SuperscriptThree
  | NotEqual
  | DecidableEqual
  | Lambda
  | Infinity
  | Minus
  | EnDash

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
glyphChar Division = '÷'
glyphChar Multiplication = '×'
glyphChar SquareRoot = '√'
glyphChar SuperscriptTwo = '²'
glyphChar SuperscriptThree = '³'
glyphChar NotEqual = '≠'
glyphChar DecidableEqual = '≟'
glyphChar Lambda = 'λ'
glyphChar Infinity = '∞'
glyphChar Minus = '−'
glyphChar EnDash = '–'

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
glyphFromChar '÷' = Just Division
glyphFromChar '×' = Just Multiplication
glyphFromChar '√' = Just SquareRoot
glyphFromChar '²' = Just SuperscriptTwo
glyphFromChar '³' = Just SuperscriptThree
glyphFromChar '≠' = Just NotEqual
glyphFromChar '≟' = Just DecidableEqual
glyphFromChar 'λ' = Just Lambda
glyphFromChar '∞' = Just Infinity
glyphFromChar '−' = Just Minus
glyphFromChar '–' = Just EnDash
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
  Division == Division = True
  Multiplication == Multiplication = True
  SquareRoot == SquareRoot = True
  SuperscriptTwo == SuperscriptTwo = True
  SuperscriptThree == SuperscriptThree = True
  NotEqual == NotEqual = True
  DecidableEqual == DecidableEqual = True
  Lambda == Lambda = True
  Infinity == Infinity = True
  Minus == Minus = True
  EnDash == EnDash = True
  _ == _ = False

public export
Show Glyph where
  show glyph = pack [glyphChar glyph]
