# Stricter type boundary

This proposal records the intended boundary before the implementation changes.
It describes distinctions ICKY already enforces; it does not add syntax or give
surface forms ICK or Idriç semantics.

## Validated source names

`Name` is an opaque source identifier. `nameFromString` is its only public
constructor and accepts exactly the scanner's current language:
`[A-Za-z_][A-Za-z0-9_]*`. `nameText` exposes the original text for display and
downstream use. `TName` and `NameNoun` carry `Name`, not `String`.

This deliberately does not broaden ICKY into Unicode identifier
classification. Arbitrary source input and extracted source text remain
`String` and `Char` values until validation succeeds.

## Decimal recognition

`DecimalDigit` is a closed ten-constructor type. Recognition has the truthful
boundary:

    decimalDigit : Char -> Maybe DecimalDigit

A `DecimalNumeral` contains a first digit and a list of remaining digits, so it
cannot be empty and cannot contain a non-decimal character. Conversion to the
numeric value accepts only `DecimalNumeral`. Tokens and nouns retain `Nat` as
their value representation because every natural number is representable by a
decimal literal and ICKY does not currently preserve numeral spelling or
leading zeroes.

## Source coordinates

`SourceOffset`, `SourceLine`, and `SourceColumn` are distinct types. Their raw
representations cannot be interchanged. The scanner's existing conventions are
preserved:

- offsets are zero-based counts of Idris `Char` values;
- lines and columns are one-based;
- a span starts at the covered text and ends immediately after it;
- newline advances the offset and line, then resets the column to one.

The positive line and column convention is represented by storing the number
of preceding lines or columns behind opaque constructors. Span ordering is not
given a proof: doing so would add machinery without excluding a state produced
by ICKY's scanner.

## Structured diagnostics

Diagnostics are indexed by a closed severity:

    Severity = Fatal | Warning
    Diagnostic : Severity -> Type

Fatal kinds cover an unexpected character, an unexpected close parenthesis, a
missing close parenthesis, and the noun-last violation. The warning kind carries
a closed compatibility spelling (`=>`, `|>`, or `%>%`). Scanner/parser failure
lists therefore cannot contain warnings, and `ParseResult.warnings` cannot
contain fatal errors. Rendering those cases into a message remains a separate
function returning `String`.

## Parser context

Sequence parsing uses `TopLevel` or `InsideGroup`, rather than a boolean whose
meaning depends on the caller remembering the convention.

## Successful expressions

A successful `Expr` has a list of pieces before its final piece, plus a final
piece whose type permits only a noun or an already-valid group:

    Expr = leading pieces + FinalNoun noun | FinalGroup expression

This makes every `Expr` nonempty and noun-ending by construction while retaining
source order and glyph identity. `exprFromPieces` is the checked bridge from an
ordinary list. The parser may use a private, unchecked candidate form while
recovering and collecting diagnostics, but that form is not part of the public
successful tree. Candidate recovery tracks noun-ending shape separately from
whether a complete valid `Expr` can be built, so an invalid earlier subgroup
does not cause a spurious noun-last error on an otherwise noun-ending outer
group. `Program` remains a possibly-empty list because empty source already
parses successfully.

No type in this boundary assigns application direction, glyph meaning, arity,
precedence, normalization, or any other ICK/Idriç semantic rule.

## Deliberately unencoded invariants

`Program` remains possibly empty because empty source is accepted. Natural
values remain `Nat` because every inhabitant has a decimal spelling. Spans do
not carry an ordering proof, and token lists do not carry a proof that the EOF
sentinel occurs exactly once at the end. Encoding either proof would add a
second indexed sequence API without changing any successful syntax ICKY
returns; the scanner and parser keep those checks procedural for now. Numeric
leading zeroes also remain unpreserved, matching the existing tree rather than
quietly changing the language's source-preservation contract.
