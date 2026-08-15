module Scan

import Diagnostic
import Glyph
import Token


private
advance : Position -> Char -> Position
advance (MkPosition offset line column) '\n' =
  MkPosition (S offset) (S line) 1
advance (MkPosition offset line column) _ =
  MkPosition (S offset) line (S column)

private
isLetter : Char -> Bool
isLetter c = elem c (unpack "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")

private
isDigit : Char -> Bool
isDigit c = elem c (unpack "0123456789")

private
isNameTail : Char -> Bool
isNameTail c = isLetter c || isDigit c || c == '_'

private
digitValue : Char -> Nat
digitValue '0' = 0
digitValue '1' = 1
digitValue '2' = 2
digitValue '3' = 3
digitValue '4' = 4
digitValue '5' = 5
digitValue '6' = 6
digitValue '7' = 7
digitValue '8' = 8
digitValue '9' = 9
digitValue _ = 0

private
digitsToNat : List Char -> Nat
digitsToNat = foldl (\acc, c => acc * 10 + digitValue c) 0

private
record Run where
  constructor MkRun
  chars : List Char
  rest : List Char
  end : Position

private
consumeWhile : (Char -> Bool) -> Position -> List Char -> Run
consumeWhile predicate position [] = MkRun [] [] position
consumeWhile predicate position (c :: cs) =
  if predicate c
     then let next = advance position c
              MkRun taken rest end = consumeWhile predicate next cs
           in MkRun (c :: taken) rest end
     else MkRun [] (c :: cs) position

private
skipComment : Position -> List Char -> (List Char, Position)
skipComment position [] = ([], position)
skipComment position input@(c :: cs) =
  if c == '\n'
     then (input, position)
     else skipComment (advance position c) cs

private
scanChars : Position -> List Char -> List Token -> List Diagnostic ->
            Either (List Diagnostic) (List Token)
scanChars position [] tokens diagnostics =
  let eof = MkToken TEOF (MkSpan position position)
      allTokens = reverse (eof :: tokens)
      allDiagnostics = reverse diagnostics
   in case allDiagnostics of
        [] => Right allTokens
        _ => Left allDiagnostics
scanChars position (c :: cs) tokens diagnostics =
  if c == ' ' || c == '\t' || c == '\r'
     then scanChars (advance position c) cs tokens diagnostics
  else if c == '\n'
     then let next = advance position c
              token = MkToken TNewline (MkSpan position next)
           in scanChars next cs (token :: tokens) diagnostics
  else if c == '⍝'
     then let afterMarker = advance position c
              (rest, next) = skipComment afterMarker cs
           in scanChars next rest tokens diagnostics
  else if c == '('
     then let next = advance position c
              token = MkToken TLParen (MkSpan position next)
           in scanChars next cs (token :: tokens) diagnostics
  else if c == ')'
     then let next = advance position c
              token = MkToken TRParen (MkSpan position next)
           in scanChars next cs (token :: tokens) diagnostics
  else case glyphFromChar c of
         Just glyph =>
           let next = advance position c
               token = MkToken (TGlyph glyph) (MkSpan position next)
            in scanChars next cs (token :: tokens) diagnostics
         Nothing =>
           if isLetter c || c == '_'
              then let next = advance position c
                       MkRun tail rest end = consumeWhile isNameTail next cs
                       token = MkToken (TName (pack (c :: tail))) (MkSpan position end)
                    in scanChars end rest (token :: tokens) diagnostics
           else if isDigit c
              then let next = advance position c
                       MkRun tail rest end = consumeWhile isDigit next cs
                       token = MkToken (TNatural (digitsToNat (c :: tail))) (MkSpan position end)
                    in scanChars end rest (token :: tokens) diagnostics
           else let next = advance position c
                    diagnostic = MkDiagnostic (MkSpan position next)
                                    ("unexpected character " ++ show (pack [c]))
                 in scanChars next cs tokens (diagnostic :: diagnostics)

public export
scan : String -> Either (List Diagnostic) (List Token)
scan source = scanChars (MkPosition 0 1 1) (unpack source) [] []
