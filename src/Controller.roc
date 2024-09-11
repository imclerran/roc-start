module [UserAction, getActions, applyAction, actionIsAvailable, paginate]

import Keys exposing [Key]
import Model exposing [Model]
import Utils

UserAction : [
    Cancel,
    ClearFilter,
    CursorDown,
    CursorUp,
    Exit,
    Finish,
    GoBack,
    MultiConfirm,
    MultiSelect,
    NextPage,
    PrevPage,
    Search,
    SearchGo,
    SingleSelect,
    TextInput,
    TextBackspace,
    TextSubmit,
    Secret,
    None,
]

## Get the available actions for the current state
getActions : Model -> List UserAction
getActions = \model ->
    when model.state is
        PlatformSelect _ ->
            [Exit, SingleSelect, CursorUp, CursorDown]
            |> \actions -> List.append actions (if Model.menuIsFiltered model then ClearFilter else Search)
            |> List.append GoBack
            |> \actions -> if Model.isNotFirstPage model then List.append actions PrevPage else actions
            |> \actions -> if Model.isNotLastPage model then List.append actions NextPage else actions

        PackageSelect _ ->
            [Exit, MultiSelect, MultiConfirm, CursorUp, CursorDown]
            |> \actions -> List.append actions (if Model.menuIsFiltered model then ClearFilter else Search)
            |> List.append GoBack
            |> \actions -> if Model.isNotFirstPage model then List.append actions PrevPage else actions
            |> \actions -> if Model.isNotLastPage model then List.append actions NextPage else actions

        TypeSelect _ ->
            [Exit, SingleSelect, CursorUp, CursorDown, Secret]
            |> \actions -> if Model.isNotFirstPage model then List.append actions PrevPage else actions
            |> \actions -> if Model.isNotLastPage model then List.append actions NextPage else actions

        InputAppName { nameBuffer } ->
            [Exit, TextSubmit, TextInput]
            |> \actions -> List.append actions (if List.isEmpty nameBuffer then GoBack else TextBackspace)

        Confirmation _ -> [Exit, Finish, GoBack]
        Search _ -> [Exit, SearchGo, Cancel, TextInput, TextBackspace]
        Splash _ -> [Exit, GoBack]
        _ -> [Exit]

## Check if the user action is available in the current state
actionIsAvailable : Model, UserAction -> Bool
actionIsAvailable = \model, action -> List.contains (getActions model) action

## Translate the user action into a state transition by dispatching to the appropriate handler
applyAction : { model : Model, action : UserAction, keyPress ? Key } -> [Step Model, Done Model]
applyAction = \{ model, action, keyPress ? None } ->
    char = keyPress |> Keys.keyToStr |> \str -> if Str.isEmpty str then None else Char str
    if actionIsAvailable model action then
        when model.state is
            TypeSelect _ -> typeSelectHandler model action
            InputAppName _ -> inputAppNameHandler model action { char }
            PlatformSelect _ -> platformSelectHandler model action
            PackageSelect _ -> packageSelectHandler model action
            Confirmation _ -> confirmationHandler model action
            Search { sender } -> searchHandler model action { sender, char }
            Splash _ -> splashHandler model action
            _ -> defaultHandler model action
    else
        Step model

## Default handler ensures program can always be exited
defaultHandler : Model, UserAction -> [Step Model, Done Model]
defaultHandler = \model, action ->
    when action is
        Exit -> Done (toUserExitedState model)
        _ -> Step model

## Map the user action to the appropriate state transition from the TypeSelect state
typeSelectHandler : Model, UserAction -> [Step Model, Done Model]
typeSelectHandler = \model, action ->
    when action is
        Exit -> Done (toUserExitedState model)
        SingleSelect ->
            type = Model.getHighlightedItem model |> \str -> if str == "App" then App else Pkg
            when type is
                App -> Step (toInputAppNameState model)
                Pkg -> Step (toPackageSelectState model)

        CursorUp -> Step (moveCursor model Up)
        CursorDown -> Step (moveCursor model Down)
        NextPage -> Step (nextPage model)
        PrevPage -> Step (prevPage model)
        Secret -> Step (toSplashState model)
        _ -> Step model

## Map the user action to the appropriate state transition from the PlatformSelect state
platformSelectHandler : Model, UserAction -> [Step Model, Done Model]
platformSelectHandler = \model, action ->
    when action is
        Exit -> Done (toUserExitedState model)
        Search -> Step (toSearchState model)
        SingleSelect -> Step (toPackageSelectState model)
        CursorUp -> Step (moveCursor model Up)
        CursorDown -> Step (moveCursor model Down)
        GoBack ->
            if Model.menuIsFiltered model then
                Step (clearSearchFilter model)
            else
                Step (toInputAppNameState model)

        ClearFilter -> Step (clearSearchFilter model)
        NextPage -> Step (nextPage model)
        PrevPage -> Step (prevPage model)
        _ -> Step model

