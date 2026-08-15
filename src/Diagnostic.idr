module Diagnostic

%default total

public export
record Position where
  constructor MkPosition
  offset : Nat
  line : Nat
  column : Nat

public export
record Span where
  constructor MkSpan
  start : Position
  end : Position

public export
record Diagnostic where
  constructor MkDiagnostic
  span : Span
  message : String

public export
Eq Position where
  (MkPosition ao al ac) == (MkPosition bo bl bc) =
    ao == bo && al == bl && ac == bc

public export
Eq Span where
  (MkSpan as ae) == (MkSpan bs be) = as == bs && ae == be

public export
Eq Diagnostic where
  (MkDiagnostic as am) == (MkDiagnostic bs bm) = as == bs && am == bm

public export
Show Position where
  show (MkPosition _ line column) = show line ++ ":" ++ show column

public export
Show Span where
  show (MkSpan start end) = show start ++ "-" ++ show end

public export
Show Diagnostic where
  show (MkDiagnostic span message) = show span ++ ": " ++ message
