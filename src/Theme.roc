module [
    Theme,
    theme_names,
    from_name,
    default,
]

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

theme_names = |themes| themes |> List.map(.name)

from_name = |themes, name|
    List.keep_if(themes, |th| th.name == name) |> List.first |> Result.map_err(|_| InvalidTheme)

default : Theme
default = {
    name: "default",
    primary: Standard Magenta,
    secondary: Standard Cyan,
    tertiary: Standard White,
    okay: Standard Green,
    warn: Standard Yellow,
    error: Standard Red,
}