## Map the user action to the appropriate state transition from the PackageSelect state
packageSelectHandler : Model, UserAction -> [Step Model, Done Model]
packageSelectHandler = \model, action ->
    when action is
        Exit -> Done (toUserExitedState model)
        Search -> Step (toSearchState model)
        MultiConfirm -> Step (toConfirmationState model)
        MultiSelect -> Step (toggleSelected model)
        CursorUp -> Step (moveCursor model Up)
        CursorDown -> Step (moveCursor model Down)
        GoBack ->
            if Model.menuIsFiltered model then
                Step (clearSearchFilter model)
            else
                type =
                    when model.state is
                        PackageSelect { config } -> config.type
                        _ -> App
                when type is
                    App -> Step (toPlatformSelectState model)
                    Pkg -> Step (toTypeSelectState model)

        ClearFilter -> Step (clearSearchFilter model)
        NextPage -> Step (nextPage model)
        PrevPage -> Step (prevPage model)
        _ -> Step model

## Map the user action to the appropriate state transition from the Search state
searchHandler : Model, UserAction, { sender : [Platform, Package], char ? [Char Str, None] } -> [Step Model, Done Model]
searchHandler = \model, action, { sender, char ? None } ->
    when action is
        Exit -> Done (toUserExitedState model)
        SearchGo ->
            when sender is
                Platform -> Step (toPlatformSelectState model)
                Package -> Step (toPackageSelectState model)

        TextBackspace -> Step (backspaceBuffer model)
        TextInput ->
            when char is
                Char c -> Step (appendToBuffer model c)
                None -> Step model

        Cancel ->
            when sender is
                Platform -> Step (model |> clearBuffer |> toPlatformSelectState)
                Package -> Step (model |> clearBuffer |> toPackageSelectState)

        _ -> Step model

## Map the user action to the appropriate state transition from the InputAppName state
inputAppNameHandler : Model, UserAction, { char ? [Char Str, None] } -> [Step Model, Done Model]
inputAppNameHandler = \model, action, { char ? None } ->
    when action is
        Exit -> Done (toUserExitedState model)
        TextSubmit -> Step (toPlatformSelectState model)
        TextInput ->
            when char is
                Char c -> Step (appendToBuffer model c)
                None -> Step model

        TextBackspace -> Step (backspaceBuffer model)
        GoBack -> Step (toTypeSelectState model)
        _ -> Step model

## Map the user action to the appropriate state transition from the Confirmation state
confirmationHandler : Model, UserAction -> [Step Model, Done Model]
confirmationHandler = \model, action ->
    when action is
        Exit -> Done (toUserExitedState model)
        Finish -> Done (toFinishedState model)
        GoBack -> Step (toPackageSelectState model)
        _ -> Step model

## Map the user action to the appropriate state transition from the Splash state
splashHandler : Model, UserAction -> [Step Model, Done Model]
splashHandler = \model, action ->
    when action is
        Exit -> Done (toUserExitedState model)
        GoBack -> Step (toTypeSelectState model)
        _ -> Step model

## Transition to the UserExited state
toUserExitedState : Model -> Model
toUserExitedState = \model -> { model & state: UserExited }

## Transition to the TypeSelect state
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

## Transition to the InputAppName state
toInputAppNameState : Model -> Model
toInputAppNameState = \model ->
    when model.state is
        TypeSelect { config } ->
            type = Model.getHighlightedItem model |> \str -> if str == "App" then App else Pkg
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

## Transition to the Splash state
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
                menu: model.platformList,
                fullMenu: model.platformList,
                cursor: { row: 2, col: 2 },
                state: PlatformSelect { config: newConfig },
            }

        Search { config, searchBuffer } ->
            filteredMenu =
                model.platformList
                |> List.keepIf \item -> Str.contains item (searchBuffer |> Str.fromUtf8 |> Result.withDefault "")
            { model &
                pageFirstItem: 0,
                menu: filteredMenu,
                fullMenu: filteredMenu,
                cursor: { row: 2, col: 2 },
                state: PlatformSelect { config },
            }

        PackageSelect { config } ->
            configWithPackages =
                when (addSelectedPackagesToConfig model).state is
                    PackageSelect data -> data.config
                    _ -> config
            { model &
                pageFirstItem: 0,
                menu: model.platformList,
                fullMenu: model.platformList,
                cursor: { row: 2, col: 2 },
                state: PlatformSelect { config: configWithPackages },
            }

        _ -> model

