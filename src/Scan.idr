module Scan

import Decimal
import Diagnostic
import Glyph
import Name
import Source
import Token


public export
record ScanResult where
  constructor MkScanResult
  tokens : List Token
  warnings : List WarningDiagnostic

private
skipComment : Position -> List Char -> (List Char, Position)
skipComment position [] = ([], position)
skipComment position input@(c :: cs) =
  if c == '\n'
     then (input, position)
     else skipComment (advancePosition position c) cs

private
scanChars : Position -> List Char -> List Token -> List FatalDiagnostic ->
            List WarningDiagnostic -> Either (List FatalDiagnostic) ScanResult
scanChars position [] tokens diagnostics warnings =
  let eof = MkToken TEOF (pointSpan position)
      allTokens = reverse (eof :: tokens)
      allDiagnostics = reverse diagnostics
      allWarnings = reverse warnings
   in case allDiagnostics of
        [] => Right (MkScanResult allTokens allWarnings)
        _ => Left allDiagnostics
scanChars position ('=' :: '>' :: cs) tokens diagnostics warnings =
  let afterEquals = advancePosition position '='
      next = advancePosition afterEquals '>'
      span = spanBetween position next
      token = MkToken (TGlyph DoubleRightArrow) span
      warning = MkDiagnostic span (CompatibilitySpellingWarning AsciiFatArrow)
   in scanChars next cs (token :: tokens) diagnostics (warning :: warnings)
scanChars position ('|' :: '>' :: cs) tokens diagnostics warnings =
  let afterBar = advancePosition position '|'
      next = advancePosition afterBar '>'
      span = spanBetween position next
      token = MkToken (TGlyph MiddleDot) span
      warning = MkDiagnostic span (CompatibilitySpellingWarning AsciiPipeline)
   in scanChars next cs (token :: tokens) diagnostics (warning :: warnings)
scanChars position ('%' :: '>' :: '%' :: cs) tokens diagnostics warnings =
  let afterPercent = advancePosition position '%'
      afterGreater = advancePosition afterPercent '>'
      next = advancePosition afterGreater '%'
      span = spanBetween position next
      token = MkToken (TGlyph MiddleDot) span
      warning = MkDiagnostic span (CompatibilitySpellingWarning MagrittrPipeline)
   in scanChars next cs (token :: tokens) diagnostics (warning :: warnings)
scanChars position input@(c :: cs) tokens diagnostics warnings =
  if c == ' ' || c == '\t' || c == '\r'
     then scanChars (advancePosition position c) cs tokens diagnostics warnings
  else if c == '\n'
     then let next = advancePosition position c
              token = MkToken TNewline (spanBetween position next)
           in scanChars next cs (token :: tokens) diagnostics warnings
  else if c == '⍝'
     then let afterMarker = advancePosition position c
              (rest, next) = skipComment afterMarker cs
           in scanChars next rest tokens diagnostics warnings
  else if c == '('
     then let next = advancePosition position c
              token = MkToken TLParen (spanBetween position next)
           in scanChars next cs (token :: tokens) diagnostics warnings
  else if c == ')'
     then let next = advancePosition position c
              token = MkToken TRParen (spanBetween position next)
           in scanChars next cs (token :: tokens) diagnostics warnings
  else case glyphFromChar c of
         Just glyph =>
           let next = advancePosition position c
               token = MkToken (TGlyph glyph) (spanBetween position next)
            in scanChars next cs (token :: tokens) diagnostics warnings
         Nothing =>
           case takeNamePrefix input of
             Just (name, rest) =>
               let end = advancePositions position (unpack (nameText name))
                   token = MkToken (TName name) (spanBetween position end)
                in scanChars end rest (token :: tokens) diagnostics warnings
             Nothing =>
               case takeDecimalPrefix input of
                 Just (numeral, rest) =>
                   let end = advancePositions position (unpack (decimalText numeral))
                       token = MkToken (TNatural (decimalValue numeral))
                                       (spanBetween position end)
                    in scanChars end rest (token :: tokens) diagnostics warnings
                 Nothing =>
                   let next = advancePosition position c
                       diagnostic = MkDiagnostic (spanBetween position next)
                                                 (UnexpectedCharacter c)
                    in scanChars next cs tokens (diagnostic :: diagnostics) warnings

public export
scanWithWarnings : String -> Either (List FatalDiagnostic) ScanResult
scanWithWarnings source = scanChars sourceStart (unpack source) [] [] []

public export
scan : String -> Either (List FatalDiagnostic) (List Token)
scan source =
  case scanWithWarnings source of
    Left diagnostics => Left diagnostics
    Right (MkScanResult tokens warnings) => Right tokens
