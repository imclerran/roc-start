module [
    # ANSI
    Escape,
    Color,
    toStr,
    style,
    color,

    # TUI
    DrawFn,
    Pixel,
    ScreenSize,
    CursorPosition,
    Input,
    parseCursor,
    updateCursor,
    inputToStr,
    parseRawStdin,
    drawScreen,
    drawText,
    drawVLine,
    drawHLine,
    drawBox,
    drawCursor,
    symbolToStr,
    lowerToStr,
    upperToStr,
]

import Color
import Style exposing [Style]
import Control exposing [Control]

Color : Color.Color

## [Ansi Escape Codes](https://en.wikipedia.org/wiki/ANSI_escape_code)
Escape : [
    Reset,
    Control Control,
]

toStr : Escape -> Str
toStr = \escape -> "\u(001b)"
    |> Str.concat
        (
            when escape is
                Reset -> "c"
                Control control -> "[" |> Str.concat (Control.toCode control)
        )

## Add styles to a string
style : Str, List Style -> Str
style = \str, styles ->
    styles
    |> List.map Style
    |> List.map Control
    |> List.map toStr
    |> List.append str
    |> Str.joinWith ""

resetStyle = "" |> style [Default]

## Add color styles to a string and then resets to default
color : Str, { fg ? Color, bg ? Color } -> Str
color = \str, { fg ? Default, bg ? Default } -> str |> style [Foreground (fg), Background (bg)] |> Str.concat resetStyle

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

Ctrl : [Space, A, B, C, D, E, F, G, H, I, J, K, L, N, O, P, Q, R, S, T, U, V, W, X, Y, Z, BackSlash, SquareCloseBracket, Caret, Underscore]
Action : [Escape, Enter, Space, Delete]
Arrow : [Up, Down, Left, Right]
Number : [N0, N1, N2, N3, N4, N5, N6, N7, N8, N9]
Letter : [A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z]

Input : [
    Ctrl Ctrl,
    Action Action,
    Arrow Arrow,
    Symbol Symbol,
    Number Number,
    Upper Letter,
    Lower Letter,
    Unsupported (List U8),
]

