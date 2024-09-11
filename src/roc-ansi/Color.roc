module [Color, toCode]

import C16 exposing [C16]
import C256 exposing [C256]
import Rgb exposing [Rgb]

## [Color](https://en.wikipedia.org/wiki/ANSI_escape_code#Colors)
## it includes the 4-bit, 8-bit and 24-bit colors supported on *most* modern terminal emulators.
Color : [
    Default,
    C16 C16,
    C256 C256,
    Rgb Rgb,
    # Convenient to have
    Hex Rgb.Hex,
    Standard C16.Name,
    Bright C16.Name,
]

toCode : Color, U8 -> List U8
toCode = \color, offset ->
    when color is
        Default -> [9 + offset]
        Rgb (red, green, blue) -> [8 + offset, 2, red, green, blue]
        C256 index -> [8 + offset, 5, index]
        C16 intensity ->
            [
                (
                    when intensity is
                        Standard name -> 0 + C16.nameToCode name
                        Bright name -> 60 + C16.nameToCode name
                )
                |> Num.add offset,
            ]

        Hex hex -> toCode (Rgb (Rgb.fromHex hex)) offset
        Standard name -> toCode (C16 (Standard name)) offset
        Bright name -> toCode (C16 (Bright name)) offset
