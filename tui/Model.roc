module [Model, getHighlightedIndex, getHighlightedItem, toPackageSelectState, toPlatformSelectState, toUserSelectedState, toSearchPageState]

import ansi.Core
import Const

Model : {
    screen : Core.ScreenSize,
    cursor : Core.Position,
    menuRow : I32,
    menu : List Str,
    selected : List U64,
    inputs : List Core.Input,
    state : [
        InputAppName { nameBuffer : Str },
        PlatformSelect { config : Configuration },
        PackageSelect { config : Configuration },
        SearchPage { searchBuffer : List U8, config : Configuration, sender : [Platform, Package] },
        UserExited,
        UserSelected { config : Configuration },
    ],
}

Configuration : {
    appName : Str,
    platform : Str,
    packages : List Str,
}

getHighlightedIndex : Model -> U64
getHighlightedIndex = \model -> Num.toU64 model.cursor.row - Num.toU64 model.menuRow

getHighlightedItem : Model -> Str
getHighlightedItem = \model -> List.get model.menu (getHighlightedIndex model) |> Result.withDefault ""

toPlatformSelectState : Model -> Model
toPlatformSelectState = \model ->
    when model.state is
        SearchPage { config, searchBuffer } ->
            { model &
                menu: Const.platformList |> List.keepIf \item -> Str.contains item (searchBuffer |> Str.fromUtf8 |> Result.withDefault ""),
                cursor: { row: 2, col: 2 },
                state: PlatformSelect { config },
            }

        _ ->
            { model &
                menu: Const.platformList,
                cursor: { row: 2, col: 2 },
                state: PlatformSelect { config: { platform: "", appName: "", packages: [] } },
            }

toPackageSelectState : Model -> Model
toPackageSelectState = \model ->
    when model.state is
        PlatformSelect { config } ->
            platform = getHighlightedItem model
            { model &
                menu: Const.packageList,
                cursor: { row: 2, col: 2 },
                state: PackageSelect { config: { config & platform } },
            }

        SearchPage { config, searchBuffer } ->
            { model &
                menu: Const.packageList |> List.keepIf \item -> Str.contains item (searchBuffer |> Str.fromUtf8 |> Result.withDefault ""),
                cursor: { row: 2, col: 2 },
                state: PackageSelect { config },
            }

        _ ->
            { model &
                menu: Const.packageList,
                cursor: { row: 2, col: 2 },
                state: PackageSelect { config: { platform: "", appName: "", packages: [] } },
            }

toUserSelectedState : Model -> Model
toUserSelectedState = \model ->
    modelWithPackages = addSelectedPackagesToConfig model
    when modelWithPackages.state is
        PlatformSelect { config } -> { model & state: UserSelected { config } }
        PackageSelect { config } -> { model & state: UserSelected { config } }
        _ -> { model & state: UserSelected { config: { platform: "", appName: "", packages: [] } } }

toSearchPageState : Model -> Model
toSearchPageState = \model ->
    when model.state is
        PlatformSelect { config } ->
            { model &
                cursor: { row: 2, col: 2 },
                state: SearchPage { config, searchBuffer: [], sender: Platform },
            }

        PackageSelect { config } ->
            { model &
                cursor: { row: 2, col: 2 },
                state: SearchPage { config, searchBuffer: [], sender: Package },
            }

        _ ->
            { model &
                cursor: { row: 2, col: 2 },
                state: SearchPage { config: Const.emptyConfig, searchBuffer: [], sender: Platform },
            }

addSelectedPackagesToConfig : Model -> Model
addSelectedPackagesToConfig = \model ->
    when model.state is
        PackageSelect data ->
            packages = getSelectedItems model
            { model & state: PackageSelect { data & config: { platform: data.config.platform, appName: data.config.appName, packages } } }

        _ -> model

getSelectedItems : Model -> List Str
getSelectedItems = \model ->
    list, item, idx <- List.walkWithIndex model.menu []
    if List.contains model.selected idx then
        List.append list item
    else
        list
