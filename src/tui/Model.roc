module [
    Model,
    init,
    get_actions,
    action_is_available,
    is_not_first_page,
    is_not_last_page,
    get_highlighted_index,
    get_highlighted_item,
    get_selected_items,
    menu_is_filtered,
    get_choices,
    get_buffer_len,
]

import ansi.ANSI

import rtils.Compare
import Choices exposing [Choices]
import State exposing [State]
import UserAction exposing [UserAction]
import repos.Manager as RM exposing [RepositoryRelease]

Model : {
    screen : ANSI.ScreenSize,
    cursor : ANSI.CursorPosition,
    menu_row : U16,
    page_first_item : U64,
    menu : List Str,
    full_menu : List Str,
    selected : List Str,
    # inputs : List ANSI.Input,
    theme_names : List Str,
    platforms : Dict Str (List RepositoryRelease),
    packages : Dict Str (List RepositoryRelease),
    package_name_map : Dict Str (List Str),
    platform_name_map : Dict Str (List Str),
    package_menu : List Str,
    platform_menu : List Str,
    state : State,
    sender : State,
    # theme : Theme,
    # including theme in model, whether imported from theme module, or redefined internally using Color causes compiler crash
}

## Get the available actions for the current state
get_actions : Model -> List UserAction
get_actions = |model|
    when model.state is
        PlatformSelect(_) ->
            [Exit, SingleSelect]
            |> |actions| if Model.get_highlighted_item(model) == "No change" then actions else List.append(actions, VersionSelect)
            |> |actions| List.join([actions, [CursorUp, CursorDown]])
            |> with_search_or_clear_filter(model)
            |> List.append(GoBack)
            |> with_prev_page(model)
            |> with_next_page(model)

        PackageSelect(_) ->
            [Exit, MultiSelect, VersionSelect, MultiConfirm, CursorUp, CursorDown]
            |> with_search_or_clear_filter(model)
            |> List.append(GoBack)
            |> with_prev_page(model)
            |> with_next_page(model)

        MainMenu(_) ->
            [Exit, SingleSelect, CursorUp, CursorDown, Secret]
            |> with_prev_page(model)
            |> with_next_page(model)

        InputAppName({ name_buffer }) ->
            [Exit, TextSubmit, TextInput(None)]
            |> |actions| List.append(actions, (if List.is_empty(name_buffer) then GoBack else TextBackspace))

        VersionSelect(_) ->
            [Exit, SingleSelect, CursorUp, CursorDown, GoBack]
            |> with_prev_page(model)
            |> with_next_page(model)

        UpdateSelect(_) ->
            [Exit, MultiSelect, MultiConfirm, CursorUp, CursorDown, GoBack]
            |> with_prev_page(model)
            |> with_next_page(model)

        SettingsMenu(_) ->
            [Exit, SingleSelect, CursorUp, CursorDown, GoBack]
            |> with_prev_page(model)
            |> with_next_page(model)

        SettingsSubmenu(_) ->
            [Exit, SingleSelect, CursorUp, CursorDown, GoBack]
            |> with_prev_page(model)
            |> with_next_page(model)

        Confirmation(_) ->
            [Exit, Finish]
            |> with_set_flags(model)
            |> |actions| List.append(actions, GoBack)

        ChooseFlags(_) ->
            [Exit, MultiSelect, MultiConfirm, CursorUp, CursorDown]
            |> with_prev_page(model)
            |> with_next_page(model)

        Search({ search_buffer }) ->
            [Exit, SearchGo, Cancel, TextInput(None)]
            |> |actions| List.append(actions, (if List.is_empty(search_buffer) then GoBack else TextBackspace))

        Splash(_) -> [Exit, GoBack]
        _ -> [Exit]

with_search_or_clear_filter = |actions, model| List.append(actions, (if Model.menu_is_filtered(model) then ClearFilter else Search))
with_prev_page = |actions, model| if Model.is_not_first_page(model) then List.append(actions, PrevPage) else actions
with_next_page = |actions, model| if Model.is_not_last_page(model) then List.append(actions, NextPage) else actions
with_set_flags = |actions, model|
    when Model.get_choices(model) is
        App(_) | Package(_) -> List.append(actions, SetFlags)
        _ -> actions

