module [renderTypeSelect, renderInputAppName, renderPlatformSelect, renderPackageSelect, renderSearch, renderConfirmation, renderSplash, renderBox]

import AsciiArt
import BoxStyle exposing [BoxStyle, border]
import Controller exposing [UserAction]
import Model exposing [Model]
import ansi.Core

## Render functions for each page
renderScreenPrompt = \text -> Core.drawText text { r: 1, c: 2, fg: Standard Cyan }
renderExitPrompt = \screen -> Core.drawText " Ctrl+C : QUIT " { r: 0, c: screen.width - 17, fg: Standard Red }
renderControlsPrompt = \text, screen -> Core.drawText text { r: screen.height - 1, c: 2, fg: Standard Cyan }
renderOuterBorder = \screen -> renderBox 0 0 screen.width screen.height (CustomBorder { tl: "╒", t: "═", tr: "╕" }) (Standard Cyan)

## Control prompts for each user action
controlPromptsDict : Dict UserAction Str
controlPromptsDict =
    Dict.empty {}
    |> Dict.insert SingleSelect "ENTER : SELECT"
    |> Dict.insert MultiSelect "SPACE : SELECT"
    |> Dict.insert MultiConfirm "ENTER : CONFIRM"
    |> Dict.insert TextSubmit "ENTER : CONFIRM"
    |> Dict.insert GoBack "BKSP : GO BACK"
    |> Dict.insert Search "S : SEARCH"
    |> Dict.insert ClearFilter "ESC : FULL LIST"
    |> Dict.insert SearchGo "ENTER : SEARCH"
    |> Dict.insert Cancel "ESC : CANCEL"
    |> Dict.insert Finish "ENTER : FINISH"
    |> Dict.insert CursorUp ""
    |> Dict.insert CursorDown ""
    |> Dict.insert TextInput ""
    |> Dict.insert TextBackspace ""
    |> Dict.insert Exit ""
    |> Dict.insert None ""
    |> Dict.insert Secret ""
    |> Dict.insert PrevPage "< PREV"
    |> Dict.insert NextPage "> NEXT"

## Shortened control prompts for smaller screens
controlPromptsShortDict : Dict UserAction Str
controlPromptsShortDict =
    Dict.empty {}
    |> Dict.insert SingleSelect "ENTER"
    |> Dict.insert MultiSelect "SPACE"
    |> Dict.insert MultiConfirm "ENTER"
    |> Dict.insert TextSubmit "ENTER"
    |> Dict.insert GoBack "BKSP"
    |> Dict.insert Search "S"
    |> Dict.insert ClearFilter "ESC"
    |> Dict.insert SearchGo "ENTER"
    |> Dict.insert Cancel "ESC"
    |> Dict.insert Finish "ENTER"
    |> Dict.insert CursorUp ""
    |> Dict.insert CursorDown ""
    |> Dict.insert TextInput ""
    |> Dict.insert TextBackspace ""
    |> Dict.insert Exit ""
    |> Dict.insert None ""
    |> Dict.insert Secret ""
    |> Dict.insert PrevPage "<"
    |> Dict.insert NextPage ">"

## Build string with all available controls
controlsPromptStr : Model -> Str
controlsPromptStr = \model ->
    actions = Controller.getActions model
    longStr = buildControlPromptStr actions controlPromptsDict
    promptLen = Num.toI32 (Str.countUtf8Bytes longStr)
    if promptLen <= model.screen.width - 6 && promptLen > 0 then
        " $(longStr) "
    else if promptLen > 0 then
        " $(buildControlPromptStr actions controlPromptsShortDict) "
    else
        ""

buildControlPromptStr : List UserAction, Dict UserAction Str -> Str
buildControlPromptStr = \actions, promptsDict ->
    actions
    |> List.map \action ->
        Dict.get promptsDict action |> Result.withDefault ""
    |> List.dropIf (\str -> Str.isEmpty str)
    |> Str.joinWith " | "

