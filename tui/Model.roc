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
    fullIdxToMenuIdx,
    appendToBuffer,
    backspaceBuffer,
    clearSearchBuffer,
    toggleSelected,
    toInputAppNameState,
    toPackageSelectState,
    toPlatformSelectState,
    toFinishedState,
    toSearchPageState,
    toConfirmationState,
    clearSearchFilter,
]

import ansi.Core
import Keys exposing [Key]
import Repos exposing [RepositoryEntry]

Model : {
    screen : Core.ScreenSize,
    cursor : Core.Position,
    menuRow : I32,
    pageFirstItem: U64,
    menu : List Str,
    fullMenu : List Str,
    selected : List Str,
    inputs : List Core.Input,
    packageRepoDict : Dict Str RepositoryEntry,
    platformRepoDict : Dict Str RepositoryEntry,
    state : [
        InputAppName { nameBuffer : List U8, config : Configuration },
        PlatformSelect { config : Configuration },
        PackageSelect { config : Configuration },
        Confirmation { config : Configuration },
        SearchPage { searchBuffer : List U8, config : Configuration, sender : [Platform, Package] },
        UserExited,
        Finished { config : Configuration },
    ],
}

Configuration : {
    appName : Str,
    platform : Str,
    packages : List Str,
}

emptyConfig = { appName: "", platform: "", packages: [] }

init : Dict Str RepositoryEntry, Dict Str RepositoryEntry -> Model
init = \platformRepoDict, packageRepoDict -> {
    screen: { width: 0, height: 0 },
    cursor: { row: 2, col: 2 },
    menuRow: 2,
    pageFirstItem: 0,
    menu: Dict.keys platformRepoDict,
    fullMenu: Dict.keys platformRepoDict,
    platformRepoDict,
    packageRepoDict,
    selected: [],
    inputs: List.withCapacity 1000,
    state: InputAppName { nameBuffer: [], config: emptyConfig }
}

paginate: Model -> Model
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
        if model.cursor.row >= model.menuRow + Num.toI32 (List.len menu) then
            model.menuRow + Num.toI32 (List.len menu) - 1
        else
            model.cursor.row
    cursor = { row: curRow, col: model.cursor.col }
    { model & menu, pageFirstItem, cursor }

nextPage: Model -> Model
nextPage = \model ->
    maxItems = model.screen.height - (model.menuRow + 1) |> Num.toU64
    if isNotLastPage model then
        pageFirstItem = model.pageFirstItem + maxItems
        menu = List.sublist model.fullMenu { start: pageFirstItem, len: maxItems }
        cursor = { row: model.menuRow, col: model.cursor.col }
        paginate { model & menu, pageFirstItem, cursor }
    else
        model

prevPage: Model -> Model
prevPage = \model ->
    maxItems = model.screen.height - (model.menuRow + 1) |> Num.toU64
    if isNotFirstPage model then
        pageFirstItem = if (Num.toI64 model.pageFirstItem - Num.toI64 maxItems) > 0 then model.pageFirstItem - maxItems else 0
        menu = List.sublist model.fullMenu { start: pageFirstItem, len: maxItems }
        cursor = { row: model.menuRow, col: model.cursor.col }
        paginate { model & menu, pageFirstItem, cursor }
    else
        model

isNotFirstPage : Model -> Bool
isNotFirstPage = \model -> model.pageFirstItem > 0

isNotLastPage : Model -> Bool
isNotLastPage = \model ->
    maxItems = model.screen.height - (model.menuRow + 1) |> Num.toU64
    model.pageFirstItem + maxItems < List.len model.fullMenu


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

toInputAppNameState : Model -> Model
toInputAppNameState = \model ->
    when model.state is
        PlatformSelect { config } ->
            { model &
                cursor: { row: 2, col: 2 },
                state: InputAppName { config, nameBuffer: config.appName |> Str.toUtf8 },
            }
        _ -> model

toPlatformSelectState : Model -> Model
toPlatformSelectState = \model ->
    when model.state is
        InputAppName { config, nameBuffer } ->
            appName = nameBuffer |> Str.fromUtf8 |> Result.withDefault "main" |> \name -> if Str.isEmpty name then "main" else name
            newConfig = { config & appName }
            { model &
                cursor: { row: 2, col: 2 },
                state: PlatformSelect { config: newConfig },
            } |> paginate
        SearchPage { config, searchBuffer } ->
            { model &
                fullMenu: model.platformRepoDict |> Dict.keys |> List.keepIf \item -> Str.contains item (searchBuffer |> Str.fromUtf8 |> Result.withDefault ""),
                cursor: { row: 2, col: 2 },
                state: PlatformSelect { config },
            } |> paginate
        PackageSelect { config } ->
            configWithPackages = when (addSelectedPackagesToConfig model).state is
                PackageSelect data -> data.config
                _ -> config
            { model &
                pageFirstItem: 0,
                fullMenu: model.platformRepoDict |> Dict.keys,
                cursor: { row: 2, col: 2 },
                state: PlatformSelect { config: configWithPackages }
            } |> paginate
        _ ->
            { model &
                menu: model.platformRepoDict |> Dict.keys,
                cursor: { row: 2, col: 2 },
                state: PlatformSelect { config: { platform: "", appName: "", packages: [] } },
            } |> paginate