## Transition to the PackageSelect state
toPackageSelectState : Model -> Model
toPackageSelectState = \model ->
    when model.state is
        TypeSelect { config } ->
            type = Model.getHighlightedItem model |> \str -> if str == "App" then App else Pkg
            fileName = "main"
            { model &
                pageFirstItem: 0,
                menu: model.packageList,
                fullMenu: model.packageList,
                cursor: { row: 2, col: 2 },
                selected: config.packages,
                state: PackageSelect { config: { config & type, fileName } },
            }

        PlatformSelect { config } ->
            platform = Model.getHighlightedItem model
            { model &
                pageFirstItem: 0,
                menu: model.packageList,
                fullMenu: model.packageList,
                cursor: { row: 2, col: 2 },
                selected: config.packages,
                state: PackageSelect { config: { config & platform } },
            }

        Search { config, searchBuffer } ->
            filteredMenu =
                model.packageList
                |> List.keepIf \item -> Str.contains item (searchBuffer |> Str.fromUtf8 |> Result.withDefault "")
            { model &
                pageFirstItem: 0,
                menu: filteredMenu,
                fullMenu: filteredMenu,
                cursor: { row: 2, col: 2 },
                selected: config.packages,
                state: PackageSelect { config },
            }

        Confirmation { config } ->
            { model &
                pageFirstItem: 0,
                menu: model.packageList,
                fullMenu: model.packageList,
                selected: config.packages,
                cursor: { row: 2, col: 2 },
                state: PackageSelect { config },
            }

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

        PlatformSelect _ ->
            { model &
                fullMenu: model.platformList,
                # cursor: { row: model.menuRow, col: 2 },
            }

        _ -> model

## Append a key to the name or search buffer
appendToBuffer : Model, Str -> Model
appendToBuffer = \model, str ->
    when model.state is
        Search { searchBuffer, config, sender } ->
            newBuffer = List.concat searchBuffer (Utils.strToSlug str |> Str.toUtf8)
            { model & state: Search { config, sender, searchBuffer: newBuffer } }

        InputAppName { nameBuffer, config } ->
            newBuffer = List.concat nameBuffer (Utils.strToSlug str |> Str.toUtf8)
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
clearBuffer : Model -> Model
clearBuffer = \model ->
    when model.state is
        Search { config, sender } ->
            { model & state: Search { config, sender, searchBuffer: [] } }

        InputAppName { config } ->
            { model & state: InputAppName { config, nameBuffer: [] } }

        _ -> model

## Toggle the selected state of an item in a multi-select menu
toggleSelected : Model -> Model
toggleSelected = \model ->
    item = Model.getHighlightedItem model
    if List.contains model.selected item then
        { model & selected: List.dropIf model.selected \i -> i == item }
    else
        { model & selected: List.append model.selected item }

## Add the selected packages to the configuration
addSelectedPackagesToConfig : Model -> Model
addSelectedPackagesToConfig = \model ->
    when model.state is
        PackageSelect data ->
            packages = Model.getSelectedItems model
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
        if model.cursor.row >= model.menuRow + Num.toU16 (List.len menu) && List.len menu > 0 then
            model.menuRow + Num.toU16 (List.len menu) - 1
        else
            model.cursor.row
    cursor = { row: curRow, col: model.cursor.col }
    { model & menu, pageFirstItem, cursor }

## Move to the next page if possible
nextPage : Model -> Model
nextPage = \model ->
    maxItems = model.screen.height - (model.menuRow + 1) |> Num.toU64
    if Model.isNotLastPage model then
        pageFirstItem = model.pageFirstItem + maxItems
        menu = List.sublist model.fullMenu { start: pageFirstItem, len: maxItems }
        cursor = { row: model.menuRow, col: model.cursor.col }
        { model & menu, pageFirstItem, cursor }
    else
        model

## Move to the previous page if possible
prevPage : Model -> Model
prevPage = \model ->
    maxItems = model.screen.height - (model.menuRow + 1) |> Num.toU64
    if Model.isNotFirstPage model then
        pageFirstItem = if (Num.toI64 model.pageFirstItem - Num.toI64 maxItems) > 0 then model.pageFirstItem - maxItems else 0
        menu = List.sublist model.fullMenu { start: pageFirstItem, len: maxItems }
        cursor = { row: model.menuRow, col: model.cursor.col }
        { model & menu, pageFirstItem, cursor }
    else
        model

## Move the cursor up or down
moveCursor : Model, [Up, Down] -> Model
moveCursor = \model, direction ->
    if List.len model.menu > 0 then
        when direction is
            Up ->
                if model.cursor.row <= Num.toU16 (model.menuRow) then
                    { model & cursor: { row: Num.toU16 (List.len model.menu) + model.menuRow - 1, col: model.cursor.col } }
                else
                    { model & cursor: { row: model.cursor.row - 1, col: model.cursor.col } }

            Down ->
                if model.cursor.row >= Num.toU16 (List.len model.menu - 1) + Num.toU16 (model.menuRow) then
                    { model & cursor: { row: Num.toU16 (model.menuRow), col: model.cursor.col } }
                else
                    { model & cursor: { row: model.cursor.row + 1, col: model.cursor.col } }
    else
        model
