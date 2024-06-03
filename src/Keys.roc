module [Key, keyToStr, keyToSlugStr]

Key : [
    Up,
    Down,
    Left,
    Right,
    Escape,
    Enter,
    LowerA,
    UpperA,
    UpperB,
    LowerB,
    UpperC,
    LowerC,
    UpperD,
    LowerD,
    UpperE,
    LowerE,
    UpperF,
    LowerF,
    UpperG,
    LowerG,
    UpperH,
    LowerH,
    UpperI,
    LowerI,
    UpperJ,
    LowerJ,
    UpperK,
    LowerK,
    UpperL,
    LowerL,
    UpperM,
    LowerM,
    UpperN,
    LowerN,
    UpperO,
    LowerO,
    UpperP,
    LowerP,
    UpperQ,
    LowerQ,
    UpperR,
    LowerR,
    UpperS,
    LowerS,
    UpperT,
    LowerT,
    UpperU,
    LowerU,
    UpperV,
    LowerV,
    UpperW,
    LowerW,
    UpperX,
    LowerX,
    UpperY,
    LowerY,
    UpperZ,
    LowerZ,
    Space,
    ExclamationMark,
    QuotationMark,
    NumberSign,
    DollarSign,
    PercentSign,
    Ampersand,
    Apostrophe,
    RoundOpenBracket,
    RoundCloseBracket,
    Asterisk,
    PlusSign,
    Comma,
    Hyphen,
    FullStop,
    ForwardSlash,
    Colon,
    SemiColon,
    LessThanSign,
    EqualsSign,
    GreaterThanSign,
    QuestionMark,
    AtSign,
    SquareOpenBracket,
    Backslash,
    SquareCloseBracket,
    Caret,
    Underscore,
    GraveAccent,
    CurlyOpenBrace,
    VerticalBar,
    CurlyCloseBrace,
    Tilde,
    Number0,
    Number1,
    Number2,
    Number3,
    Number4,
    Number5,
    Number6,
    Number7,
    Number8,
    Number9,
    Delete,
]

keyToStr : Key -> Str
keyToStr = \key ->
    when key is
        LowerA -> "a"
        UpperA -> "A"
        LowerB -> "b"
        UpperB -> "B"
        LowerC -> "c"
        UpperC -> "C"
        LowerD -> "d"
        UpperD -> "D"
        LowerE -> "e"
        UpperE -> "E"
        LowerF -> "f"
        UpperF -> "F"
        LowerG -> "g"
        UpperG -> "G"
        LowerH -> "h"
        UpperH -> "H"
        LowerI -> "i"
        UpperI -> "I"
        LowerJ -> "j"
        UpperJ -> "J"
        LowerK -> "k"
        UpperK -> "K"
        LowerL -> "l"
        UpperL -> "L"
        LowerM -> "m"
        UpperM -> "M"
        LowerN -> "n"
        UpperN -> "N"
        LowerO -> "o"
        UpperO -> "O"
        LowerP -> "p"
        UpperP -> "P"
        LowerQ -> "q"
        UpperQ -> "Q"
        LowerR -> "r"
        UpperR -> "R"
        LowerS -> "s"
        UpperS -> "S"
        LowerT -> "t"
        UpperT -> "T"
        LowerU -> "u"
        UpperU -> "U"
        LowerV -> "v"
        UpperV -> "V"
        LowerW -> "w"
        UpperW -> "W"
        LowerX -> "x"
        UpperX -> "X"
        LowerY -> "y"
        UpperY -> "Y"
        LowerZ -> "z"
        UpperZ -> "Z"
        Space -> " "
        ExclamationMark -> "!"
        QuotationMark -> "\""
        NumberSign -> "#"
        DollarSign -> "$"
        PercentSign -> "%"
        Ampersand -> "&"
        Apostrophe -> "'"
        RoundOpenBracket -> "("
        RoundCloseBracket -> ")"
        Asterisk -> "*"
        PlusSign -> "+"
        Comma -> ","
        Hyphen -> "-"
        FullStop -> "."
        ForwardSlash -> "/"
        Colon -> ":"
        SemiColon -> ";"
        LessThanSign -> "<"
        EqualsSign -> "="
        GreaterThanSign -> ">"
        QuestionMark -> "?"
        AtSign -> "@"
        SquareOpenBracket -> "["
        Backslash -> "\\"
        SquareCloseBracket -> "]"
        Caret -> "^"
        Underscore -> "_"
        GraveAccent -> "`"
        CurlyOpenBrace -> "{"
        VerticalBar -> "|"
        CurlyCloseBrace -> "}"
        Tilde -> "~"
        Number0 -> "0"
        Number1 -> "1"
        Number2 -> "2"
        Number3 -> "3"
        Number4 -> "4"
        Number5 -> "5"
        Number6 -> "6"
        Number7 -> "7"
        Number8 -> "8"
        Number9 -> "9"
        _ -> ""

keyToSlugStr : Key -> Str
keyToSlugStr = \key ->
    when key is
        LowerA -> "a"
        UpperA -> "A"
        LowerB -> "b"
        UpperB -> "B"
        LowerC -> "c"
        UpperC -> "C"
        LowerD -> "d"
        UpperD -> "D"
        LowerE -> "e"
        UpperE -> "E"
        LowerF -> "f"
        UpperF -> "F"
        LowerG -> "g"
        UpperG -> "G"
        LowerH -> "h"
        UpperH -> "H"
        LowerI -> "i"
        UpperI -> "I"
        LowerJ -> "j"
        UpperJ -> "J"
        LowerK -> "k"
        UpperK -> "K"
        LowerL -> "l"
        UpperL -> "L"
        LowerM -> "m"
        UpperM -> "M"
        LowerN -> "n"
        UpperN -> "N"
        LowerO -> "o"
        UpperO -> "O"
        LowerP -> "p"
        UpperP -> "P"
        LowerQ -> "q"
        UpperQ -> "Q"
        LowerR -> "r"
        UpperR -> "R"
        LowerS -> "s"
        UpperS -> "S"
        LowerT -> "t"
        UpperT -> "T"
        LowerU -> "u"
        UpperU -> "U"
        LowerV -> "v"
        UpperV -> "V"
        LowerW -> "w"
        UpperW -> "W"
        LowerX -> "x"
        UpperX -> "X"
        LowerY -> "y"
        UpperY -> "Y"
        LowerZ -> "z"
        UpperZ -> "Z"
        Space -> "_"
        Hyphen -> "-"
        Underscore -> "_"
        Number0 -> "0"
        Number1 -> "1"
        Number2 -> "2"
        Number3 -> "3"
        Number4 -> "4"
        Number5 -> "5"
        Number6 -> "6"
        Number7 -> "7"
        Number8 -> "8"
        Number9 -> "9"
        _ -> ""