parseRawStdin : List U8 -> Input
parseRawStdin = \bytes ->
    when bytes is
        [0, ..] -> Ctrl Space
        [1, ..] -> Ctrl A
        [2, ..] -> Ctrl B
        [3, ..] -> Ctrl C
        [4, ..] -> Ctrl D
        [5, ..] -> Ctrl E
        [6, ..] -> Ctrl F
        [7, ..] -> Ctrl G
        [8, ..] -> Ctrl H
        [9, ..] -> Ctrl I
        [10, ..] -> Ctrl J
        [11, ..] -> Ctrl K
        [12, ..] -> Ctrl L
        [13, ..] -> Action Enter
        # [13, ..] -> Ctrl M # Same as Action Enter
        [14, ..] -> Ctrl N
        [15, ..] -> Ctrl O
        [16, ..] -> Ctrl P
        [17, ..] -> Ctrl Q
        [18, ..] -> Ctrl R
        [19, ..] -> Ctrl S
        [20, ..] -> Ctrl T
        [21, ..] -> Ctrl U
        [22, ..] -> Ctrl V
        [23, ..] -> Ctrl W
        [24, ..] -> Ctrl X
        [25, ..] -> Ctrl Y
        [26, ..] -> Ctrl Z
        [27, 91, 'A', ..] -> Arrow Up
        [27, 91, 'B', ..] -> Arrow Down
        [27, 91, 'C', ..] -> Arrow Right
        [27, 91, 'D', ..] -> Arrow Left
        [27, ..] -> Action Escape
        # [27, ..] -> Ctrl SquareOpenBracket # Same as Action Escape
        [28, ..] -> Ctrl BackSlash
        [29, ..] -> Ctrl SquareCloseBracket
        [30, ..] -> Ctrl Caret
        [31, ..] -> Ctrl Underscore
        [32, ..] -> Action Space
        ['!', ..] -> Symbol ExclamationMark
        ['"', ..] -> Symbol QuotationMark
        ['#', ..] -> Symbol NumberSign
        ['$', ..] -> Symbol DollarSign
        ['%', ..] -> Symbol PercentSign
        ['&', ..] -> Symbol Ampersand
        ['\'', ..] -> Symbol Apostrophe
        ['(', ..] -> Symbol RoundOpenBracket
        [')', ..] -> Symbol RoundCloseBracket
        ['*', ..] -> Symbol Asterisk
        ['+', ..] -> Symbol PlusSign
        [',', ..] -> Symbol Comma
        ['-', ..] -> Symbol Hyphen
        ['.', ..] -> Symbol FullStop
        ['/', ..] -> Symbol ForwardSlash
        ['0', ..] -> Number N0
        ['1', ..] -> Number N1
        ['2', ..] -> Number N2
        ['3', ..] -> Number N3
        ['4', ..] -> Number N4
        ['5', ..] -> Number N5
        ['6', ..] -> Number N6
        ['7', ..] -> Number N7
        ['8', ..] -> Number N8
        ['9', ..] -> Number N9
        [':', ..] -> Symbol Colon
        [';', ..] -> Symbol SemiColon
        ['<', ..] -> Symbol LessThanSign
        ['=', ..] -> Symbol EqualsSign
        ['>', ..] -> Symbol GreaterThanSign
        ['?', ..] -> Symbol QuestionMark
        ['@', ..] -> Symbol AtSign
        ['A', ..] -> Upper A
        ['B', ..] -> Upper B
        ['C', ..] -> Upper C
        ['D', ..] -> Upper D
        ['E', ..] -> Upper E
        ['F', ..] -> Upper F
        ['G', ..] -> Upper G
        ['H', ..] -> Upper H
        ['I', ..] -> Upper I
        ['J', ..] -> Upper J
        ['K', ..] -> Upper K
        ['L', ..] -> Upper L
        ['M', ..] -> Upper M
        ['N', ..] -> Upper N
        ['O', ..] -> Upper O
        ['P', ..] -> Upper P
        ['Q', ..] -> Upper Q
        ['R', ..] -> Upper R
        ['S', ..] -> Upper S
        ['T', ..] -> Upper T
        ['U', ..] -> Upper U
        ['V', ..] -> Upper V
        ['W', ..] -> Upper W
        ['X', ..] -> Upper X
        ['Y', ..] -> Upper Y
        ['Z', ..] -> Upper Z
        ['[', ..] -> Symbol SquareOpenBracket
        ['\\', ..] -> Symbol Backslash
        [']', ..] -> Symbol SquareCloseBracket
        ['^', ..] -> Symbol Caret
        ['_', ..] -> Symbol Underscore
        ['`', ..] -> Symbol GraveAccent
        ['a', ..] -> Lower A
        ['b', ..] -> Lower B
        ['c', ..] -> Lower C
        ['d', ..] -> Lower D
        ['e', ..] -> Lower E
        ['f', ..] -> Lower F
        ['g', ..] -> Lower G
        ['h', ..] -> Lower H
        ['i', ..] -> Lower I
        ['j', ..] -> Lower J
        ['k', ..] -> Lower K
        ['l', ..] -> Lower L
        ['m', ..] -> Lower M
        ['n', ..] -> Lower N
        ['o', ..] -> Lower O
        ['p', ..] -> Lower P
        ['q', ..] -> Lower Q
        ['r', ..] -> Lower R
        ['s', ..] -> Lower S
        ['t', ..] -> Lower T
        ['u', ..] -> Lower U
        ['v', ..] -> Lower V
        ['w', ..] -> Lower W
        ['x', ..] -> Lower X
        ['y', ..] -> Lower Y
        ['z', ..] -> Lower Z
        ['{', ..] -> Symbol CurlyOpenBrace
        ['|', ..] -> Symbol VerticalBar
        ['}', ..] -> Symbol CurlyCloseBrace
        ['~', ..] -> Symbol Tilde
        [127, ..] -> Action Delete
        _ -> Unsupported bytes

