# ICKY source-preserving compiler interface

Parent: Flexible Pipes issue #71. Continue the retained `stricter-types`
branch; the compatibility parser and its semantics remain unchanged.

## Type sketch written before implementation

- Input: the exact Unicode `String` passed to ICKY, with all comments,
  whitespace, compatibility spellings and leading zeroes retained.
- Output: opaque `SourceLocatedResult`, containing that same input and the
  result of the maintained `parseLocatedWithWarnings` on that input.
- `parseSourceLocated : String -> Either SourceProtocolFailure SourceLocatedResult`.
- `sourceLocatedText : SourceLocatedResult -> String` and
  `sourceLocatedSyntax : SourceLocatedResult -> Either (List FatalDiagnostic) LocatedParseResult`.
- `renderSourceLocated : SourceLocatedResult -> Either SourceProtocolFailure String`.
- The private constructor prevents pairing an AST with a different input.
  Serialization verifies each character span, line/column and UTF-8 byte
  interval against the bound input. Source identity is the entire canonical
  UTF-8 byte sequence, not a producer-declared digest.
- Effects belong only to the existing executable driver: read a supplied
  file, parse, print a deterministic record stream, return nonzero on refusal.
- The pure library owns UTF-8 encoding of Unicode scalar values. It rejects
  invalid scalar input and inconsistent spans; it does not own preprocessing,
  C integer interpretation, target types, ABI or code generation.

## Implementation and evidence boundary

The implementation extends the maintained ordinary-Idris compatibility
stratum in `src/SourceProtocol.idr`; `SourceFidelity.idric` preserves a small
downstream-use example. The package builds and test executable use the
canonical pinned Idriç entrypoint from the existing workflow. No Python,
Node, stock Idris, generated C, or handwritten language-parser fallback.

This draft starts with NOT_RUN status. Hosted exact-head compiler evidence
must be inspected before claiming the implementation executes. Existing
protocol v1 and decimal-Nat semantics remain unchanged. Protocol v3 preserves
`010` as written bytes while recording the ICKY decimal value 10; a C consumer
must use the written token under C rules, rather than trust the decimal value.

## Remaining language and compiler work

The first remaining integration capability is an actual ICK consumer that
binds this frame to its own raw or preprocessed source buffer and expansion
map, then feeds admitted syntax to GCC's typed semantic operations. A
positive compiler-output fixture and negative wrong-input, wrong-parser,
malformed-input and neighboring-glyph controls must prove that interface.
No consumer, general C grammar, independent delivery admission, or device
acceptance is claimed by the source-preserving producer alone.

Concurrent retained-branch work introduced v2 numeral spelling at
`ab2e353ff4f6474fe8ec53bb716298c29925917f` before this change was published.
This attempt was reconciled on that head: it preserves and reuses v2's literal
checks, keeps its tests and CLI modes, and reserves version 3 for the additional
whole-input/byte-span interface. No competing parser is added. Actual v3 CLI
controls use the pinned Idriç process interface with escaped argument lists;
the hosted check must pass on the combined head.
