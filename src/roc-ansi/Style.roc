module [Style, toCode]

import Color exposing [Color]

## [Style](https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_(Select_Graphic_Rendition)_parameters) (commonly known as Select Graphic Rendition or SGR)
## represents the control sequence for terminal display attributes.
## It controls various attributes, which remain in effect until explicitly reset by a subsequent style sequence.
## The provided attributes are common and well-supported, though not exhaustive.
Style : [
    Default,
    Bold [On, Off],
    Faint [On, Off],
    Italic [On, Off],
    Underline [On, Off],
    Strikethrough [On, Off],
    Invert [On, Off],
    Foreground Color,
    Background Color,
]

toCode : Style -> List U8
toCode = \a ->
    when a is
        Default -> [0]
        Bold state ->
            when state is
                On -> [1]
                Off -> [22]

        Faint state ->
            when state is
                On -> [2]
                Off -> [22]

        Italic state ->
            when state is
                On -> [3]
                Off -> [23]

        Underline state ->
            when state is
                On -> [4]
                Off -> [24]

        Strikethrough state ->
            when state is
                On -> [9]
                Off -> [29]

        Invert state ->
            when state is
                On -> [7]
                Off -> [27]

        Foreground color -> color |> Color.toCode 30
        Background color -> color |> Color.toCode 40
