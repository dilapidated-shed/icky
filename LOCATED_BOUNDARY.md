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
identity, or a byte-offset table.

An ICK GCC consumer must therefore distinguish raw input positions from
positions in its preprocessed C stream. It must not treat a three-byte UTF-8
`←` as a one-byte source offset. Macro expansion/source-map conversion,
an explicit versioned executable protocol, pinning the ICKY compiler and
toolchain, and verifying the exact parser executable are still separate K2
work. Nothing here permits a hidden handwritten C fallback if an ICKY-admitted
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

As of this source change, the qualification runner itself has **NOT_RUN**
status: the current environment lacks a qualified Idriç compiler executable.
