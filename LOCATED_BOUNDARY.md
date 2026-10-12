# Located ICKY source-tree contract

This is an opt-in extension of the retained typed-parser branch. It preserves
the existing `parse` and `parseWithWarnings` APIs and does **not** claim
that GCC's C parser, preprocessing or `gengtype` has been replaced.

## Interfaces

```idris
parseLocated : String -> Either (List FatalDiagnostic) LocatedProgram
parseLocatedWithWarnings : String -> Either (List FatalDiagnostic) LocatedParseResult
eraseLocatedProgram : LocatedProgram -> Program
```

`LocatedExpr` is nonempty and noun-ending by construction. It carries a span
from its first to last written source piece. Each `LocatedNoun`,
`LocatedGlyph` or `LocatedGroup` carries its own scanner-derived span.
A group span includes both parentheses; its nested `LocatedExpr` span covers
only the contents. `LocatedFinalNoun` and `LocatedFinalGroup` enforce the
same successful-expression shape as ordinary `Expr`.

`eraseLocatedProgram` drops location metadata and returns the established
`Syntax.Program`. The accepted source-order, glyph identity, warnings and
fatal diagnostics are unchanged. A successful erasure must equal the existing
`parse source` result; rejected forms must produce exactly the same fatal
diagnostics on both APIs. The executable fixture in `src/Tests.idr` checks
these properties for nested groups, Unicode glyphs, ASCII compatibility
spellings, malformed syntax and C operators that are **not** aliases.

## Coordinate and origin model

Source offsets count Idris `Char` values from zero, not UTF-8 bytes. Source
lines/columns are one-based and spans are half-open. All spans belong to the
**exact source string given to ICKY**. The parser does not currently retain a
file path, an input digest, a macro expansion map, a preprocessor token
identity, or a byte-offset table in the v1 AST.

The separate [source-preserving v3 interface](SOURCE_PROTOCOL.md) provides
an opaque input/result pairing, complete canonical UTF-8 source bytes,
written numeral/glyph/name slices and checked byte intervals. It does not
change the located AST or supply a macro expansion map.

An ICK GCC consumer must therefore distinguish raw input positions from
positions in its preprocessed C stream. It must not treat a three-byte UTF-8
`←` as a one-byte source offset. Macro expansion/source-map conversion,
the actual ICK consumer and verified compiler/executable identity remain K2
work. Versioned producer protocols alone do not integrate the compiler.
Nothing here permits a hidden handwritten C fallback if an ICKY-admitted
path rejects the input.

## Ownership and acceptance

The ICKY implementation lives on the original `stricter-types` branch,
preserved by [ICKY PR #4](https://github.com/dilapidated-shed/icky/pull/4).
Do not fork the superseded Unicode branch or treat this as a full C grammar.

[Flexible Pipes SUN K1 #71](https://github.com/isomorphisms/flexible-pipes/issues/71)
remains the non-bypassable job and delivery boundary; AICI requires actual
tests and an exact toolchain receipt before accepting this source change.
The [ICK bootstrap correction PR #89](https://github.com/dilapidated-shed/ick/pull/89)
separately isolates Bison/Yacc and retains Flex for GCC's `gengtype`. Those
two projects are not equivalent just because both contain parsers.

## Exact-head execution qualification

The fail-closed `tests/qualify-located.sh` runner expects `IDRIC` to be an
absolute path to the chosen Idriç executable and `IDRIC_SOURCE_SHA` to name
its exact source revision. It refuses dirty tracked ICKY source or missing
compiler/toolchain metadata. It builds the library, tests and parser through
that executable, runs the original tests, negative type-boundary checks and
the `icky-parser` identity/parse/failure protocol tests.

The runner stores input source SHA, **declared** Idriç source revision, actual
compiler executable path/hash/version, produced binary hashes and complete
test logs under `build/qualification/located-<ICKY_SOURCE_SHA>/`; it refuses
to overwrite a previous receipt. Its `LOCAL_PASS` means only that these
programs executed under the specified local compiler. The compiler source
revision remains declared until independently bound to the executable; AICI
must independently check identities and execution traces before delivering
or merging anything.

The original runner/library/v1 executable qualification passed at source
`ec5981c1256bf20f10306d49864f2e7c75e1d755` in
[run 38138151255](https://github.com/dilapidated-shed/icky/actions/runs/38138151255),
including the independent AICI receipt consumer. Every later source edit,
including the v3 prerequisite, requires a fresh exact-head verdict.

## Source spelling and the opt-in v2 protocol

The original `--parse` and `ICKY-LOCATED\t1\tchar-offset` protocol continue
to emit the existing canonical `natural` value. That interface still does not
distinguish a source numeral `010` from `10`.

The additive `--identity-v2` and `--parse-v2 SOURCE_FILE` modes use
`ICKY-LOCATED\t2\tchar-offset`. They serialize the **same ICKY AST**, with
extra `spelling` rows identifying the AST path, its six character-coordinate
fields, and the original decimal text. The parser takes that text from its
actual input string at the located span and verifies it against ICKY's typed
`DecimalNumeral` recognizer and numeric value before returning success.
A mismatch is a nonzero failure, never a fabricated `ok` record.

For example, `← 010` produces a natural value of `10`, plus a `spelling`
record containing `010`. A C consumer must use that preserved spelling when
deciding whether a literal means decimal or octal, or explicitly reject it.
A `Nat` value alone is never evidence for C integer-literal semantics.

**Not yet supplied by v2:** immutable original input-byte SHA-256, UTF-8
byte-to-character conversion, GCC preprocessor source maps, general C syntax,
or actual GCC ICK frontend consumption. Those are separate mandatory
consumer admission conditions in Flexible Pipes SUN K1 #71. The v2 producer
alone cannot authorize a C frontend or a merge. Each changed source head
requires an exact Idriç parser run and a separate AICI receipt verdict.

The additive v3 source frame and checked UTF-8 intervals are described in
[SOURCE_PROTOCOL.md](SOURCE_PROTOCOL.md). They use the same parser and v2
literal checks with an opaque source/result pairing. V1/v2 output stays
unchanged; an actual ICK consumer and preprocessing map are still missing.
