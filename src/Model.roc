module [
    Model,
    init,
    paginate,
    nextPage,
    prevPage,
    isNotFirstPage,
    isNotLastPage,
    moveCursor,
    getHighlightedIndex,
    getHighlightedItem,
    menuIdxToFullIdx,
    appendToBuffer,
    backspaceBuffer,
    clearSearchBuffer,
    toggleSelected,
    toInputAppNameState,
    toPackageSelectState,
    toPlatformSelectState,
    toFinishedState,
    toSearchState,
    toConfirmationState,
    toUserExitedState,
    toSplashState,
    toTypeSelectState,
    clearSearchFilter,
    menuIsFiltered,
]

import Keys exposing [Key]
import ansi.Core

Model : {
    screen : Core.ScreenSize,
    cursor : Core.Position,
    menuRow : I32,
    pageFirstItem : U64,
    menu : List Str,
    fullMenu : List Str,
    selected : List Str,
    inputs : List Core.Input,
    packageList : List Str,
    platformList : List Str,
    state : [
        TypeSelect { config : Configuration },
        InputAppName { nameBuffer : List U8, config : Configuration },
        Search { searchBuffer : List U8, config : Configuration, sender : [Platform, Package] },
        PlatformSelect { config : Configuration },
        PackageSelect { config : Configuration },
        Confirmation { config : Configuration },
        Finished { config : Configuration },
        Splash { config : Configuration },
        UserExited,
    ],
}

Configuration : {
    type : [App, Pkg],
    fileName : Str,
    platform : Str,
    packages : List Str,
}

emptyAppConfig = { fileName: "", platform: "", packages: [], type: App }

## Initialize the model
init : List Str, List Str -> Model
init = \platformList, packageList -> {
    screen: { width: 0, height: 0 },
    cursor: { row: 2, col: 2 },
    menuRow: 2,
    pageFirstItem: 0,
    menu: ["App", "Package"],
    # platformList,
    fullMenu: ["App", "Package"],
    # platformList,
    platformList,
    packageList,
    selected: [],
    inputs: List.withCapacity 1000,
    state: TypeSelect { config: emptyAppConfig },
    # state: InputAppName { nameBuffer: [], config: emptyAppConfig },
}

## Split the menu into pages, and adjust the cursor position if necessary
paginate : Model -> Model
paginate = \model ->
    maxItems = model.screen.height - (model.menuRow + 1) |> Num.toU64
    pageFirstItem =
        if List.len model.menu < maxItems && model.pageFirstItem > 0 then
            idx = Num.toI64 (List.len model.fullMenu) - Num.toI64 maxItems
            if idx >= 0 then Num.toU64 idx else 0
        else
            model.pageFirstItem
    menu = List.sublist model.fullMenu { start: pageFirstItem, len: maxItems }
    curRow =
        if model.cursor.row >= model.menuRow + Num.toI32 (List.len menu) && List.len menu > 0 then
            model.menuRow + Num.toI32 (List.len menu) - 1
        else
            model.cursor.row
    cursor = { row: curRow, col: model.cursor.col }
    { model & menu, pageFirstItem, cursor }

## Move to the next page if possible
nextPage : Model -> Model
nextPage = \model ->
    maxItems = model.screen.height - (model.menuRow + 1) |> Num.toU64
    if isNotLastPage model then
        pageFirstItem = model.pageFirstItem + maxItems
        menu = List.sublist model.fullMenu { start: pageFirstItem, len: maxItems }
        cursor = { row: model.menuRow, col: model.cursor.col }
        paginate { model & menu, pageFirstItem, cursor }
    else
        model

## Move to the previous page if possible
prevPage : Model -> Model
prevPage = \model ->
    maxItems = model.screen.height - (model.menuRow + 1) |> Num.toU64
    if isNotFirstPage model then
        pageFirstItem = if (Num.toI64 model.pageFirstItem - Num.toI64 maxItems) > 0 then model.pageFirstItem - maxItems else 0
        menu = List.sublist model.fullMenu { start: pageFirstItem, len: maxItems }
        cursor = { row: model.menuRow, col: model.cursor.col }
        paginate { model & menu, pageFirstItem, cursor }
    else
        model

## Check if the current page is not the first page
isNotFirstPage : Model -> Bool
isNotFirstPage = \model -> model.pageFirstItem > 0

## Check if the current page is not the last page
isNotLastPage : Model -> Bool
isNotLastPage = \model ->
    maxItems = model.screen.height - (model.menuRow + 1) |> Num.toU64
    model.pageFirstItem + maxItems < List.len model.fullMenu

