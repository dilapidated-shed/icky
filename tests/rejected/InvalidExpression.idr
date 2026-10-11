module InvalidExpression

import Glyph
import Syntax

badExpression : Expr
badExpression = MkExpr [GlyphPiece Target]
