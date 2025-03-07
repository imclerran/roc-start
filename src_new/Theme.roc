module [Theme, themes, theme_names, from_name, roc, roc_mono, warn_only, no_color]

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

themes : List Theme
themes = [roc_mono, roc, warn_only, no_color]

theme_names = themes |> List.map(.name)

from_name = |name|
    if name == roc.name then
        Ok(roc)
    else if name == roc_mono.name then
        Ok(roc_mono)
    else if name == warn_only.name then
        Ok(warn_only)
    else if name == no_color.name then
        Ok(no_color)
    else
        Err(InvalidTheme)

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

roc_mono =
    light_purple = Rgb((137, 101, 222))
    orange = Rgb((222, 136, 100))
    coral = Rgb((222, 100, 124))
    {
        name: "roc-mono",
        primary: light_purple,
        secondary: light_purple,
        tertiary: light_purple,
        okay: light_purple,
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
