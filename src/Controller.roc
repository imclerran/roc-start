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
    Secret,
    None,
]

getActions : Model -> List UserAction
getActions = \model ->
    when model.state is
        PlatformSelect _ ->
            [Exit, SingleSelect, CursorUp, CursorDown]
            |> \actions -> if
                    Model.menuIsFiltered model
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
                    Model.menuIsFiltered model
                then
                    List.append actions ClearFilter
                else
                    List.append actions Search
            |> List.append GoBack
            |> \actions -> if Model.isNotFirstPage model then List.append actions PrevPage else actions
            |> \actions -> if Model.isNotLastPage model then List.append actions NextPage else actions

        Confirmation _ -> [Exit, Finish, GoBack]
        InputAppName _ -> [Exit, TextConfirm, TextInput, TextBackspace, Secret]
        Search _ -> [Exit, SearchGo, Cancel, TextInput, TextBackspace]
        Splash _ -> [Exit, GoBack]
        _ -> [Exit]

applyAction : { model : Model, action : UserAction, keyPress ? [KeyPress Key, None] } -> [Step Model, Done Model]
applyAction = \{ model, action, keyPress ? None } ->
    if actionIsAvailable model action then
        when model.state is
            InputAppName _ -> inputAppNameHandler model action { keyPress }
            PlatformSelect _ -> platformSelectHandler model action
            PackageSelect _ -> packageSelectHandler model action
            Confirmation _ -> confirmationHandler model action
            Search { sender } -> searchHandler model action { sender, keyPress }
            Splash _ -> splashHandler model action
            _ -> Step model
    else
        Step model

actionIsAvailable : Model, UserAction -> Bool
actionIsAvailable = \model, action -> List.contains (getActions model) action

platformSelectHandler : Model, UserAction -> [Step Model, Done Model]
platformSelectHandler = \model, action ->
    when action is
        Exit -> Done (Model.toUserExitedState model)
        Search -> Step (Model.toSearchState model)
        SingleSelect -> Step (Model.toPackageSelectState model)
        CursorUp -> Step (Model.moveCursor model Up)
        CursorDown -> Step (Model.moveCursor model Down)
        GoBack ->
            if Model.menuIsFiltered model then
                Step (Model.clearSearchFilter model)
            else
                Step (Model.toInputAppNameState model)

        ClearFilter -> Step (Model.clearSearchFilter model)
        NextPage -> Step (Model.nextPage model)
        PrevPage -> Step (Model.prevPage model)
        _ -> Step model

packageSelectHandler : Model, UserAction -> [Step Model, Done Model]
packageSelectHandler = \model, action ->
    when action is
        Exit -> Done (Model.toUserExitedState model)
        Search -> Step (Model.toSearchState model)
        MultiConfirm -> Step (Model.toConfirmationState model)
        MultiSelect -> Step (Model.toggleSelected model)
        CursorUp -> Step (Model.moveCursor model Up)
        CursorDown -> Step (Model.moveCursor model Down)
        GoBack ->
            if Model.menuIsFiltered model then
                Step (Model.clearSearchFilter model)
            else
                Step (Model.toPlatformSelectState model)

        ClearFilter -> Step (Model.clearSearchFilter model)
        NextPage -> Step (Model.nextPage model)
        PrevPage -> Step (Model.prevPage model)
        _ -> Step model

searchHandler : Model, UserAction, { sender : [Platform, Package], keyPress ? [KeyPress Key, None] } -> [Step Model, Done Model]
searchHandler = \model, action, { sender, keyPress ? None } ->
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

inputAppNameHandler : Model, UserAction, { keyPress ? [KeyPress Key, None] } -> [Step Model, Done Model]
inputAppNameHandler = \model, action, { keyPress ? None } ->
    when action is
        Exit -> Done (Model.toUserExitedState model)
        TextConfirm -> Step (Model.toPlatformSelectState model)
        TextInput ->
            when keyPress is
                KeyPress key -> Step (Model.appendToBuffer model key)
                None -> Step model
        Secret -> Step (Model.toSplashState model)

        TextBackspace -> Step (Model.backspaceBuffer model)
        _ -> Step model

confirmationHandler : Model, UserAction -> [Step Model, Done Model]
confirmationHandler = \model, action ->
    when action is
        Exit -> Done (Model.toUserExitedState model)
        Finish -> Done (Model.toFinishedState model)
        GoBack -> Step (Model.toPackageSelectState model)
        _ -> Step model

splashHandler : Model, UserAction -> [Step Model, Done Model]
splashHandler = \model, action ->
    when action is
        Exit -> Done (Model.toUserExitedState model)
        GoBack -> Step (Model.toInputAppNameState model)
        _ -> Step model
