module [C256, toRgb]

import Rgb exposing [Rgb]

## [Ansi 16 colors](https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit)
## System range (0-15)
## Chromatic range 6x6x6 cube (16-231)
## Grayscale range (232-255)
C256 : U8

toCode : C256 -> U8
toCode = \color -> color

# https://www.ditig.com/publications/256-colors-cheat-sheet
systemRange : List Rgb
systemRange = [
    (000, 000, 000), # Standard black
    (128, 000, 000), # Standard red
    (000, 128, 000), # Standard green
    (128, 128, 000), # Standard yellow
    (000, 000, 128), # Standard blue
    (128, 000, 128), # Standard magenta
    (000, 128, 128), # Standard cyan
    (192, 192, 192), # Standard white (light gray)
    (128, 128, 128), # Bright black (dark gray)
    (255, 000, 000), # Bright red
    (000, 255, 000), # Bright green
    (255, 255, 000), # Bright yellow
    (000, 000, 255), # Bright blue
    (255, 000, 255), # Bright magenta
    (000, 255, 255), # Bright cyan
    (255, 255, 255), # Bright white
]

chromaticRange = List.concat [0] (List.range { start: At 95, end: Length 5, step: 40 })
grayscaleRange = List.range { start: At 8, end: Length 24, step: 10 }

# https://www.hackitu.de/termcolor256/
toRgb : C256 -> Rgb
toRgb = \color ->
    when Num.toU64 (toCode color) is
        code if code < 16 ->
            List.get systemRange code |> Result.withDefault (0, 0, 0)

        code if code < 232 ->
            index = code - 16
            c = \a -> List.get chromaticRange (index |> Num.divTrunc (Num.powInt 6 (2 - a)) |> Num.rem 6) |> Result.withDefault 0
            (c 0, c 1, c 2)

        code ->
            index = code - 232
            gray = List.get grayscaleRange index |> Result.withDefault 0
            (gray, gray, gray)

expect toRgb 8 == (128, 128, 128)
expect toRgb 55 == (95, 0, 175)
expect toRgb 240 == (88, 88, 88)

# TODO: toC16 : C256 -> C16