toPackageSelectState : Model -> Model
toPackageSelectState = \model ->
    when model.state is
        PlatformSelect { config } ->
            platform = getHighlightedItem model
            { model &
                pageFirstItem: 0,
                fullMenu: model.packageRepoDict |> Dict.keys,
                cursor: { row: 2, col: 2 },
                selected: config.packages,
                state: PackageSelect { config: { config & platform } },
            } |> paginate

        SearchPage { config, searchBuffer } ->
            { model &
                pageFirstItem: 0,
                fullMenu: model.packageRepoDict |> Dict.keys |> List.keepIf \item -> Str.contains item (searchBuffer |> Str.fromUtf8 |> Result.withDefault ""),
                cursor: { row: 2, col: 2 },
                selected: config.packages,
                state: PackageSelect { config },
            } |> paginate

        Confirmation { config } ->
            { model &
                pageFirstItem: 0,
                fullMenu: model.packageRepoDict |> Dict.keys,
                selected: config.packages,
                cursor: { row: 2, col: 2 },
                state: PackageSelect { config },
            } |> paginate

        _ ->
            { model &
                pageFirstItem: 0,
                fullMenu: model.packageRepoDict |> Dict.keys,
                cursor: { row: 2, col: 2 },
                state: PackageSelect { config: { platform: "", appName: "", packages: [] } },
            } |> paginate

toFinishedState : Model -> Model
toFinishedState = \model ->
    modelWithPackages = addSelectedPackagesToConfig model
    when modelWithPackages.state is
        PlatformSelect { config } -> { model & state: Finished { config } }
        PackageSelect { config } -> { model & state: Finished { config } }
        Confirmation { config } -> { model & state: Finished { config } }
        _ -> { model & state: Finished { config: { platform: "", appName: "", packages: [] } } }

toConfirmationState : Model -> Model
toConfirmationState = \model ->
    modelWithPackages = addSelectedPackagesToConfig model
    when modelWithPackages.state is
        PlatformSelect { config } -> { model & state: Confirmation { config } }
        PackageSelect { config } -> { model & state: Confirmation { config } }
        _ -> { model & state: Confirmation { config: { platform: "", appName: "", packages: [] } } }

toSearchPageState : Model -> Model
toSearchPageState = \model ->
    when model.state is
        PlatformSelect { config } ->
            { model &
                cursor: { row: model.menuRow, col: 2 },
                state: SearchPage { config, searchBuffer: [], sender: Platform },
            }

        PackageSelect { config } ->
            newConfig = { config & packages: model.selected }
            { model &
                cursor: { row: model.menuRow, col: 2 },
                state: SearchPage { config: newConfig, searchBuffer: [], sender: Package },
            }

        _ -> model

clearSearchFilter : Model -> Model
clearSearchFilter = \model ->
    when model.state is
        PackageSelect _ ->
            { model &
                fullMenu: model.packageRepoDict |> Dict.keys,
                #cursor: { row: model.menuRow, col: 2 },
            } |> paginate
        PlatformSelect _ ->
            { model &
                fullMenu: model.platformRepoDict |> Dict.keys,
                #cursor: { row: model.menuRow, col: 2 },
            } |> paginate
        _ -> model

appendToBuffer : Model, Key -> Model
appendToBuffer = \model, key ->
    when model.state is
        SearchPage { searchBuffer, config, sender } ->
            newBuffer = List.concat searchBuffer (Keys.keyToSlugStr key |> Str.toUtf8)
            { model & state: SearchPage { config, sender, searchBuffer: newBuffer } }
        InputAppName { nameBuffer, config } ->
            newBuffer = List.concat nameBuffer (Keys.keyToSlugStr key |> Str.toUtf8)
            { model & state: InputAppName { config, nameBuffer: newBuffer } }

        _ -> model

backspaceBuffer : Model -> Model
backspaceBuffer = \model ->
    when model.state is
        SearchPage { searchBuffer, config, sender } ->
            newBuffer = List.dropLast searchBuffer 1
            { model & state: SearchPage { config, sender, searchBuffer: newBuffer } }
        InputAppName { nameBuffer, config } ->
            newBuffer = List.dropLast nameBuffer 1
            { model & state: InputAppName { config, nameBuffer: newBuffer } }

        _ -> model

clearSearchBuffer : Model -> Model
clearSearchBuffer = \model ->
    when model.state is
        SearchPage { config, sender } ->
            { model & state: SearchPage { config, sender, searchBuffer: [] } }

        _ -> model

toggleSelected : Model -> Model
toggleSelected = \model ->
    item = getHighlightedItem model
    if List.contains model.selected item then
        { model & selected: List.dropIf model.selected \i -> i == item }
    else
        { model & selected: List.append model.selected item  }

addSelectedPackagesToConfig : Model -> Model
addSelectedPackagesToConfig = \model ->
    when model.state is
        PackageSelect data ->
            packages = getSelectedItems model
            { model & state: PackageSelect { data & config: { platform: data.config.platform, appName: data.config.appName, packages } } }

        _ -> model

getHighlightedIndex : Model -> U64
getHighlightedIndex = \model -> Num.toU64 model.cursor.row - Num.toU64 model.menuRow

getHighlightedItem : Model -> Str
getHighlightedItem = \model -> List.get model.menu (getHighlightedIndex model) |> Result.withDefault ""

menuIdxToFullIdx : U64, Model -> U64
menuIdxToFullIdx = \idx, model -> idx + model.pageFirstItem

fullIdxToMenuIdx : U64, Model -> U64
fullIdxToMenuIdx = \idx, model -> idx - model.pageFirstItem

getSelectedItems : Model -> List Str
getSelectedItems = \model -> model.selected
