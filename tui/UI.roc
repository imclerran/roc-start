module [platformSelect, packageSelect, searchPage]

import Model exposing [Model]
import BoxStyle exposing [BoxStyle, border]
import ansi.Core

platformSelect : Model -> List Core.DrawFn
platformSelect = \model ->
    List.join [
        [
            Core.drawCursor { fg: Standard Magenta, char: ">" },
            exitPrompt model.screen,
            screenPrompt "SELECT A PLATFORM:",
            controlsPrompt " ENTER TO SELECT | S TO SEARCH " model.screen,
        ],
        drawMenu model,
        outerBorder model.screen,
    ]

packageSelect : Model -> List Core.DrawFn
packageSelect = \model ->
    List.join [
        [
            Core.drawCursor { fg: Standard Magenta, char: ">" },
            exitPrompt model.screen,
            screenPrompt "SELECT 0+ PACKAGES:",
            controlsPrompt " SPACE TO SELECT | ENTER TO CONFIRM " model.screen,
        ],
        drawMultipleChoiceMenu model,
        outerBorder model.screen,
    ]

searchPage : Model -> List Core.DrawFn
searchPage = \model ->
    when model.state is
        SearchPage { sender, searchBuffer } ->
            searchPrompt = if sender == Package then "SEARCH FOR A PACKAGE:" else "SEARCH FOR A PLATFORM:"
            List.join [
                [
                    Core.drawCursor { fg: Standard Magenta, char: ">" },
                    exitPrompt model.screen,
                    screenPrompt searchPrompt,
                    controlsPrompt " ENTER TO SEARCH " model.screen,
                    Core.drawText (searchBuffer |> Str.fromUtf8 |> Result.withDefault "") { r: 2, c: 4, fg: Standard White },
                ],
                outerBorder model.screen,
            ]

        _ -> []

screenPrompt = \text -> Core.drawText text { r: 1, c: 2, fg: Standard White }
exitPrompt = \screen -> Core.drawText " Ctrl+C TO QUIT " { r: 0, c: screen.width - 18, fg: Standard Red }
controlsPrompt = \text, screen -> Core.drawText text { r: screen.height - 1, c: 2, fg: Standard Cyan }
outerBorder = \screen -> drawBox 0 0 screen.width screen.height (CustomBorder { tl: "╒", t: "═", tr: "╕" }) (Standard Cyan)

drawBox : I32, I32, I32, I32, BoxStyle, Core.Color -> List Core.DrawFn
drawBox = \col, row, width, height, style, color -> [
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
    checkedItems = List.mapWithIndex model.menu \item, idx -> if List.contains model.selected idx then "[X] $(item)" else "[ ] $(item)"
    item, idx <- List.mapWithIndex checkedItems
    row = Num.toI32 idx + model.menuRow
    if model.cursor.row == row then
        Core.drawText "> $(item)" { r: row, c: 2, fg: Standard Magenta }
    else
        Core.drawText "- $(item)" { r: row, c: 2, fg: Default }
