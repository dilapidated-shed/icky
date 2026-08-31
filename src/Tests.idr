module Tests

import Diagnostic
import Glyph
import Parse
import Scan
import Syntax
import Token
import System

private
fail : String -> IO ()
fail message = do
  putStrLn ("FAIL: " ++ message)
  exitFailure

private
pass : String -> IO ()
pass name = putStrLn ("ok: " ++ name)

private
assert : String -> Bool -> IO ()
assert name True = pass name
assert name False = fail name

private
assertParses : String -> String -> Program -> IO ()
assertParses name source expected =
  case parse source of
    Right actual => assert name (actual == expected)
    Left diagnostics => fail (name ++ " — parse failed: " ++ show diagnostics)

private
assertParsesWithWarning : String -> String -> Program -> IO ()
assertParsesWithWarning name source expected =
  case parseWithWarnings source of
    Right (MkParseResult actual (_ :: _)) => assert name (actual == expected)
    Right (MkParseResult actual []) => fail (name ++ " — expected a warning")
    Left diagnostics => fail (name ++ " — parse failed: " ++ show diagnostics)

private
assertFails : String -> String -> IO ()
assertFails name source =
  case parse source of
    Left _ => pass name
    Right program => fail (name ++ " — unexpectedly parsed: " ++ show program)

private
one : List Piece -> Program
one pieces = MkProgram [MkExpr pieces]

main : IO ()
main = do
  assertParses "name is a noun"
    "image"
    (one [NounPiece (NameNoun "image")])

  assertParses "natural is a noun"
    "42"
    (one [NounPiece (NaturalNoun 42)])

  assertParses "act-first prefix-shaped order is preserved"
    "⌖ image"
    (one [GlyphPiece Target, NounPiece (NameNoun "image")])

  assertParses "value-first pipeline-shaped order is preserved"
    "image · resize"
    (one [ NounPiece (NameNoun "image")
         , GlyphPiece MiddleDot
         , NounPiece (NameNoun "resize")
         ])

  assertParses "composition ring is preserved"
    "f ∘ g"
    (one [ NounPiece (NameNoun "f")
         , GlyphPiece Composition
         , NounPiece (NameNoun "g")
         ])

  assertParses "arrow directions are paired"
    "← → ⇐ ⇒ ↥ ↧ image"
    (one [ GlyphPiece LeftArrow
         , GlyphPiece RightArrow
         , GlyphPiece DoubleLeftArrow
         , GlyphPiece DoubleRightArrow
         , GlyphPiece UpArrow
         , GlyphPiece DownArrow
         , NounPiece (NameNoun "image")
         ])

  assertParsesWithWarning "ASCII fat arrow remains accepted"
    "result => next"
    (one [ NounPiece (NameNoun "result")
         , GlyphPiece DoubleRightArrow
         , NounPiece (NameNoun "next")
         ])

  assertParsesWithWarning "ASCII pipeline remains accepted"
    "image |> resize"
    (one [ NounPiece (NameNoun "image")
         , GlyphPiece MiddleDot
         , NounPiece (NameNoun "resize")
         ])

  assertParsesWithWarning "Magrittr pipeline remains accepted"
    "image %>% resize"
    (one [ NounPiece (NameNoun "image")
         , GlyphPiece MiddleDot
         , NounPiece (NameNoun "resize")
         ])

  assertParses "source order is preserved"
    "← ↥ image"
    (one [GlyphPiece LeftArrow, GlyphPiece UpArrow,
          NounPiece (NameNoun "image")])

  assertParses "all source glyphs are preserved"
    "← → ⇐ ⇒ = ⌖ ↥ ↧ · ∘ image"
    (one [ GlyphPiece LeftArrow
         , GlyphPiece RightArrow
         , GlyphPiece DoubleLeftArrow
         , GlyphPiece DoubleRightArrow
         , GlyphPiece Equals
         , GlyphPiece Target
         , GlyphPiece UpArrow
         , GlyphPiece DownArrow
         , GlyphPiece MiddleDot
         , GlyphPiece Composition
         , NounPiece (NameNoun "image")
         ])

  assertParses "comment runs to newline"
    "⌖ image ⍝ ignored\nother"
    (MkProgram [ MkExpr [GlyphPiece Target, NounPiece (NameNoun "image")]
               , MkExpr [NounPiece (NameNoun "other")]
               ])

  assertParses "group is syntax, not semantics"
    "⌖ (↥ image)"
    (one [ GlyphPiece Target
         , GroupPiece (MkExpr [GlyphPiece UpArrow,
                               NounPiece (NameNoun "image")])
         ])

  assertFails "glyph-only expression violates noun-last" "⌖"
  assertFails "trailing glyph violates noun-last" "image ⌖"
  assertFails "group must end in noun" "(image ⌖)"
  assertFails "unexpected character is lexical error" "@ image"
  assertFails "unmatched close parenthesis" "image)"
  assertFails "missing close parenthesis" "(⌖ image"