expect parseRawStdin [27, 91, 65] == Arrow Up
expect parseRawStdin [27] == Action Escape

inputToStr : Input -> Str
inputToStr = \input ->
    when input is
        Ctrl key -> "Ctrl - " |> Str.concat (ctrlToStr key)
        Action key -> "Action " |> Str.concat (actionToStr key)
        Arrow key -> "Arrow " |> Str.concat (arrowToStr key)
        Symbol key -> "Symbol " |> Str.concat (symbolToStr key)
        Number key -> "Number " |> Str.concat (numberToStr key)
        Upper key -> "Letter " |> Str.concat (upperToStr key)
        Lower key -> "Letter " |> Str.concat (lowerToStr key)
        Unsupported bytes ->
            bytesStr = bytes |> List.map Num.toStr |> Str.joinWith ","
            "Unsupported [$(bytesStr)]"

ctrlToStr : Ctrl -> Str
ctrlToStr = \ctrl ->
    when ctrl is
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
        # M -> "M"
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
        Space -> "[Space]"
        # OpenSquareBracket -> "["
        BackSlash -> "\\"
        SquareCloseBracket -> "]"
        Caret -> "^"
        Underscore -> "_"

actionToStr : Action -> Str
actionToStr = \action ->
    when action is
        Escape -> "Escape"
        Enter -> "Enter"
        Space -> "Space"
        Delete -> "Delete"

arrowToStr : Arrow -> Str
arrowToStr = \arrow ->
    when arrow is
        Up -> "Up"
        Down -> "Down"
        Left -> "Left"
        Right -> "Right"

symbolToStr : Symbol -> Str
symbolToStr = \symbol ->
    when symbol is
        ExclamationMark -> "!"
        QuotationMark -> "\""
        NumberSign -> "#"
        DollarSign -> "\$"
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

upperToStr : Letter -> Str
upperToStr = \letter ->
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

lowerToStr : Letter -> Str
lowerToStr = \letter ->
    when letter is
        A -> "a"
        B -> "b"
        C -> "c"
        D -> "d"
        E -> "e"
        F -> "f"
        G -> "g"
        H -> "h"
        I -> "i"
        J -> "j"
        K -> "k"
        L -> "l"
        M -> "m"
        N -> "n"
        O -> "o"
        P -> "p"
        Q -> "q"
        R -> "r"
        S -> "s"
        T -> "t"
        U -> "u"
        V -> "v"
        W -> "w"
        X -> "x"
        Y -> "y"
        Z -> "z"

ScreenSize : { width : U16, height : U16 }
CursorPosition : { row : U16, col : U16 }
DrawFn : CursorPosition, CursorPosition -> Result Pixel {}
Pixel : { char : Str, fg : Color, bg : Color, styles : List Style }

parseCursor : List U8 -> CursorPosition
parseCursor = \bytes ->
    { val: row, rest: afterFirst } = takeNumber { val: 0, rest: List.dropFirst bytes 2 }
    { val: col } = takeNumber { val: 0, rest: List.dropFirst afterFirst 1 }

    { row, col }

# test "ESC[33;1R"
expect parseCursor [27, 91, 51, 51, 59, 49, 82] == { row: 33, col: 1 }

