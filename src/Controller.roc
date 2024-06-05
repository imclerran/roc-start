module [UserAction, getActions, applyAction]

import Keys exposing [Key]
import Model exposing [Model]

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
    TextConfirm,
    None,
]

getActions : Model -> List UserAction
getActions = \model ->
    when model.state is
        PlatformSelect _ ->
            [Exit, SingleSelect, CursorUp, CursorDown]
            |> \actions -> if
                    List.len model.fullMenu < List.len model.platformList
                then
                    List.append actions ClearFilter
                else
                    List.append actions Search
            |> List.append GoBack
            |> \actions -> if Model.isNotFirstPage model then List.append actions PrevPage else actions
            |> \actions -> if Model.isNotLastPage model then List.append actions NextPage else actions

        PackageSelect _ ->
            [Exit, MultiSelect, MultiConfirm, CursorUp, CursorDown]
            |> \actions -> if
                    List.len model.fullMenu < List.len model.packageList
                then
                    List.append actions ClearFilter
                else
                    List.append actions Search
            |> List.append GoBack
            |> \actions -> if Model.isNotFirstPage model then List.append actions PrevPage else actions
            |> \actions -> if Model.isNotLastPage model then List.append actions NextPage else actions

        Confirmation _ -> [Exit, Finish, GoBack]
        InputAppName _ -> [Exit, TextConfirm, TextInput, TextBackspace]
        Search _ -> [Exit, SearchGo, Cancel, TextInput, TextBackspace]
        _ -> [Exit]

applyAction : { model : Model, action : UserAction, keyPress ? [KeyPress Key, None] } -> [Step Model, Done Model]
applyAction = \{ model, action, keyPress ? None } ->
    if actionIsAvailable model action then
        when model.state is
            InputAppName _ -> inputAppName model action { keyPress }
            PlatformSelect _ -> platformSelect model action
            PackageSelect _ -> packageSelect model action
            Confirmation _ -> confirmation model action
            Search { sender } -> searchActionHandler model action { sender, keyPress }
            _ -> Step model
    else
        Step model

actionIsAvailable : Model, UserAction -> Bool
actionIsAvailable = \model, action -> List.contains (getActions model) action

platformSelect : Model, UserAction -> [Step Model, Done Model]
platformSelect = \model, action ->
    when action is
        Exit -> Done (Model.toUserExitedState model)
        Search -> Step (Model.toSearchState model)
        SingleSelect -> Step (Model.toPackageSelectState model)
        CursorUp -> Step (Model.moveCursor model Up)
        CursorDown -> Step (Model.moveCursor model Down)
        GoBack -> Step (Model.toInputAppNameState model)
        ClearFilter -> Step (Model.clearSearchFilter model)
        NextPage -> Step (Model.nextPage model)
        PrevPage -> Step (Model.prevPage model)
        _ -> Step model

packageSelect : Model, UserAction -> [Step Model, Done Model]
packageSelect = \model, action ->
    when action is
        Exit -> Done (Model.toUserExitedState model)
        Search -> Step (Model.toSearchState model)
        MultiConfirm -> Step (Model.toConfirmationState model)
        MultiSelect -> Step (Model.toggleSelected model)
        CursorUp -> Step (Model.moveCursor model Up)
        CursorDown -> Step (Model.moveCursor model Down)
        GoBack -> Step (Model.toPlatformSelectState model)
        ClearFilter -> Step (Model.clearSearchFilter model)
        NextPage -> Step (Model.nextPage model)
        PrevPage -> Step (Model.prevPage model)
        _ -> Step model

searchActionHandler : Model, UserAction, { sender : [Platform, Package], keyPress ? [KeyPress Key, None] } -> [Step Model, Done Model]
searchActionHandler = \model, action, { sender, keyPress ? None } ->
    when action is
        Exit -> Done (Model.toUserExitedState model)
        SearchGo ->
            when sender is
                Platform -> Step (Model.toPlatformSelectState model)
                Package -> Step (Model.toPackageSelectState model)

        TextBackspace -> Step (Model.backspaceBuffer model)
        TextInput ->
            when keyPress is
                KeyPress key -> Step (Model.appendToBuffer model key)
                None -> Step model

        Cancel ->
            when sender is
                Platform -> Step (model |> Model.clearSearchBuffer |> Model.toPlatformSelectState)
                Package -> Step (model |> Model.clearSearchBuffer |> Model.toPackageSelectState)

        _ -> Step model

inputAppName : Model, UserAction, { keyPress ? [KeyPress Key, None] } -> [Step Model, Done Model]
inputAppName = \model, action, { keyPress ? None } ->
    when action is
        Exit -> Done (Model.toUserExitedState model)
        TextConfirm -> Step (Model.toPlatformSelectState model)
        TextInput ->
            when keyPress is
                KeyPress key -> Step (Model.appendToBuffer model key)
                None -> Step model

        TextBackspace -> Step (Model.backspaceBuffer model)
        _ -> Step model

confirmation : Model, UserAction -> [Step Model, Done Model]
confirmation = \model, action ->
    when action is
        Exit -> Done (Model.toUserExitedState model)
        Finish -> Done (Model.toFinishedState model)
        GoBack -> Step (Model.toPackageSelectState model)
        _ -> Step model