## Render a multi-line text with word wrapping
renderMultiLineText : List Str, { startCol : I32, startRow : I32, maxCol : I32, wrapCol : I32, wordDelim ? Str, fg ? Core.Color } -> List Core.DrawFn
renderMultiLineText = \words, { startCol, startRow, maxCol, wrapCol, wordDelim ? " ", fg ? Standard White } ->
    firstLineWidth = maxCol - startCol
    consecutiveWidths = maxCol - wrapCol
    delims = List.repeat wordDelim (if List.len words == 0 then 0 else List.len words - 1) |> List.append ""
    wordsWithDelims = List.map2 words delims \word, delim -> Str.concat word delim
    lineList =
        List.walk wordsWithDelims [] \lines, word ->
            when lines is
                [line] ->
                    if Num.toI32 (Str.countUtf8Bytes line + Str.countUtf8Bytes word) <= firstLineWidth then
                        [Str.concat line word]
                    else
                        [line, word]

                [.. as prevLines, line] ->
                    if Num.toI32 (Str.countUtf8Bytes line + Str.countUtf8Bytes word) <= consecutiveWidths then
                        List.concat prevLines [Str.concat line word]
                    else
                        List.concat prevLines [line, word]

                [] -> [word]
    List.mapWithIndex lineList \line, idx ->
        if idx == 0 then
            Core.drawText line { r: startRow, c: startCol, fg }
        else
            Core.drawText line { r: startRow + (Num.toI32 idx), c: wrapCol, fg }

renderTypeSelect : Model -> List Core.DrawFn
renderTypeSelect = \model ->
    List.join [
        [
            renderExitPrompt model.screen,
            renderControlsPrompt (controlsPromptStr model) model.screen,
        ],
        renderOuterBorder model.screen,
        [
            renderScreenPrompt "WHAT TO START?",
            Core.drawCursor { fg: Standard Magenta, char: ">" },
        ],
        renderMenu model,
    ]

## Generate the list of functions to draw the platform select page.
renderPlatformSelect : Model -> List Core.DrawFn
renderPlatformSelect = \model ->
    List.join [
        [
            renderExitPrompt model.screen,
            renderControlsPrompt (controlsPromptStr model) model.screen,
        ],
        renderOuterBorder model.screen,
        [
            renderScreenPrompt "SELECT A PLATFORM:",
            Core.drawCursor { fg: Standard Magenta, char: ">" },
        ],
        renderMenu model,
    ]

## Generate the list of functions to draw the package select page.
renderPackageSelect : Model -> List Core.DrawFn
renderPackageSelect = \model ->
    List.join [
        [
            renderExitPrompt model.screen,
            renderControlsPrompt (controlsPromptStr model) model.screen,
        ],
        renderOuterBorder model.screen,
        [
            renderScreenPrompt "SELECT 0+ PACKAGES:",
            Core.drawCursor { fg: Standard Magenta, char: ">" },
        ],
        renderMultipleChoiceMenu model,

    ]

## Generate the list of functions to draw the app name input page.
renderInputAppName : Model -> List Core.DrawFn
renderInputAppName = \model ->
    when model.state is
        InputAppName { nameBuffer } ->
            List.join [
                [
                    renderExitPrompt model.screen,
                    renderControlsPrompt (controlsPromptStr model) model.screen,
                ],
                renderOuterBorder model.screen,
                if List.len nameBuffer == 0 then [Core.drawText " (Leave blank for \"main\"):" { r: 1, c: 20, fg: Standard Cyan }] else [],
                [
                    renderScreenPrompt "ENTER THE APP NAME:",
                    Core.drawCursor { fg: Standard Magenta, char: ">" },
                    Core.drawText (nameBuffer |> Str.fromUtf8 |> Result.withDefault "") { r: model.menuRow, c: 4, fg: Standard White },

                ],
            ]

        _ -> []

## Generate the list of functions to draw the search page.
renderSearch : Model -> List Core.DrawFn
renderSearch = \model ->
    when model.state is
        Search { sender, searchBuffer } ->
            searchPrompt = if sender == Package then "SEARCH FOR A PACKAGE:" else "SEARCH FOR A PLATFORM:"
            List.join [
                [
                    renderExitPrompt model.screen,
                    renderControlsPrompt (controlsPromptStr model) model.screen,
                ],
                renderOuterBorder model.screen,
                [
                    renderScreenPrompt searchPrompt,
                    Core.drawCursor { fg: Standard Magenta, char: ">" },
                    Core.drawText (searchBuffer |> Str.fromUtf8 |> Result.withDefault "") { r: model.menuRow, c: 4, fg: Standard White },
                ],
            ]

        _ -> []