takeNumber : { val : U16, rest : List U8 } -> { val : U16, rest : List U8 }
takeNumber = \in ->
    when in.rest is
        [a, ..] if a == '0' -> takeNumber { val: in.val * 10 + 0, rest: List.dropFirst in.rest 1 }
        [a, ..] if a == '1' -> takeNumber { val: in.val * 10 + 1, rest: List.dropFirst in.rest 1 }
        [a, ..] if a == '2' -> takeNumber { val: in.val * 10 + 2, rest: List.dropFirst in.rest 1 }
        [a, ..] if a == '3' -> takeNumber { val: in.val * 10 + 3, rest: List.dropFirst in.rest 1 }
        [a, ..] if a == '4' -> takeNumber { val: in.val * 10 + 4, rest: List.dropFirst in.rest 1 }
        [a, ..] if a == '5' -> takeNumber { val: in.val * 10 + 5, rest: List.dropFirst in.rest 1 }
        [a, ..] if a == '6' -> takeNumber { val: in.val * 10 + 6, rest: List.dropFirst in.rest 1 }
        [a, ..] if a == '7' -> takeNumber { val: in.val * 10 + 7, rest: List.dropFirst in.rest 1 }
        [a, ..] if a == '8' -> takeNumber { val: in.val * 10 + 8, rest: List.dropFirst in.rest 1 }
        [a, ..] if a == '9' -> takeNumber { val: in.val * 10 + 9, rest: List.dropFirst in.rest 1 }
        _ -> in

expect takeNumber { val: 0, rest: [27, 91, 51, 51, 59, 49, 82] } == { val: 0, rest: [27, 91, 51, 51, 59, 49, 82] }
expect takeNumber { val: 0, rest: [51, 51, 59, 49, 82] } == { val: 33, rest: [59, 49, 82] }
expect takeNumber { val: 0, rest: [49, 82] } == { val: 1, rest: [82] }

updateCursor : { cursor : CursorPosition, screen : ScreenSize }a, [Up, Down, Left, Right] -> { cursor : CursorPosition, screen : ScreenSize }a
updateCursor = \state, direction ->
    when direction is
        Up ->
            { state &
                cursor: {
                    row: ((state.cursor.row + state.screen.height - 1) % state.screen.height),
                    col: state.cursor.col,
                },
            }

        Down ->
            { state &
                cursor: {
                    row: ((state.cursor.row + 1) % state.screen.height),
                    col: state.cursor.col,
                },
            }

        Left ->
            { state &
                cursor: {
                    row: state.cursor.row,
                    col: ((state.cursor.col + state.screen.width - 1) % state.screen.width),
                },
            }

        Right ->
            { state &
                cursor: {
                    row: state.cursor.row,
                    col: ((state.cursor.col + 1) % state.screen.width),
                },
            }

## Loop through each pixel in screen and build up a single string to write to stdout
drawScreen : { cursor : CursorPosition, screen : ScreenSize }*, List DrawFn -> Str
drawScreen = \{ cursor, screen }, drawFns ->
    pixels =
        List.map (List.range { start: At 0, end: Before screen.height }) \row ->
            List.map (List.range { start: At 0, end: Before screen.width }) \col ->
                List.walkUntil
                    drawFns
                    { char: " ", fg: Default, bg: Default, styles: [] }
                    \defaultPixel, drawFn ->
                        when drawFn cursor { row, col } is
                            Ok pixel -> Break pixel
                            Err _ -> Continue defaultPixel

    pixels
    |> joinAllPixels

joinAllPixels : List (List Pixel) -> Str
joinAllPixels = \rows ->

    walkWithIndex = \remaining, idx, state, fn ->
        when remaining is
            [] -> state
            [head, .. as rest] -> walkWithIndex rest (idx + 1) (fn state head idx) fn

    init = {
        char: " ",
        fg: Default,
        bg: Default,
        lines: List.withCapacity (List.len rows),
        styles: [],
    }

    walkWithIndex rows 0 init joinPixelRow
    |> .lines
    |> Str.joinWith ""

