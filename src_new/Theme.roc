module [Theme, roc, warn_only, no_color]

import ansi.Color
Color : Color.Color

Theme : {
    name : Str,
    primary : Color,
    secondary : Color,
    tertiary : Color,
    okay : Color,
    error : Color,
    warn : Color,
}

roc : Theme
roc =
    dark_purple = Rgb((107, 58, 220))
    light_purple = Rgb((137, 101, 222))
    dark_cyan = Rgb((57, 171, 219))
    coral = Rgb((222, 100, 124))
    green = Rgb((122, 222, 100))
    orange = Rgb((222, 136, 100))
    {
        name: "roc",
        primary: light_purple,
        secondary: dark_cyan,
        tertiary: dark_purple,
        okay: green,
        warn: orange,
        error: coral,
    }

warn_only : Theme
warn_only =
    coral = Rgb((222, 100, 124))
    orange = Rgb((222, 136, 100))
    {
        name: "warn-only",
        primary: Default,
        secondary: Default,
        tertiary: Default,
        okay: Default,
        warn: orange,
        error: coral,
    }

no_color : Theme
no_color = {
    name: "no-color",
    primary: Default,
    secondary: Default,
    tertiary: Default,
    okay: Default,
    warn: Default,
    error: Default,
}
