module [Key, keyToStr, keyToSlugStr]

import Utils

Key : [
    Action [Space],
    Symbol Symbol,
    Number Number,
    Upper Letter,
    Lower Letter,
    None,
]

Symbol : [
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
]
Number : [N0, N1, N2, N3, N4, N5, N6, N7, N8, N9]
Letter : [A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z]

symbolToStr : Symbol -> Str
symbolToStr = \symbol ->
    when symbol is
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

numberToStr : Number -> Str
numberToStr = \number ->
    when number is
        N0 -> "0"
        N1 -> "1"
        N2 -> "2"
        N3 -> "3"
        N4 -> "4"
        N5 -> "5"
        N6 -> "6"
        N7 -> "7"
        N8 -> "8"
        N9 -> "9"

letterToStr : Letter -> Str
letterToStr = \letter ->
    when letter is
        A -> "A"
        B -> "B"
        C -> "C"
        D -> "D"
        E -> "E"
        F -> "F"
        G -> "G"
        H -> "H"
        I -> "I"
        J -> "J"
        K -> "K"
        L -> "L"
        M -> "M"
        N -> "N"
        O -> "O"
        P -> "P"
        Q -> "Q"
        R -> "R"
        S -> "S"
        T -> "T"
        U -> "U"
        V -> "V"
        W -> "W"
        X -> "X"
        Y -> "Y"
        Z -> "Z"

keyToStr : Key -> Str
keyToStr = \key ->
    when key is
        Action Space -> " "
        Symbol symbol ->
            symbol
            |> symbolToStr

        Number number ->
            number
            |> numberToStr

        Upper letter ->
            letter
            |> letterToStr

        Lower letter ->
            letter
            |> letterToStr
            |> Utils.strToLower

        None -> ""

keyToSlugStr : Key -> Str
keyToSlugStr = \key ->
    when key is
        Action Space -> "_"
        Symbol Hyphen -> "-"
        Symbol Underscore -> "_"
        Number number ->
            number
            |> numberToStr

        Lower letter ->
            letter
            |> letterToStr
            |> Utils.strToLower

        Upper letter ->
            letter
            |> letterToStr

        _ -> ""