joinPixelRow : { char : Str, fg : Color, bg : Color, lines : List Str, styles : List Style }, List Pixel, U64 -> { char : Str, fg : Color, bg : Color, lines : List Str, styles : List Style }
joinPixelRow = \{ char, fg, bg, lines, styles }, pixelRow, row ->

    { rowStrs, prev } =
        List.walk
            pixelRow
            { rowStrs: List.withCapacity (Num.intCast (List.len pixelRow)), prev: { char, fg, bg, styles } }
            joinPixels

    line =
        rowStrs
        |> Str.joinWith "" # Set cursor at the start of line we want to draw
        |> Str.withPrefix (toStr (Control (Cursor (Abs { row: Num.toU16 (row + 1), col: 0 }))))

    { char: " ", fg: prev.fg, bg: prev.bg, lines: List.append lines line, styles: prev.styles }

joinPixels : { rowStrs : List Str, prev : Pixel }, Pixel -> { rowStrs : List Str, prev : Pixel }
joinPixels = \{ rowStrs, prev }, curr ->
    pixelStr =
        # Prepend an ASCII escape ONLY if there is a change between pixels
        curr.char
        |> \str -> if curr.fg != prev.fg then Str.concat (toStr (Control (Style (Foreground curr.fg)))) str else str
        |> \str -> if curr.bg != prev.bg then Str.concat (toStr (Control (Style (Background curr.bg)))) str else str

    { rowStrs: List.append rowStrs pixelStr, prev: curr }

drawBox : { r : U16, c : U16, w : U16, h : U16, fg ? Color, bg ? Color, char ? Str, styles ? List Style } -> DrawFn
drawBox = \{ r, c, w, h, fg ? Default, bg ? Default, char ? "#", styles ? [] } -> \_, { row, col } ->

        startRow = r
        endRow = (r + h)
        startCol = c
        endCol = (c + w)

        if row == r && (col >= startCol && col < endCol) then
            Ok { char, fg, bg, styles } # TOP BORDER
        else if row == (r + h - 1) && (col >= startCol && col < endCol) then
            Ok { char, fg, bg, styles } # BOTTOM BORDER
        else if col == c && (row >= startRow && row < endRow) then
            Ok { char, fg, bg, styles } # LEFT BORDER
        else if col == (c + w - 1) && (row >= startRow && row < endRow) then
            Ok { char, fg, bg, styles } # RIGHT BORDER
        else
            Err {}

drawVLine : { r : U16, c : U16, len : U16, fg ? Color, bg ? Color, char ? Str, styles ? List Style } -> DrawFn
drawVLine = \{ r, c, len, fg ? Default, bg ? Default, char ? "|", styles ? [] } -> \_, { row, col } ->
        if col == c && (row >= r && row < (r + len)) then
            Ok { char, fg, bg, styles }
        else
            Err {}

drawHLine : { r : U16, c : U16, len : U16, fg ? Color, bg ? Color, char ? Str, styles ? List Style } -> DrawFn
drawHLine = \{ r, c, len, fg ? Default, bg ? Default, char ? "-", styles ? [] } -> \_, { row, col } ->
        if row == r && (col >= c && col < (c + len)) then
            Ok { char, fg, bg, styles }
        else
            Err {}

drawCursor : { fg ? Color, bg ? Color, char ? Str, styles ? List Style } -> DrawFn
drawCursor = \{ fg ? Default, bg ? Default, char ? " ", styles ? [] } -> \cursor, { row, col } ->
        if (row == cursor.row) && (col == cursor.col) then
            Ok { char, fg, bg, styles }
        else
            Err {}

drawText : Str, { r : U16, c : U16, fg ? Color, bg ? Color, styles ? List Style } -> DrawFn
drawText = \text, { r, c, fg ? Default, bg ? Default, styles ? [] } -> \_, pixel ->
        bytes = Str.toUtf8 text
        len = text |> Str.toUtf8 |> List.len |> Num.toU16
        if pixel.row == r && pixel.col >= c && pixel.col < (c + len) then
            bytes
            |> List.get (Num.intCast (pixel.col - c))
            |> Result.try \b -> Str.fromUtf8 [b]
            |> Result.map \char -> { char, fg, bg, styles }
            |> Result.mapErr \_ -> {}
        else
            Err {}
