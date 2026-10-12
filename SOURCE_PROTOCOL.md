# Source-preserving ICKY interface, version 3

Parent: [Flexible Pipes #71](https://github.com/isomorphisms/flexible-pipes/issues/71).
This is a producer prerequisite for an ICK consumer, not the completed consumer.

## Bound input and parser result

`SourceProtocol` exports the opaque `SourceLocatedResult`. Its constructor is
private. `parseSourceLocated` takes one source `String`, checks Unicode scalar
validity, invokes the maintained `parseLocatedWithWarnings` on that same
string, and binds the result to it. The serializer accepts this bound value;
it has no argument for an independently supplied source or AST.

`sourceLocatedText` and `sourceLocatedSyntax` expose the original string and
parser result. They cannot replace either component of the bound value.
The existing `parse`, `parseWithWarnings`, located AST and version-1 and version-2 protocols
remain unchanged. The new package module uses the same ordinary-Idris
compatibility stratum and canonical source-built Idriç compiler.

The executable adds `--identity-v3` and `--parse-v3 SOURCE_FILE`.
The existing v1/v2 entrypoints retain their original output. The v3 serializer also invokes the maintained v2 literal checks on the bound input.
Invalid syntax and file/protocol failures return nonzero. Successful syntax
still has ICKY's existing noun-last grammar and decimal-Nat interpretation.

## Record format

The first line is `ICKY-LOCATED`, version `3`, coordinate convention
`char-and-utf8-byte-offset`, separated by tabs. It is followed by:

| Record | Fields after the record name |
| --- | --- |
| `source` | character count, UTF-8 byte count, complete input encoded as lowercase UTF-8 hex |
| `ok` | top-level expression count |
| `error` | fatal diagnostic count; no successful AST records follow |
| `expr`, `group` | path, eight source coordinates |
| `name` | path, eight coordinates, validated name, written UTF-8 hex |
| `natural` | path, eight coordinates, ICKY decimal value, written UTF-8 hex |
| `glyph` | path, eight coordinates, canonical glyph, written UTF-8 hex |
| `warning` | eight coordinates, compatibility code, written UTF-8 hex |
| `fatal` | eight coordinates, fatal code, optional quoted unexpected character, written UTF-8 hex |

The eight coordinates are: starting character offset, starting line,
starting column, finishing character offset, finishing line, finishing column,
starting UTF-8 byte offset, finishing UTF-8 byte offset. Offsets start at zero;
lines/columns start at one; both intervals exclude their finishing position.
The serializer checks interval bounds and recomputes positions against the
bound input before slicing. A mismatch returns `InconsistentSourceSpan` and
the driver emits no success stream.

Group and nested-expression paths follow v1's convention. Their distinct
record types distinguish the full parenthesis interval from its inner content.
Warnings retain their actual ASCII/Magrittr spelling. Tabs, CRLF, comments,
two/three/four-byte Unicode and leading zeroes remain present in the source
frame, even if they do not appear as successful syntax nodes. Empty input has
zero counts and an empty final source-hex field.

For `x ← 010`, the frame contains 7 characters and 9 UTF-8 bytes. The arrow's
character interval is `[2,3)` and its byte interval is `[2,5)`. The numeral's
intervals are `[4,7)` and `[6,9)`; its decimal value is 10 and its written bytes
are `303130`. A written `10` has hex `3130`, so it cannot be mistaken for that
same input. This preserves information; it does not assign C octal semantics.

`io-error` and `protocol-error` are refusal records after the header. A
consumer must check process exit, the complete stream and exact expected
schema; a header or partial output cannot mean success.

## Identity and preprocessing boundary

The source frame is the canonical UTF-8 encoding of the exact **parsed
String**, not a digest declared by a caller and not evidence about an
unobserved file. A compiler consumer must compare the complete decoded frame
with its own immutable byte buffer before interpreting any node. Lengths,
intervals and written slices must match that buffer. Different whitespace,
comments, numeral spellings, aliases, invalid-UTF-8 replacement or newline
normalization must reject when the compiler expected different bytes.

The current file reader is the inherited `System.File.readFile`. This change
does not independently prove its handling of every malformed UTF-8 file.
Whole-frame comparison in the consumer is therefore mandatory. A source
path, claimed hash or equal decimal values cannot substitute for byte equality.

This producer has no preprocessing expansion map. The eventual ICK consumer
must explicitly declare whether its input is raw source or a preprocessed
stream, retain its own original-token/expansion identities and translate
coordinates through that map. These byte offsets belong only to the provided
String. They must not be attributed to an original macro spelling without a
verified map.

The producer does not parse C declarations, semicolons, strings, C integer
suffixes or general C expressions. Unsupported syntax rejects. A C consumer
must interpret written literal tokens under its admitted C semantics; trusting
`NaturalNoun 10` for written C `010` would still be incorrect. No ASCII rewrite,
second handwritten parser or stock-parser fallback is introduced here.

## Qualification

The existing canonical Idriç workflow builds the new library module and
driver. Twelve additional assertions bind source/result identity and check
exact records for numerals, Unicode byte offsets, aliases, ignored comments,
CRLF, nested groups, empty input, malformed input and a neighboring arrow.
The distinct AICI consumer requires the new source-fidelity assertions and four actual v3 CLI assertions along
with the original v1/v2 parser/type/protocol receipts.

Source edits start as NOT_RUN until the fresh exact-head hosted result is
inspected. The test executable uses the pinned Idriç `System.File.Process.Escaped.popen`
interface with a fixed argument list to invoke the newly built parser's v3
identity, positive, malformed-input and missing-input modes. This is actual
producer CLI execution; it does not establish an ICK compiler consumer. An actual ICK-produced object/execution,
source-map validation, wrong-parser/bypass rejection, four-ABI consumer
qualification and Flexible Pipes delivery/current-base admission remain open.
