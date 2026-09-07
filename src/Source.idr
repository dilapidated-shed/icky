module Source

%default total

-- Source offsets count Idris Char values from zero.  The constructor stays
-- private so an offset cannot be confused with either one-based coordinate.
export
data SourceOffset = OffsetFromStart Nat

-- These store how many complete lines precede the current line.  Rendering
-- adds one, which makes a zero line unrepresentable.
export
data SourceLine = AfterLines Nat

-- Likewise, this stores how many characters precede the current column.
export
data SourceColumn = AfterColumns Nat

export
data Position = AtPosition SourceOffset SourceLine SourceColumn

export
data Span = FromPositionTo Position Position

export
sourceStart : Position
sourceStart = AtPosition (OffsetFromStart 0) (AfterLines 0) (AfterColumns 0)

export
advancePosition : Position -> Char -> Position
advancePosition (AtPosition (OffsetFromStart offset) (AfterLines line) column) '\n' =
  AtPosition (OffsetFromStart (S offset)) (AfterLines (S line)) (AfterColumns 0)
advancePosition (AtPosition (OffsetFromStart offset) line (AfterColumns column)) _ =
  AtPosition (OffsetFromStart (S offset)) line (AfterColumns (S column))

export
advancePositions : Position -> List Char -> Position
advancePositions = foldl advancePosition

export
spanBetween : Position -> Position -> Span
spanBetween = FromPositionTo

export
pointSpan : Position -> Span
pointSpan position = FromPositionTo position position

export
spanStart : Span -> Position
spanStart (FromPositionTo start end) = start

export
spanEnd : Span -> Position
spanEnd (FromPositionTo start end) = end

export
positionOffset : Position -> SourceOffset
positionOffset (AtPosition offset line column) = offset

export
positionLine : Position -> SourceLine
positionLine (AtPosition offset line column) = line

export
positionColumn : Position -> SourceColumn
positionColumn (AtPosition offset line column) = column

export
offsetNumber : SourceOffset -> Nat
offsetNumber (OffsetFromStart offset) = offset

export
lineNumber : SourceLine -> Nat
lineNumber (AfterLines preceding) = S preceding

export
columnNumber : SourceColumn -> Nat
columnNumber (AfterColumns preceding) = S preceding

public export
Eq SourceOffset where
  (OffsetFromStart a) == (OffsetFromStart b) = a == b

public export
Eq SourceLine where
  (AfterLines a) == (AfterLines b) = a == b

public export
Eq SourceColumn where
  (AfterColumns a) == (AfterColumns b) = a == b

public export
Eq Position where
  (AtPosition ao al ac) == (AtPosition bo bl bc) =
    ao == bo && al == bl && ac == bc

public export
Eq Span where
  (FromPositionTo as ae) == (FromPositionTo bs be) = as == bs && ae == be

public export
Show SourceOffset where
  show = show . offsetNumber

public export
Show SourceLine where
  show = show . lineNumber

public export
Show SourceColumn where
  show = show . columnNumber

public export
Show Position where
  show position =
    show (lineNumber (positionLine position)) ++ ":" ++
    show (columnNumber (positionColumn position))

public export
Show Span where
  show span = show (spanStart span) ++ "-" ++ show (spanEnd span)
