module [C16, toC256, nameToCode, Name]

import C256 exposing [C256]

## [Ansi 16 colors](https://en.wikipedia.org/wiki/ANSI_escape_code#3-bit_and_4-bit)
## This colors can be customized, leading to variations across different terminals.
## Therefore, if your use case requires a consistent color palette, it's recommended to avoid using them.
C16 : [Standard Name, Bright Name]
Name : [Black, Red, Green, Yellow, Blue, Magenta, Cyan, White]

nameToCode : Name -> U8
nameToCode = \name ->
    when name is
        Black -> 0
        Red -> 1
        Green -> 2
        Yellow -> 3
        Blue -> 4
        Magenta -> 5
        Cyan -> 6
        White -> 7

toC256 : C16 -> C256
toC256 = \intensity ->
    when intensity is
        Standard name -> 0 + nameToCode name
        Bright name -> 8 + nameToCode name
