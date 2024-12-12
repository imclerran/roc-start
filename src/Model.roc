module [
    Model,
    emptyAppConfig,
    init,
    isNotFirstPage,
    isNotLastPage,
    getHighlightedIndex,
    getHighlightedItem,
    getSelectedItems,
    menuIsFiltered,
]
    

import ansi.Ansi

Model : {
    screen : Ansi.ScreenSize,
    cursor : Ansi.CursorPosition,
    menuRow : U16,
    pageFirstItem : U64,
    menu : List Str,
    fullMenu : List Str,
    selected : List Str,
    inputs : List Ansi.Input,
    packageList : List Str,
    platformList : List Str,
    state : State,
}

State: [
    TypeSelect { config : Configuration },
    InputAppName { nameBuffer : List U8, config : Configuration },
    Search { searchBuffer : List U8, config : Configuration, sender : [Platform, Package] },
    PlatformSelect { config : Configuration },
    PackageSelect { config : Configuration },
    Confirmation { config : Configuration },
    Finished { config : Configuration },
    Splash { config : Configuration },
    UserExited,
]

Configuration : {
    type : [App, Pkg],
    fileName : Str,
    platform : Str,
    packages : List Str,
}

emptyAppConfig = { fileName: "", platform: "", packages: [], type: App }

## Initialize the model
init : List Str, List Str, { state ? State }  -> Model
init = \platformList, packageList, { state ? TypeSelect { config: emptyAppConfig } } -> {
    screen: { width: 0, height: 0 },
    cursor: { row: 2, col: 2 },
    menuRow: 2,
    pageFirstItem: 0,
    menu: ["App", "Package"],
    fullMenu: ["App", "Package"],
    platformList,
    packageList,
    selected: [],
    inputs: List.withCapacity 1000,
    state,
}

## Check if the current page is not the first page
isNotFirstPage : Model -> Bool
isNotFirstPage = \model -> model.pageFirstItem > 0

## Check if the current page is not the last page
isNotLastPage : Model -> Bool
isNotLastPage = \model ->
    maxItems = 
        Num.subChecked (model.screen.height) (model.menuRow + 1)
        |> Result.withDefault 0
        |> Num.toU64
    model.pageFirstItem + maxItems < List.len model.fullMenu

## Get the index of the highlighted item
getHighlightedIndex : Model -> U64
getHighlightedIndex = \model -> Num.toU64 model.cursor.row - Num.toU64 model.menuRow

## Get the highlighted item
getHighlightedItem : Model -> Str
getHighlightedItem = \model -> List.get model.menu (getHighlightedIndex model) |> Result.withDefault ""

## Get the selected items in a multi-select menu
getSelectedItems : Model -> List Str
getSelectedItems = \model -> model.selected

## Check if the menu is currently filtered
menuIsFiltered : Model -> Bool
menuIsFiltered = \model ->
    when model.state is
        PlatformSelect _ -> List.len model.fullMenu < List.len model.platformList
        PackageSelect _ -> List.len model.fullMenu < List.len model.packageList
        _ -> Bool.false
