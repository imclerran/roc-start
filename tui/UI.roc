module [platformSelect, packageSelect, searchPage, renderBox]

import Model exposing [Model]
import BoxStyle exposing [BoxStyle, border]
import ansi.Core

screenPrompt = \text -> Core.drawText text { r: 1, c: 2, fg: Standard White }
exitPrompt = \screen -> Core.drawText " Ctrl+C TO QUIT " { r: 0, c: screen.width - 18, fg: Standard Red }
controlsPrompt = \text, screen -> Core.drawText text { r: screen.height - 1, c: 2, fg: Standard Cyan }
outerBorder = \screen -> renderBox 0 0 screen.width screen.height (CustomBorder { tl: "╒", t: "═", tr: "╕" }) (Standard Cyan)

navStr =\ model ->
    if Model.isNotFirstPage model && Model.isNotLastPage model then
        " | < PREV | > NEXT "
    else if Model.isNotFirstPage model then
        " | < PREV "
    else if Model.isNotLastPage model then
        " | > NEXT "
    else ""

platformSelect : Model -> List Core.DrawFn
platformSelect = \model ->
    List.join [
        [
            exitPrompt model.screen,
            controlsPrompt " ENTER TO SELECT | S TO SEARCH $(navStr model)" model.screen,
        ],
        outerBorder model.screen,
        [
            screenPrompt "SELECT A PLATFORM:",
            Core.drawCursor { fg: Standard Magenta, char: ">" },
        ],
        drawMenu model,

    ]

packageSelect : Model -> List Core.DrawFn
packageSelect = \model ->
    List.join [
        [
            exitPrompt model.screen,
            controlsPrompt " SPACE TO SELECT | ENTER TO CONFIRM | BKSPACE TO GO BACK $(navStr model)" model.screen,
        ],
        outerBorder model.screen,
        [
            screenPrompt "SELECT 0+ PACKAGES:",
            Core.drawCursor { fg: Standard Magenta, char: ">"},
        ],
        drawMultipleChoiceMenu model,

    ]

searchPage : Model -> List Core.DrawFn
searchPage = \model ->
    when model.state is
        SearchPage { sender, searchBuffer } ->
            searchPrompt = if sender == Package then "SEARCH FOR A PACKAGE:" else "SEARCH FOR A PLATFORM:"
            List.join [
                [
                    exitPrompt model.screen,
                    controlsPrompt " ENTER TO SEARCH " model.screen,
                ],
                outerBorder model.screen,
                [
                    screenPrompt searchPrompt,
                    Core.drawCursor { fg: Standard Magenta, char: ">" },
                    Core.drawText (searchBuffer |> Str.fromUtf8 |> Result.withDefault "") { r: 2, c: 4, fg: Standard White },
                ],
            ]

        _ -> []

renderBox : I32, I32, I32, I32, BoxStyle, Core.Color -> List Core.DrawFn
renderBox = \col, row, width, height, style, color -> [
    Core.drawHLine { r: row, c: col, len: 1, char: border TopLeft style, fg: color },
    Core.drawHLine { r: row, c: col + 1, len: width - 2, char: border Top style, fg: color },
    Core.drawHLine { r: row, c: col + width - 1, len: 1, char: border TopRight style, fg: color },
    Core.drawVLine { r: row + 1, c: col, len: height - 2, char: border Left style, fg: color },
    Core.drawVLine { r: row + 1, c: col + width - 1, len: height - 2, char: border Right style, fg: color },
    Core.drawHLine { r: row + height - 1, c: col, len: 1, char: border BotLeft style, fg: color },
    Core.drawHLine { r: row + height - 1, c: col + 1, len: width - 2, char: border Bot style, fg: color },
    Core.drawHLine { r: row + height - 1, c: col + width - 1, len: 1, char: border BotRight style, fg: color },
]

drawMenu = \model ->
    item, idx <- List.mapWithIndex model.menu
    row = Num.toI32 idx + model.menuRow
    if model.cursor.row == row then
        Core.drawText "> $(item)" { r: row, c: 2, fg: Standard Magenta }
    else
        Core.drawText "- $(item)" { r: row, c: 2, fg: Default }

drawMultipleChoiceMenu = \model ->
    isSelected = \menuIdx -> List.contains model.selected (Model.menuIdxToFullIdx menuIdx model)
    checkedItems = List.mapWithIndex model.menu \item, idx -> if isSelected idx then "[X] $(item)" else "[ ] $(item)"
    item, idx <- List.mapWithIndex checkedItems
    row = Num.toI32 idx + model.menuRow
    if model.cursor.row == row then
        Core.drawText "> $(item)" { r: row, c: 2, fg: Standard Magenta }
    else
        Core.drawText "- $(item)" { r: row, c: 2, fg: Default }