## Move the cursor up or down
moveCursor : Model, [Up, Down] -> Model
moveCursor = \model, direction ->
    if List.len model.menu > 0 then
        when direction is
            Up ->
                if model.cursor.row <= Num.toI32 (model.menuRow) then
                    { model & cursor: { row: Num.toI32 (List.len model.menu) + model.menuRow - 1, col: model.cursor.col } }
                else
                    { model & cursor: { row: model.cursor.row - 1, col: model.cursor.col } }

            Down ->
                if model.cursor.row >= Num.toI32 (List.len model.menu - 1) + Num.toI32 (model.menuRow) then
                    { model & cursor: { row: Num.toI32 (model.menuRow), col: model.cursor.col } }
                else
                    { model & cursor: { row: model.cursor.row + 1, col: model.cursor.col } }
    else
        model

## Transition to the UserExited state
toUserExitedState : Model -> Model
toUserExitedState = \model -> { model & state: UserExited }

toTypeSelectState : Model -> Model
toTypeSelectState = \model ->
    when model.state is
        InputAppName { config, nameBuffer } ->
            fileName = nameBuffer |> Str.fromUtf8 |> Result.withDefault "main"
            newConfig = { config & fileName }
            { model &
                cursor: { row: 2, col: 2 },
                fullMenu: ["App", "Package"],
                state: TypeSelect { config: newConfig },
            }

        PackageSelect { config } ->
            configWithPackages =
                when (addSelectedPackagesToConfig model).state is
                    PackageSelect data -> data.config
                    _ -> config
            if config.type == Pkg then
                { model &
                    fullMenu: ["App", "Package"],
                    cursor: { row: 2, col: 2 },
                    state: TypeSelect { config: configWithPackages },
                }
            else
                model

        Splash { config } ->
            { model &
                cursor: { row: 2, col: 2 },
                fullMenu: ["App", "Package"],
                state: TypeSelect { config },
            }

        _ -> model

toInputAppNameState : Model -> Model
toInputAppNameState = \model ->
    when model.state is
        TypeSelect { config } ->
            type = getHighlightedItem model |> \str -> if str == "App" then App else Pkg
            { model &
                cursor: { row: 2, col: 2 },
                state: InputAppName { config: { config & type }, nameBuffer: config.fileName |> Str.toUtf8 },
            }

        PlatformSelect { config } ->
            { model &
                cursor: { row: 2, col: 2 },
                state: InputAppName { config, nameBuffer: config.fileName |> Str.toUtf8 },
            }

        Splash { config } ->
            { model &
                cursor: { row: 2, col: 2 },
                state: InputAppName { config, nameBuffer: config.fileName |> Str.toUtf8 },
            }

        _ -> model

toSplashState : Model -> Model
toSplashState = \model ->
    when model.state is
        TypeSelect { config } ->
            { model &
                state: Splash { config },
            }

        _ -> model

## Transition to the PlatformSelect state
toPlatformSelectState : Model -> Model
toPlatformSelectState = \model ->
    when model.state is
        InputAppName { config, nameBuffer } ->
            fileName = nameBuffer |> Str.fromUtf8 |> Result.withDefault "main" |> \name -> if Str.isEmpty name then "main" else name
            newConfig = { config & fileName }
            { model &
                pageFirstItem: 0,
                fullMenu: model.platformList,
                cursor: { row: 2, col: 2 },
                state: PlatformSelect { config: newConfig },
            }
            |> paginate

        Search { config, searchBuffer } ->
            { model &
                fullMenu: model.platformList |> List.keepIf \item -> Str.contains item (searchBuffer |> Str.fromUtf8 |> Result.withDefault ""),
                cursor: { row: 2, col: 2 },
                state: PlatformSelect { config },
            }
            |> paginate

        PackageSelect { config } ->
            configWithPackages =
                when (addSelectedPackagesToConfig model).state is
                    PackageSelect data -> data.config
                    _ -> config
            { model &
                pageFirstItem: 0,
                fullMenu: model.platformList,
                cursor: { row: 2, col: 2 },
                state: PlatformSelect { config: configWithPackages },
            }
            |> paginate

        _ -> model

## To the PackageSelect state
toPackageSelectState : Model -> Model
toPackageSelectState = \model ->
    when model.state is
        TypeSelect { config } ->
            type = getHighlightedItem model |> \str -> if str == "App" then App else Pkg
            fileName = "main"
            { model &
                pageFirstItem: 0,
                fullMenu: model.packageList,
                cursor: { row: 2, col: 2 },
                selected: config.packages,
                state: PackageSelect { config: { config & type, fileName } },
            }

        PlatformSelect { config } ->
            platform = getHighlightedItem model
            { model &
                pageFirstItem: 0,
                fullMenu: model.packageList,
                cursor: { row: 2, col: 2 },
                selected: config.packages,
                state: PackageSelect { config: { config & platform } },
            }
            |> paginate

        Search { config, searchBuffer } ->
            { model &
                pageFirstItem: 0,
                fullMenu: model.packageList |> List.keepIf \item -> Str.contains item (searchBuffer |> Str.fromUtf8 |> Result.withDefault ""),
                cursor: { row: 2, col: 2 },
                selected: config.packages,
                state: PackageSelect { config },
            }
            |> paginate

        Confirmation { config } ->
            { model &
                pageFirstItem: 0,
                fullMenu: model.packageList,
                selected: config.packages,
                cursor: { row: 2, col: 2 },
                state: PackageSelect { config },
            }
            |> paginate

        _ -> model

