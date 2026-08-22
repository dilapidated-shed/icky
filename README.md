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

ICKY preserves the written position of every piece. This leaves room for
downstream ICK and Idriç to define at least two application directions: one
natural act-first prefix form and one value-first form in which the next act is
written after its input. R's Magrittr pipeline (`value %>% act`) is the concrete
precedent for the latter; `%>%` is not yet ICKY syntax.

ICKY does not infer subject and object roles, choose an application form, or
promise that every S/V/O permutation has a meaning. Application declarations,
arity, precedence, and normalization belong downstream in ICK. For now an
expression must end in a noun. Parenthesized groups obey the same rule. Newlines
separate top-level expressions.

Build:

    idris2 --build icky.ipkg

Tests:

    idris2 --build tests.ipkg
    ./build/exec/icky-tests
