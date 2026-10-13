module MixedSeverity

import Diagnostic
import Source

badWarning : WarningDiagnostic
badWarning = MkDiagnostic (pointSpan sourceStart) (UnexpectedCharacter '@')
