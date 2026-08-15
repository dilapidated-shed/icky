# icky

parser for ick (y-y-yacc replacement, hence the y)

ICKY turns source text into a small, semantic-neutral syntax tree. It recognizes
names, natural numbers, grouping, line comments, and the source glyphs:

    ←  =  ⌖  ↥  ·

`⍝` starts a comment that runs to the end of the line.

The public boundary ICK needs is:

    parse : String -> Either (List Diagnostic) Program

ICKY preserves glyph identity and source order. It does not decide what a glyph
means and it does not assign precedence. That belongs downstream in ICK.

For now an expression must end in a noun. Parenthesized groups obey the same
rule. Newlines separate top-level expressions.

Build:

    idris2 --build icky.ipkg

Tests:

    idris2 --build tests.ipkg
    ./build/exec/icky-tests
