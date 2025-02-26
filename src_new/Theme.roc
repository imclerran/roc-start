module [Theme, default, warn_only, no_color]

import ansi.Color
Color : Color.Color

Theme : { 
    primary: Color,
    secondary: Color,
    tertiary: Color,
    okay: Color,
    error: Color,
    warn: Color,
}

default : Theme
default = 
    dark_purple = Rgb((107, 58, 220))
    light_purple = Rgb((137, 101, 222))
    dark_cyan = Rgb((57, 171, 219))
    coral = Rgb((222, 100, 124))
    green = Rgb((122, 222, 100))
    orange = Rgb((222, 136, 100))
    {
        primary: light_purple,
        secondary: dark_cyan,
        tertiary :dark_purple,
        okay : green,
        warn: orange,
        error : coral,
    }

warn_only : Theme
warn_only = 
    coral = Rgb((222, 100, 124))
    orange = Rgb((222, 136, 100)) 
    {
        primary: Default,
        secondary: Default,
        tertiary :Default,
        okay : Default,
        warn: orange,
        error : coral,
    }

no_color : Theme
no_color = 
    {
        primary: Default,
        secondary: Default,
        tertiary :Default,
        okay : Default,
        warn: Default,
        error : Default,
    }