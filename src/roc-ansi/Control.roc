module [Control, toCode]

import Style exposing [Style]

## [Control](https://en.wikipedia.org/wiki/ANSI_escape_code#CSI_(Control_Sequence_Introducer)_sequences) (commonly known as Control Sequence Introducer or CSI)
## represents the control sequences for terminal commands.
## The provided commands are common and well-supported, though not exhaustive.
Control : [
    Screen [Size],
    Cursor
        [
            Position [Get, Save, Restore],
            Display [On, Off],
            ## Move relatively by a specified number of rows up or down, or columns left or right.
            Rel [Up, Down, Left, Right] U16,
            ## Move relatively by a specified number of rows next or previous (and to the first column of the corresponding row).
            Row [Next, Prev] U16,
            ## Move absolutely to the specified row and column.
            Abs { row : U16, col : U16 },
            ## Move absolutely to the specified column in the current row.
            Col U16,
        ],
    Erase
        [
            Display [ToEnd, ToStart, All],
            Line [ToEnd, ToStart, All],
        ],
    Scroll [Up, Down] U16,
    Style Style,
]

toCode : Control -> Str
toCode = \a ->
    when a is
        Screen b ->
            when b is
                Size -> "18t"

        Cursor b ->
            when b is
                Position state ->
                    when state is
                        Get -> "6n"
                        Save -> "s"
                        Restore -> "u"

                Display state ->
                    "?25"
                    |> Str.concat
                        (
                            when state is
                                On -> "l"
                                Off -> "h"
                        )

                Rel direction number ->
                    Num.toStr number
                    |> Str.concat
                        (
                            when direction is
                                Up -> "A"
                                Down -> "B"
                                Right -> "C"
                                Left -> "D"
                        )

                Row direction number ->
                    Num.toStr number
                    |> Str.concat
                        (
                            when direction is
                                Next -> "E"
                                Prev -> "F"
                        )

                Abs { row, col } -> [row, col] |> List.map Num.toStr |> Str.joinWith ";" |> Str.concat "H"
                Col col -> col |> Num.toStr |> Str.concat "G"

        Erase b ->
            when b is
                Display d ->
                    (
                        when d is
                            ToEnd -> 0
                            ToStart -> 1
                            All -> 2
                        # ClearScreen -> 3
                    )
                    |> Num.toStr
                    |> Str.concat "J"

                Line l ->
                    (
                        when l is
                            ToEnd -> 0
                            ToStart -> 1
                            All -> 2
                    )
                    |> Num.toStr
                    |> Str.concat "K"

        Scroll direction lines ->
            Num.toStr lines
            |> Str.concat
                (
                    when direction is
                        Up -> "S"
                        Down -> "T"
                )

        Style style -> style |> Style.toCode |> List.map Num.toStr |> Str.joinWith ";" |> Str.concat "m"
