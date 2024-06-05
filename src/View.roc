module [renderInputAppName, renderPlatformSelect, renderPackageSelect, renderSearch, renderConfirmation, renderBox]

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
    |> Dict.insert TextConfirm "ENTER : CONFIRM"
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
    |> Dict.insert PrevPage "< PREV"
    |> Dict.insert NextPage "> NEXT"

## Shortened control prompts for smaller screens
controlPromptsShortDict : Dict UserAction Str
controlPromptsShortDict =
    Dict.empty {}
    |> Dict.insert SingleSelect "ENTER"
    |> Dict.insert MultiSelect "SPACE"
    |> Dict.insert MultiConfirm "ENTER"
    |> Dict.insert TextConfirm "ENTER"
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
    |> Dict.insert PrevPage "<"
    |> Dict.insert NextPage ">"

## Build string with all available controls
controlsPromptStr : Model -> Str
controlsPromptStr = \model ->
    actions = Controller.getActions model
    longStr = buildControlPromptStr actions controlPromptsDict
    if Num.toI32 (Str.countUtf8Bytes longStr) <= model.screen.width - 6 then
        " $(longStr) "
    else
        " $(buildControlPromptStr actions controlPromptsShortDict) "

buildControlPromptStr : List UserAction, Dict UserAction Str -> Str
buildControlPromptStr = \actions, promptsDict ->
    actions
    |> List.map \action ->
        Dict.get promptsDict action |> Result.withDefault ""
    |> List.dropIf (\str -> Str.isEmpty str)
    |> Str.joinWith " | "

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
                [
                    renderScreenPrompt "YOU SELECTED:",
                    Core.drawText "App name:" { r: model.menuRow, c: 2, fg: Standard Magenta },
                    Core.drawText config.appName { r: model.menuRow, c: 12, fg: Standard White },
                    Core.drawText "Platform:" { r: model.menuRow + 1, c: 2, fg: Standard Magenta },
                    Core.drawText config.platform { r: model.menuRow + 1, c: 12, fg: Standard White },
                    Core.drawText "Packages:" { r: model.menuRow + 2, c: 2, fg: Standard Magenta },
                    Core.drawText (config.packages |> Str.joinWith ", ") { r: model.menuRow + 2, c: 12, fg: Standard White },
                ],
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
