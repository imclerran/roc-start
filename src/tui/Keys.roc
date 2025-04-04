module [Key, key_to_str, key_to_slug_str]

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

symbol_to_str : Symbol -> Str
symbol_to_str = |symbol|
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

number_to_str : Number -> Str
number_to_str = |number|
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

letter_to_str : Letter -> Str
letter_to_str = |letter|
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

key_to_str : Key -> Str
key_to_str = |key|
    when key is
        Action(Space) -> " "
        Symbol(symbol) ->
            symbol
            |> symbol_to_str

        Number(number) ->
            number
            |> number_to_str

        Upper(letter) ->
            letter
            |> letter_to_str

        Lower(letter) ->
            letter
            |> letter_to_str
            |> Utils.str_to_lower

        None -> ""

key_to_slug_str : Key -> Str
key_to_slug_str = |key|
    when key is
        Action(Space) -> "_"
        Symbol(Hyphen) -> "-"
        Symbol(Underscore) -> "_"
        Number(number) ->
            number
            |> number_to_str

        Lower(letter) ->
            letter
            |> letter_to_str
            |> Utils.str_to_lower

        Upper(letter) ->
            letter
            |> letter_to_str

        _ -> ""
