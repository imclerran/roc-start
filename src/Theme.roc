module [Theme, themes, theme_names, from_name, roc_c16, roc, roc_mono, warn_only, no_color, coffee_cat_dark, coffee_cat_light]

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

rgb = |r, g, b| Rgb((r, g, b))

themes : List Theme
themes = [roc_mono, roc_c16, roc, warn_only, no_color, coffee_cat_dark, coffee_cat_light]

theme_names = themes |> List.map(.name)

from_name = |name|
    List.keep_if(themes, |th| th.name == name) |> List.first |> Result.map_err(|_| InvalidTheme)

roc : Theme
roc =
    light_purple = rgb(137, 101, 222)
    dark_cyan = rgb(57, 171, 219)
    coral = rgb(222, 100, 124)
    green = rgb(122, 222, 100)
    peach = rgb(250, 179, 135)
    {
        name: "roc",
        primary: light_purple,
        secondary: dark_cyan,
        tertiary: Standard White,
        okay: green,
        warn: peach,
        error: coral,
    }

roc_c16 : Theme
roc_c16 = {
    name: "roc-c16",
    primary: Standard Magenta,
    secondary: Standard Cyan,
    tertiary: Standard White,
    okay: Standard Green,
    warn: Standard Yellow,
    error: Standard Red,
}

roc_mono =
    light_purple = rgb(137, 101, 222)
    peach = rgb(250, 179, 135)
    coral = rgb(222, 100, 124)
    {
        name: "roc-mono",
        primary: light_purple,
        secondary: light_purple,
        tertiary: light_purple,
        okay: light_purple,
        warn: peach,
        error: coral,
    }

warn_only : Theme
warn_only =
    coral = rgb(222, 100, 124)
    peach = rgb(250, 179, 135)
    {
        name: "warn-only",
        primary: Default,
        secondary: Default,
        tertiary: Default,
        okay: Default,
        warn: peach,
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

coffee_cat_dark : Theme
coffee_cat_dark =
    mauve = rgb(203, 166, 247)
    saffire = rgb(116, 199, 236)
    teal = rgb(148, 226, 213)
    red = rgb(243, 139, 168)
    maroon = rgb(235, 160, 172)
    green = rgb(166, 227, 161)
    {
        name: "coffee-cat-dark",
        primary: mauve,
        secondary: saffire,
        tertiary: teal,
        okay: green,
        warn: maroon,
        error: red,
    }

coffee_cat_light : Theme
coffee_cat_light =
    mauve = rgb(136, 57, 239)
    saffire = rgb(32, 159, 181)
    pink = rgb(234, 118, 203)
    red = rgb(210, 15, 57)
    # peach = rgb(254, 100, 11)
    flamingo = rgb(221, 120, 120)
    green = rgb(64, 160, 43)
    {
        name: "coffee-cat-light",
        primary: mauve,
        secondary: saffire,
        tertiary: pink,
        okay: green,
        warn: flamingo,
        error: red,
    }


