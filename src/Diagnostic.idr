module Diagnostic

import Glyph
import Source

%default total

public export
data Severity = Fatal | Warning

public export
data CompatibilitySpelling
  = AsciiFatArrow
  | AsciiPipeline
  | MagrittrPipeline

public export
data DiagnosticKind : Severity -> Type where
  UnexpectedCharacter : Char -> DiagnosticKind Fatal
  UnexpectedCloseParenthesis : DiagnosticKind Fatal
  MissingCloseParenthesis : DiagnosticKind Fatal
  ExpressionMustEndInNoun : DiagnosticKind Fatal
  CompatibilitySpellingWarning : CompatibilitySpelling -> DiagnosticKind Warning

public export
record Diagnostic (severity : Severity) where
  constructor MkDiagnostic
  span : Span
  kind : DiagnosticKind severity

public export
FatalDiagnostic : Type
FatalDiagnostic = Diagnostic Fatal

public export
WarningDiagnostic : Type
WarningDiagnostic = Diagnostic Warning

public export
diagnosticSeverity : {severity : Severity} -> Diagnostic severity -> Severity
diagnosticSeverity {severity} diagnostic = severity

public export
compatibilityText : CompatibilitySpelling -> String
compatibilityText AsciiFatArrow = "=>"
compatibilityText AsciiPipeline = "|>"
compatibilityText MagrittrPipeline = "%>%"

public export
compatibilityGlyph : CompatibilitySpelling -> Glyph
compatibilityGlyph AsciiFatArrow = DoubleRightArrow
compatibilityGlyph AsciiPipeline = MiddleDot
compatibilityGlyph MagrittrPipeline = MiddleDot

public export
renderDiagnosticKind : DiagnosticKind severity -> String
renderDiagnosticKind (UnexpectedCharacter c) =
  "unexpected character " ++ show (pack [c])
renderDiagnosticKind UnexpectedCloseParenthesis = "unexpected ')'"
renderDiagnosticKind MissingCloseParenthesis = "missing ')'"
renderDiagnosticKind ExpressionMustEndInNoun = "expression must end in a noun"
renderDiagnosticKind (CompatibilitySpellingWarning spelling) =
  let written = compatibilityText spelling
      preferred = pack [glyphChar (compatibilityGlyph spelling)]
   in case spelling of
        MagrittrPipeline =>
          "Magrittr '" ++ written ++ "' accepted; prefer '" ++ preferred ++ "'"
        _ =>
          "ASCII '" ++ written ++ "' accepted; prefer '" ++ preferred ++ "'"

public export
diagnosticMessage : Diagnostic severity -> String
diagnosticMessage (MkDiagnostic _ kind) = renderDiagnosticKind kind

public export
renderDiagnostic : Diagnostic severity -> String
renderDiagnostic diagnostic =
  show diagnostic.span ++ ": " ++ diagnosticMessage diagnostic

public export
Eq Severity where
  Fatal == Fatal = True
  Warning == Warning = True
  _ == _ = False

public export
Eq CompatibilitySpelling where
  AsciiFatArrow == AsciiFatArrow = True
  AsciiPipeline == AsciiPipeline = True
  MagrittrPipeline == MagrittrPipeline = True
  _ == _ = False

public export
Eq (DiagnosticKind severity) where
  (UnexpectedCharacter a) == (UnexpectedCharacter b) = a == b
  UnexpectedCloseParenthesis == UnexpectedCloseParenthesis = True
  MissingCloseParenthesis == MissingCloseParenthesis = True
  ExpressionMustEndInNoun == ExpressionMustEndInNoun = True
  (CompatibilitySpellingWarning a) == (CompatibilitySpellingWarning b) = a == b
  _ == _ = False

public export
Eq (Diagnostic severity) where
  (MkDiagnostic as ak) == (MkDiagnostic bs bk) = as == bs && ak == bk

public export
Show Severity where
  show Fatal = "fatal"
  show Warning = "warning"

public export
Show CompatibilitySpelling where
  show = compatibilityText

public export
Show (DiagnosticKind severity) where
  show = renderDiagnosticKind

public export
Show (Diagnostic severity) where
  show = renderDiagnostic