## Generate the list of functions to draw the confirmation page.
renderConfirmation : Model -> List Core.DrawFn
renderConfirmation = \model ->
    when model.state is
        Confirmation { config } ->
            List.join [
                [
                    renderExitPrompt model.screen,
                    renderControlsPrompt (controlsPromptStr model) model.screen,
                ],
                renderOuterBorder model.screen,
                (
                    if config.type == App then
                        [
                            renderScreenPrompt "APP CONFIGURATION:",
                            Core.drawText "App name:" { r: model.menuRow, c: 2, fg: Standard Magenta },
                            Core.drawText config.fileName { r: model.menuRow, c: 12, fg: Standard White },
                            Core.drawText "Platform:" { r: model.menuRow + 1, c: 2, fg: Standard Magenta },
                            Core.drawText config.platform { r: model.menuRow + 1, c: 12, fg: Standard White },
                            Core.drawText "Packages:" { r: model.menuRow + 2, c: 2, fg: Standard Magenta },
                        ]
                    else
                        [
                            renderScreenPrompt "PACKAGE CONFIGURATION:",
                            Core.drawText "Packages:" { r: model.menuRow, c: 2, fg: Standard Magenta },
                        ]
                ),
                renderMultiLineText config.packages {
                    startCol: 12,
                    startRow: if config.type == App then (model.menuRow + 2) else model.menuRow,
                    maxCol: (model.screen.width - 1),
                    wrapCol: 2,
                    wordDelim: ", ",
                    fg: Standard White,
                },
            ]

        _ -> []

## Generate the list of functions to draw a box.
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

## Generate the list of functions to draw a single select menu.
renderMenu : Model -> List Core.DrawFn
renderMenu = \model ->
    item, idx <- List.mapWithIndex model.menu
    row = Num.toI32 idx + model.menuRow
    if model.cursor.row == row then
        Core.drawText "> $(item)" { r: row, c: 2, fg: Standard Magenta }
    else
        Core.drawText "- $(item)" { r: row, c: 2, fg: Default }

## Generate the list of functions to draw a multiple choice menu.
renderMultipleChoiceMenu : Model -> List Core.DrawFn
renderMultipleChoiceMenu = \model ->
    isSelected = \item -> List.contains model.selected item
    checkedItems = List.map model.menu \item -> if isSelected item then "[X] $(item)" else "[ ] $(item)"
    item, idx <- List.mapWithIndex checkedItems
    row = Num.toI32 idx + model.menuRow
    if model.cursor.row == row then
        Core.drawText "> $(item)" { r: row, c: 2, fg: Standard Magenta }
    else
        Core.drawText "- $(item)" { r: row, c: 2, fg: Default }

renderSplash : Model -> List Core.DrawFn
renderSplash = \model ->
    List.join [
        [
            renderExitPrompt model.screen,
            renderControlsPrompt (controlsPromptStr model) model.screen,
        ],
        renderOuterBorder model.screen,
        renderSplashBySize model.screen,
    ]

renderSplashBySize : Core.ScreenSize -> List Core.DrawFn
renderSplashBySize = \screen ->
    art = chooseSplashArt screen
    startRow = (screen.height - art.height) // 2
    startCol = (screen.width - art.width) // 2
    List.join [
        renderArtAccent art screen,
        renderAsciiArt art startRow startCol,
    ]

renderAsciiArt : AsciiArt.Art, I32, I32 -> List Core.DrawFn
renderAsciiArt = \art, startRow, startCol ->
    List.map art.art \elem ->
        Core.drawText elem.text { r: startRow + elem.r, c: startCol + elem.c, fg: elem.color }

chooseSplashArt : Core.ScreenSize -> AsciiArt.Art
chooseSplashArt = \screen ->
    if
        (screen.height >= (AsciiArt.rocLargeColored.height + 2))
        && (screen.width >= (AsciiArt.rocLargeColored.width + 2))
    then
        AsciiArt.rocLargeColored
    else if
        (screen.height >= (AsciiArt.rocSmallColored.height + 2))
        && (screen.width >= (AsciiArt.rocSmallColored.width + 2))
    then
        AsciiArt.rocSmallColored
    else
        AsciiArt.rocStartColored

renderArtAccent : AsciiArt.Art, Core.ScreenSize -> List Core.DrawFn
renderArtAccent = \art, screen ->
    startRow = (screen.height - art.height) // 2
    startCol = (screen.width - art.width) // 2
    if art == AsciiArt.rocLargeColored then
        List.mapWithIndex AsciiArt.rocStart \line, idx ->
            Core.drawText line { r: startRow + 30 + Num.toI32 idx, c: startCol + 50, fg: Standard Cyan }
    else if art == AsciiArt.rocSmallColored then
        [
            Core.drawText "roc start" { r: startRow + 11, c: startCol + 16, fg: Standard Cyan },
            Core.drawText "quick start cli" { r: startRow + 12, c: startCol + 16, fg: Standard Cyan },
        ]
    else
        [Core.drawText " quick start cli" { r: startRow + 5, c: startCol, fg: Standard Cyan }]
