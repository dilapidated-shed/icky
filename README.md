# icky

parser for ick (y-y-yacc replacement, hence the y)

ICKY turns source text into a small, semantic-neutral syntax tree. It recognizes
names, natural numbers, grouping, line comments, and the source glyphs:

    ←  →  ⇐  ⇒  =  ⌖  ↥  ↧  ·  ∘

`⍝` starts a comment that runs to the end of the line.

The public compatibility boundary remains:

    parse : String -> Either (List FatalDiagnostic) Program

Callers that want nonfatal surface-style warnings can use:

    parseWithWarnings : String -> Either (List FatalDiagnostic) ParseResult

where `ParseResult` contains the parsed `Program` and a list of
`WarningDiagnostic` values. Fatal diagnostics and warnings have structured,
closed cases and cannot be mixed; rendering them to `String` happens only at the
display boundary.

ICKY preserves glyph identity and source order. It does not decide what a glyph
means and it does not assign precedence. That belongs downstream in ICK.

## Permissive surface syntax

ICKY is not a style gate. Older keyboard-oriented spellings remain readable when
they have a safe, unambiguous ICKY alias. The parser keeps going and reports a
warning suggesting the preferred source glyph:

    =>    ⇒
    |>    ·
    %>%   ·

The preferred spelling is Unicode; the ASCII or Magrittr spelling is not an
error. `parse` deliberately remains source-compatible and discards these style
warnings, while `parseWithWarnings` exposes them.

Aliases are token-aware rather than global text substitutions. In particular,
ICKY does not repurpose existing C operators such as `->`, `<=`, `>=`, `<<`, or
`>>` as arrow aliases. That distinction is necessary for the planned ability to
read older C-family source without changing what that source says.

## Direction and composition

Directional glyphs are introduced in explicit reverse pairs:

    ←  →
    ⇐  ⇒
    ↥  ↧

`reverseGlyph` records those pairings without assigning operational semantics.

ICKY also preserves both the composition ring `∘` and the value-first pipeline
glyph `·`. This allows downstream ICK and Idriç to define pre-composition,
post-composition, act-first application, and value-first/Magrittr-like flow
without teaching ICKY what those expressions mean.

ICKY does not infer subject and object roles, choose an application form, or
promise that every S/V/O permutation has a meaning. Application declarations,
arity, precedence, and normalization belong downstream in ICK. For now an
expression must end in a noun. Parenthesized groups obey the same rule. Newlines
separate top-level expressions.

## Type boundary

Scanner-validated names have the opaque `Name` type. Decimal recognition uses a
closed `DecimalDigit` type and a nonempty `DecimalNumeral` before producing a
natural-number value. Offsets, lines, and columns are distinct source-coordinate
types.

Successful expressions are nonempty and noun-ending by construction: an `Expr`
contains its leading pieces and a final piece that can only be a noun or an
already-valid parenthesized expression. `exprFromPieces` is the checked bridge
from an ordinary list. See [TYPE_BOUNDARY.md](TYPE_BOUNDARY.md) for the exact
boundary and the invariants deliberately left out.

Build:

    idris2 --build icky.ipkg

Tests:

    idris2 --build tests.ipkg
    ./build/exec/icky-tests
    IDRIS2=idris2 ./tests/check-type-boundaries.sh

The final command verifies that direct construction across the opaque-name,
decimal-digit, coordinate, diagnostic-severity, and successful-expression
boundaries is rejected by the compiler for the intended reason.
