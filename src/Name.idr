module Name

%default total

export
data Name = ValidName String

private
isAsciiLetter : Char -> Bool
isAsciiLetter c = elem c (unpack "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")

private
isNameStart : Char -> Bool
isNameStart c = isAsciiLetter c || c == '_'

private
isNameTail : Char -> Bool
isNameTail c = isNameStart c || elem c (unpack "0123456789")

private
takeNameTail : List Char -> (List Char, List Char)
takeNameTail [] = ([], [])
takeNameTail input@(c :: cs) =
  if isNameTail c
     then let (taken, rest) = takeNameTail cs in (c :: taken, rest)
     else ([], input)

export
takeNamePrefix : List Char -> Maybe (Name, List Char)
takeNamePrefix [] = Nothing
takeNamePrefix input@(c :: cs) =
  if isNameStart c
     then let (tail, rest) = takeNameTail cs
           in Just (ValidName (pack (c :: tail)), rest)
     else Nothing

export
nameFromString : String -> Maybe Name
nameFromString source =
  case takeNamePrefix (unpack source) of
    Just (name, []) => Just name
    _ => Nothing

export
nameText : Name -> String
nameText (ValidName text) = text

public export
Eq Name where
  (ValidName a) == (ValidName b) = a == b

public export
Show Name where
  show = nameText