## Transition to the Finished state
toFinishedState : Model -> Model
toFinishedState = \model ->
    modelWithPackages = addSelectedPackagesToConfig model
    when modelWithPackages.state is
        PlatformSelect { config } -> { model & state: Finished { config } }
        PackageSelect { config } -> { model & state: Finished { config } }
        Confirmation { config } -> { model & state: Finished { config } }
        _ -> model

## Transition to the Confirmation state
toConfirmationState : Model -> Model
toConfirmationState = \model ->
    modelWithPackages = addSelectedPackagesToConfig model
    when modelWithPackages.state is
        PlatformSelect { config } -> { model & state: Confirmation { config } }
        PackageSelect { config } -> { model & state: Confirmation { config } }
        _ -> model

## Transition to the Search state
toSearchState : Model -> Model
toSearchState = \model ->
    when model.state is
        PlatformSelect { config } ->
            { model &
                cursor: { row: model.menuRow, col: 2 },
                state: Search { config, searchBuffer: [], sender: Platform },
            }

        PackageSelect { config } ->
            newConfig = { config & packages: model.selected }
            { model &
                cursor: { row: model.menuRow, col: 2 },
                state: Search { config: newConfig, searchBuffer: [], sender: Package },
            }

        _ -> model

## Clear the search filter
clearSearchFilter : Model -> Model
clearSearchFilter = \model ->
    when model.state is
        PackageSelect _ ->
            { model &
                fullMenu: model.packageList,
                # cursor: { row: model.menuRow, col: 2 },
            }
            |> paginate

        PlatformSelect _ ->
            { model &
                fullMenu: model.platformList,
                # cursor: { row: model.menuRow, col: 2 },
            }
            |> paginate

        _ -> model

## Append a key to the name or search buffer
appendToBuffer : Model, Key -> Model
appendToBuffer = \model, key ->
    when model.state is
        Search { searchBuffer, config, sender } ->
            newBuffer = List.concat searchBuffer (Keys.keyToSlugStr key |> Str.toUtf8)
            { model & state: Search { config, sender, searchBuffer: newBuffer } }

        InputAppName { nameBuffer, config } ->
            newBuffer = List.concat nameBuffer (Keys.keyToSlugStr key |> Str.toUtf8)
            { model & state: InputAppName { config, nameBuffer: newBuffer } }

        _ -> model

## Remove the last character from the name or search buffer
backspaceBuffer : Model -> Model
backspaceBuffer = \model ->
    when model.state is
        Search { searchBuffer, config, sender } ->
            newBuffer = List.dropLast searchBuffer 1
            { model & state: Search { config, sender, searchBuffer: newBuffer } }

        InputAppName { nameBuffer, config } ->
            newBuffer = List.dropLast nameBuffer 1
            { model & state: InputAppName { config, nameBuffer: newBuffer } }

        _ -> model

## Clear the search buffer
clearSearchBuffer : Model -> Model
clearSearchBuffer = \model ->
    when model.state is
        Search { config, sender } ->
            { model & state: Search { config, sender, searchBuffer: [] } }

        _ -> model

## Toggle the selected state of an item in a multi-select menu
toggleSelected : Model -> Model
toggleSelected = \model ->
    item = getHighlightedItem model
    if List.contains model.selected item then
        { model & selected: List.dropIf model.selected \i -> i == item }
    else
        { model & selected: List.append model.selected item }

## Add the selected packages to the configuration
addSelectedPackagesToConfig : Model -> Model
addSelectedPackagesToConfig = \model ->
    when model.state is
        PackageSelect data ->
            packages = getSelectedItems model
            { model &
                state: PackageSelect
                    { data &
                        config: {
                            platform: data.config.platform,
                            fileName: data.config.fileName,
                            packages,
                            type: data.config.type,
                        },
                    },
            }

        _ -> model

## Get the index of the highlighted item
getHighlightedIndex : Model -> U64
getHighlightedIndex = \model -> Num.toU64 model.cursor.row - Num.toU64 model.menuRow

## Get the highlighted item
getHighlightedItem : Model -> Str
getHighlightedItem = \model -> List.get model.menu (getHighlightedIndex model) |> Result.withDefault ""

## Convert the index of an item in the menu to the index in the full menu
menuIdxToFullIdx : U64, Model -> U64
menuIdxToFullIdx = \idx, model -> idx + model.pageFirstItem

## Get the selected items in a multi-select menu
getSelectedItems : Model -> List Str
getSelectedItems = \model -> model.selected

menuIsFiltered : Model -> Bool
menuIsFiltered = \model ->
    when model.state is
        PlatformSelect _ -> List.len model.fullMenu < List.len model.platformList
        PackageSelect _ -> List.len model.fullMenu < List.len model.packageList
        _ -> Bool.false
