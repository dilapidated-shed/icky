module Decimal

%default total

public export
data DecimalDigit
  = ZeroDigit
  | OneDigit
  | TwoDigit
  | ThreeDigit
  | FourDigit
  | FiveDigit
  | SixDigit
  | SevenDigit
  | EightDigit
  | NineDigit

public export
decimalDigit : Char -> Maybe DecimalDigit
decimalDigit '0' = Just ZeroDigit
decimalDigit '1' = Just OneDigit
decimalDigit '2' = Just TwoDigit
decimalDigit '3' = Just ThreeDigit
decimalDigit '4' = Just FourDigit
decimalDigit '5' = Just FiveDigit
decimalDigit '6' = Just SixDigit
decimalDigit '7' = Just SevenDigit
decimalDigit '8' = Just EightDigit
decimalDigit '9' = Just NineDigit
decimalDigit _ = Nothing

public export
digitValue : DecimalDigit -> Nat
digitValue ZeroDigit = 0
digitValue OneDigit = 1
digitValue TwoDigit = 2
digitValue ThreeDigit = 3
digitValue FourDigit = 4
digitValue FiveDigit = 5
digitValue SixDigit = 6
digitValue SevenDigit = 7
digitValue EightDigit = 8
digitValue NineDigit = 9

public export
digitChar : DecimalDigit -> Char
digitChar ZeroDigit = '0'
digitChar OneDigit = '1'
digitChar TwoDigit = '2'
digitChar ThreeDigit = '3'
digitChar FourDigit = '4'
digitChar FiveDigit = '5'
digitChar SixDigit = '6'
digitChar SevenDigit = '7'
digitChar EightDigit = '8'
digitChar NineDigit = '9'

public export
record DecimalNumeral where
  constructor MkDecimalNumeral
  firstDigit : DecimalDigit
  remainingDigits : List DecimalDigit

public export
decimalValue : DecimalNumeral -> Nat
decimalValue (MkDecimalNumeral first rest) =
  foldl (\value, digit => value * 10 + digitValue digit)
        (digitValue first) rest

public export
decimalText : DecimalNumeral -> String
decimalText (MkDecimalNumeral first rest) =
  pack (digitChar first :: map digitChar rest)

private
takeDecimalTail : List Char -> (List DecimalDigit, List Char)
takeDecimalTail [] = ([], [])
takeDecimalTail input@(c :: cs) =
  case decimalDigit c of
    Just digit =>
      let (taken, rest) = takeDecimalTail cs in (digit :: taken, rest)
    Nothing => ([], input)

public export
takeDecimalPrefix : List Char -> Maybe (DecimalNumeral, List Char)
takeDecimalPrefix [] = Nothing
takeDecimalPrefix (c :: cs) =
  case decimalDigit c of
    Just first =>
      let (restDigits, restInput) = takeDecimalTail cs
       in Just (MkDecimalNumeral first restDigits, restInput)
    Nothing => Nothing

public export
Eq DecimalDigit where
  ZeroDigit == ZeroDigit = True
  OneDigit == OneDigit = True
  TwoDigit == TwoDigit = True
  ThreeDigit == ThreeDigit = True
  FourDigit == FourDigit = True
  FiveDigit == FiveDigit = True
  SixDigit == SixDigit = True
  SevenDigit == SevenDigit = True
  EightDigit == EightDigit = True
  NineDigit == NineDigit = True
  _ == _ = False

public export
Eq DecimalNumeral where
  (MkDecimalNumeral af ar) == (MkDecimalNumeral bf br) = af == bf && ar == br

public export
Show DecimalDigit where
  show digit = pack [digitChar digit]

public export
Show DecimalNumeral where
  show = decimalText
