module [
    BoxStyle,
    BoxElement,
    border,
]

BoxStyle : [
    SingleWall,
    DoubleWall,
    OneChar Str,
    CustomBorder { tl ?? Str, t ?? Str, tr ?? Str, l ?? Str, r ?? Str, bl ?? Str, b ?? Str, br ?? Str },
]

BoxElement : [
    TopLeft,
    Top,
    TopRight,
    Left,
    Right,
    BotLeft,
    Bot,
    BotRight,
]

border : BoxElement, BoxStyle -> Str
border = |pos, style|
    when style is
        SingleWall ->
            when pos is
                TopLeft -> "┌"
                Top -> "─"
                TopRight -> "┐"
                Left -> "│"
                Right -> "│"
                BotLeft -> "└"
                Bot -> "─"
                BotRight -> "┘"

        DoubleWall ->
            when pos is
                TopLeft -> "╔"
                Top -> "═"
                TopRight -> "╗"
                Left -> "║"
                Right -> "║"
                BotLeft -> "╚"
                Bot -> "═"
                BotRight -> "╝"

        OneChar(char) ->
            when pos is
                TopLeft -> char
                Top -> char
                TopRight -> char
                Left -> char
                Right -> char
                BotLeft -> char
                Bot -> char
                BotRight -> char

        CustomBorder(chars) ->
            box_chars_with_defaults = |{ tl ?? "┌", t ?? "─", tr ?? "┐", l ?? "│", r ?? "│", bl ?? "└", b ?? "─", br ?? "┘" }| { tl, t, tr, l, r, bl, b, br }
            box_chars = box_chars_with_defaults(chars)
            when pos is
                TopLeft -> box_chars.tl
                Top -> box_chars.t
                TopRight -> box_chars.tr
                Left -> box_chars.l
                Right -> box_chars.r
                BotLeft -> box_chars.bl
                Bot -> box_chars.b
                BotRight -> box_chars.br
