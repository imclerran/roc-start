module [
    BoxStyle,
    BoxElement,
    border,
]

BoxStyle : [
    SingleWall,
    DoubleWall,
    OneChar Str,
    CustomBorder { tl ? Str, t ? Str, tr ? Str, l ? Str, r ? Str, bl ? Str, b ? Str, br ? Str },
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
border = \pos, style ->
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

        OneChar char ->
            when pos is
                TopLeft -> char
                Top -> char
                TopRight -> char
                Left -> char
                Right -> char
                BotLeft -> char
                Bot -> char
                BotRight -> char

        CustomBorder chars ->
            boxCharsWithDefaults = \{ tl ? "┌", t ? "─", tr ? "┐", l ? "│", r ? "│", bl ? "└", b ? "─", br ? "┘" } -> { tl, t, tr, l, r, bl, b, br }
            boxChars = boxCharsWithDefaults chars
            when pos is
                TopLeft -> boxChars.tl
                Top -> boxChars.t
                TopRight -> boxChars.tr
                Left -> boxChars.l
                Right -> boxChars.r
                BotLeft -> boxChars.bl
                Bot -> boxChars.b
                BotRight -> boxChars.br