## Check if the user action is available in the current state
action_is_available : Model, UserAction -> Bool
action_is_available = |model, action|
    actions = get_actions(model)
    when action is
        TextInput(_) -> List.contains(actions, TextInput(None))
        _ -> List.contains(actions, action)

## Initialize the model
init : Dict Str (List RepositoryRelease), Dict Str (List RepositoryRelease), { state ?? State, theme_names ?? List Str } -> Model
init = |platforms, packages, { state ?? MainMenu({ choices: NothingToDo }), theme_names ?? ["default"] }|
    package_name_map = RM.build_repo_name_map(Dict.keys(packages))
    platform_name_map = RM.build_repo_name_map(Dict.keys(platforms))
    package_menu = build_repo_menu(package_name_map)
    platform_menu = build_repo_menu(platform_name_map)
    menu = ["Start app", "Start package", "Upgrade app", "Upgrade package", "Update roc-start", "Settings", "Exit"]
    {
        screen: { width: 0, height: 0 },
        cursor: { row: 2, col: 2 },
        menu_row: 2,
        page_first_item: 0,
        menu: menu,
        full_menu: menu,
        theme_names,
        platforms,
        packages,
        package_name_map,
        platform_name_map,
        platform_menu: platform_menu,
        package_menu: package_menu,
        selected: [],
        state,
        sender: state,
    }

build_repo_menu : Dict Str (List Str) -> List Str
build_repo_menu = |name_map|
    Dict.to_list(name_map)
    |> List.sort_with(|(a, _), (b, _)| Compare.str(a, b))
    |> List.map(
        |(name, owners)|
            when owners is
                [_] -> [name]
                _ -> List.map(owners, |owner| "${name} (${owner})") |> List.sort_with(Compare.str),
    )
    |> List.join

## Check if the current page is not the first page
is_not_first_page : Model -> Bool
is_not_first_page = |model| model.page_first_item > 0

## Check if the current page is not the last page
is_not_last_page : Model -> Bool
is_not_last_page = |model|
    max_items =
        Num.sub_checked(model.screen.height, (model.menu_row + 1))
        |> Result.with_default(0)
        |> Num.to_u64
    model.page_first_item + max_items < List.len(model.full_menu)

## Get the index of the highlighted item
get_highlighted_index : Model -> U64
get_highlighted_index = |model| Num.to_u64(model.cursor.row) - Num.to_u64(model.menu_row)

## Get the highlighted item
get_highlighted_item : Model -> Str
get_highlighted_item = |model| List.get(model.menu, get_highlighted_index(model)) |> Result.with_default("")

## Get the selected items in a multi-select menu
get_selected_items : Model -> List Str
get_selected_items = |model| model.selected

## Check if the menu is currently filtered
menu_is_filtered : Model -> Bool
menu_is_filtered = |model|
    when model.state is
        PlatformSelect(_) -> List.len(model.full_menu) < List.len(model.platform_menu)
        PackageSelect(_) -> List.len(model.full_menu) < List.len(model.package_menu)
        _ -> Bool.false

get_choices : Model -> Choices
get_choices = |model|
    when model.state is
        MainMenu({ choices }) -> choices
        InputAppName({ choices }) -> choices
        SettingsMenu({ choices }) -> choices
        SettingsSubmenu({ choices }) -> choices
        Search({ choices }) -> choices
        PlatformSelect({ choices }) -> choices
        PackageSelect({ choices }) -> choices
        VersionSelect({ choices }) -> choices
        UpdateSelect({ choices }) -> choices
        Confirmation({ choices }) -> choices
        Finished({ choices }) -> choices
        Splash({ choices }) -> choices
        _ -> NothingToDo

get_buffer_len : Model -> U64
get_buffer_len = |model|
    when model.state is
        InputAppName({ name_buffer }) -> List.len(name_buffer)
        Search({ search_buffer }) -> List.len(search_buffer)
        _ -> 0
