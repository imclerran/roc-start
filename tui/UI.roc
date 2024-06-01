module [renderPlatformSelect, renderPackageSelect, renderSearchPage, renderConfirmation, renderBox]

import Model exposing [Model]
import BoxStyle exposing [BoxStyle, border]
import ansi.Core

renderScreenPrompt = \text -> Core.drawText text { r: 1, c: 2, fg: Standard White }
renderExitPrompt = \screen -> Core.drawText " Ctrl+C TO QUIT " { r: 0, c: screen.width - 18, fg: Standard Red }
renderControlsPrompt = \text, screen -> Core.drawText text { r: screen.height - 1, c: 2, fg: Standard Cyan }
renderOuterBorder = \screen -> renderBox 0 0 screen.width screen.height (CustomBorder { tl: "╒", t: "═", tr: "╕" }) (Standard Cyan)

UiActions : [SingleSelect, MuitiSelect, MultiConfirm, GoBack, Search, SearchGo, PrevPage, NextPage, Cancel, Finish]

getActions : Model -> List UiActions
getActions = \model ->
    when model.state is
        PlatformSelect _ ->
            [SingleSelect, Search]
            |> \actions -> if Model.isNotFirstPage model then List.append actions PrevPage else actions
            |> \actions -> if Model.isNotLastPage model then List.append actions NextPage else actions
        PackageSelect _ ->
            [MuitiSelect, MultiConfirm, GoBack]
            |> \actions -> if Model.isNotFirstPage model then List.append actions PrevPage else actions
            |> \actions -> if Model.isNotLastPage model then List.append actions NextPage else actions
        Confirmation _ -> [Finish, GoBack]
        SearchPage _ -> [SearchGo, Cancel]
        _ -> []

controlPromptsDict = Dict.empty {}
    |> Dict.insert SingleSelect "ENTER TO SELECT"
    |> Dict.insert MuitiSelect "SPACE TO SELECT"
    |> Dict.insert MultiConfirm "ENTER TO CONFIRM"
    |> Dict.insert GoBack "BKSP TO GO BACK"
    |> Dict.insert Search "S TO SEARCH"
    |> Dict.insert SearchGo "ENTER TO SEARCH"
    |> Dict.insert Cancel "ESC TO CANCEL"
    |> Dict.insert Finish "ENTER TO FINISH"
    |> Dict.insert PrevPage "< PREV"
    |> Dict.insert NextPage "> NEXT"


controlPromptsShortDict = Dict.empty {}
    |> Dict.insert SingleSelect "ENTER"
    |> Dict.insert MuitiSelect "SPACE"
    |> Dict.insert MultiConfirm "ENTER"
    |> Dict.insert GoBack "BKSP"
    |> Dict.insert Search "S"
    |> Dict.insert SearchGo "ENTER"
    |> Dict.insert Cancel "ESC"
    |> Dict.insert Finish "ENTER"
    |> Dict.insert PrevPage "<"
    |> Dict.insert NextPage ">"

controlsPromptStr = \model ->
    actions = getActions model
    promptsDict = if model.screen.width // Num.toI32 (List.len actions) < 20 then controlPromptsShortDict else controlPromptsDict
    actionStrs = getActions model
        |> List.map \action ->
            Dict.get promptsDict action |> Result.withDefault ""
    " $(Str.joinWith actionStrs " | ") "

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
            Core.drawCursor { fg: Standard Magenta, char: ">"},
        ],
        renderMultipleChoiceMenu model,

    ]

renderSearchPage : Model -> List Core.DrawFn
renderSearchPage = \model ->
    when model.state is
        SearchPage { sender, searchBuffer } ->
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
                    Core.drawText (searchBuffer |> Str.fromUtf8 |> Result.withDefault "") { r: 2, c: 4, fg: Standard White },
                ],
            ]

        _ -> []

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
                    Core.drawText "Platform:" { r: 2, c: 2, fg: Standard Magenta },
                    Core.drawText config.platform { r: 2, c: 12, fg: Standard White },
                    Core.drawText "Packages:" { r: 3, c: 2, fg: Standard Magenta },
                    Core.drawText (config.packages |> Str.joinWith ", ") { r: 3, c: 12, fg: Standard White },
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

renderMenu = \model ->
    item, idx <- List.mapWithIndex model.menu
    row = Num.toI32 idx + model.menuRow
    if model.cursor.row == row then
        Core.drawText "> $(item)" { r: row, c: 2, fg: Standard Magenta }
    else
        Core.drawText "- $(item)" { r: row, c: 2, fg: Default }

renderMultipleChoiceMenu = \model ->
    isSelected = \menuIdx -> List.contains model.selected (Model.menuIdxToFullIdx menuIdx model)
    checkedItems = List.mapWithIndex model.menu \item, idx -> if isSelected idx then "[X] $(item)" else "[ ] $(item)"
    item, idx <- List.mapWithIndex checkedItems
    row = Num.toI32 idx + model.menuRow
    if model.cursor.row == row then
        Core.drawText "> $(item)" { r: row, c: 2, fg: Standard Magenta }
    else
        Core.drawText "- $(item)" { r: row, c: 2, fg: Default }
