module [
    Model,
    init,
    main_menu,
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
    paginate,
    add_selected_packages_to_config,
    clear_search_filter,
    append_to_buffer,
    backspace_buffer,
    clear_buffer,
    toggle_selected,
    next_page,
    prev_page,
    move_cursor,
]

import Utils
import Choices exposing [Choices]
import State exposing [State]
import UserAction exposing [UserAction]
import ansi.ANSI
import repos.Manager as RM exposing [RepositoryRelease]
import rtils.Compare

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
            [Exit, SingleSelect, CursorUp, CursorDown]
            |> with_platform_version(model)
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

        InputAppName(_) ->
            [Exit, TextSubmit, TextInput(None)]
            |> with_go_back_or_backspace(model)

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
            |> List.append(GoBack)

        ChooseFlags(_) ->
            [Exit, MultiSelect, MultiConfirm, CursorUp, CursorDown]
            |> with_prev_page(model)
            |> with_next_page(model)

        Search(_) ->
            [Exit, SearchGo, Cancel, TextInput(None)]
            |> with_go_back_or_backspace(model)

        Splash(_) -> [Exit, Continue]
        _ -> [Exit]

with_search_or_clear_filter = |actions, model| List.append(actions, (if Model.menu_is_filtered(model) then ClearFilter else Search))
with_go_back_or_backspace = |actions, model| List.append(actions, (if Model.get_buffer_len(model) > 0 then TextBackspace else GoBack))
with_platform_version = |actions, model| if Model.get_highlighted_item(model) == "No change" then actions else List.append(actions, VersionSelect)
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

main_menu = ["Start app", "Start package", "Upgrade app", "Upgrade package", "Update roc-start", "Settings", "Exit"]

## Initialize the model
init : Dict Str (List RepositoryRelease), Dict Str (List RepositoryRelease), { state ?? State, theme_names ?? List Str } -> Model
init = |platforms, packages, { state ?? MainMenu({ choices: NothingToDo }), theme_names ?? ["default"] }|
    package_name_map = RM.build_repo_name_map(Dict.keys(packages))
    platform_name_map = RM.build_repo_name_map(Dict.keys(platforms))
    package_menu = build_repo_menu(package_name_map)
    platform_menu = build_repo_menu(platform_name_map)
    {
        screen: { width: 0, height: 0 },
        cursor: { row: 2, col: 2 },
        menu_row: 2,
        page_first_item: 0,
        menu: main_menu,
        full_menu: main_menu,
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

## Split the menu into pages, and adjust the cursor position if necessary
paginate : Model -> Model
paginate = |model|
    max_items =
        Num.sub_checked(model.screen.height, (model.menu_row + 1))
        |> Result.with_default(0)
        |> Num.to_u64
    page_first_item =
        if List.len(model.menu) < max_items and model.page_first_item > 0 then
            idx = Num.to_i64(List.len(model.full_menu)) - Num.to_i64(max_items)
            if idx >= 0 then Num.to_u64(idx) else 0
        else
            model.page_first_item
    menu = List.sublist(model.full_menu, { start: page_first_item, len: max_items })
    cursor_row =
        if model.cursor.row >= model.menu_row + Num.to_u16(List.len(menu)) and List.len(menu) > 0 then
            model.menu_row + Num.to_u16(List.len(menu)) - 1
        else
            model.cursor.row
    cursor = { row: cursor_row, col: model.cursor.col }
    { model & menu, page_first_item, cursor }

## Add the selected packages to the configuration
add_selected_packages_to_config : Model -> Model
add_selected_packages_to_config = |model|
    when model.state is
        PackageSelect(data) ->
            package_repos = Model.get_selected_items(model) |> List.map(Utils.menu_item_to_repo)
            new_choices = data.choices |> Choices.set_packages(package_repos)
            { model & state: PackageSelect({ data & choices: new_choices }) }

        _ -> model

## Clear the search filter
clear_search_filter : Model -> Model
clear_search_filter = |model|
    when model.state is
        PackageSelect(_) ->
            { model &
                full_menu: model.package_menu,
                cursor: { row: 2, col: 2 },
            }

        PlatformSelect({ choices }) ->
            menu =
                when choices is
                    Upgrade(_) -> [["No change"], model.platform_menu] |> List.join
                    _ -> model.platform_menu
            { model &
                full_menu: menu,
                cursor: { row: 2, col: 2 },
            }

        _ -> model

## Append a key to the name or search buffer
append_to_buffer : Model, Str -> Model
append_to_buffer = |model, str|
    when model.state is
        Search({ search_buffer, choices, prior_sender }) ->
            new_buffer = List.concat(search_buffer, (Utils.str_to_slug(str) |> Str.to_utf8))
            { model & state: Search({ choices, search_buffer: new_buffer, prior_sender }) }

        InputAppName({ name_buffer, choices }) ->
            new_buffer = List.concat(name_buffer, (Utils.str_to_slug(str) |> Str.to_utf8))
            { model & state: InputAppName({ choices, name_buffer: new_buffer }) }

        _ -> model

## Remove the last character from the name or search buffer
backspace_buffer : Model -> Model
backspace_buffer = |model|
    when model.state is
        Search({ search_buffer, choices, prior_sender }) ->
            new_buffer = List.drop_last(search_buffer, 1)
            { model & state: Search({ choices, search_buffer: new_buffer, prior_sender }) }

        InputAppName({ name_buffer, choices }) ->
            new_buffer = List.drop_last(name_buffer, 1)
            { model & state: InputAppName({ choices, name_buffer: new_buffer }) }

        _ -> model

## Clear the search buffer
clear_buffer : Model -> Model
clear_buffer = |model|
    when model.state is
        Search({ choices, prior_sender }) ->
            { model & state: Search({ choices, search_buffer: [], prior_sender }) }

        InputAppName({ choices }) ->
            { model & state: InputAppName({ choices, name_buffer: [] }) }

        _ -> model

## Toggle the selected state of an item in a multi-select menu
toggle_selected : Model -> Model
toggle_selected = |model|
    item = Model.get_highlighted_item(model)
    if List.contains(model.selected, item) then
        { model & selected: List.drop_if(model.selected, |i| i == item) }
    else
        { model & selected: List.append(model.selected, item) }

## Move to the next page if possible
next_page : Model -> Model
next_page = |model|
    max_items = model.screen.height - (model.menu_row + 1) |> Num.to_u64
    if Model.is_not_last_page(model) then
        page_first_item = model.page_first_item + max_items
        menu = List.sublist(model.full_menu, { start: page_first_item, len: max_items })
        cursor = { row: model.menu_row, col: model.cursor.col }
        { model & menu, page_first_item, cursor }
    else
        model

## Move to the previous page if possible
prev_page : Model -> Model
prev_page = |model|
    max_items = model.screen.height - (model.menu_row + 1) |> Num.to_u64
    if Model.is_not_first_page(model) then
        page_first_item = if (Num.to_i64(model.page_first_item) - Num.to_i64(max_items)) > 0 then model.page_first_item - max_items else 0
        menu = List.sublist(model.full_menu, { start: page_first_item, len: max_items })
        cursor = { row: model.menu_row, col: model.cursor.col }
        { model & menu, page_first_item, cursor }
    else
        model

## Move the cursor up or down
move_cursor : Model, [Up, Down] -> Model
move_cursor = |model, direction|
    if List.len(model.menu) > 0 then
        when direction is
            Up ->
                if model.cursor.row <= Num.to_u16(model.menu_row) then
                    { model & cursor: { row: Num.to_u16(List.len(model.menu)) + model.menu_row - 1, col: model.cursor.col } }
                else
                    { model & cursor: { row: model.cursor.row - 1, col: model.cursor.col } }

            Down ->
                if model.cursor.row >= Num.to_u16((List.len(model.menu) - 1)) + Num.to_u16(model.menu_row) then
                    { model & cursor: { row: Num.to_u16(model.menu_row), col: model.cursor.col } }
                else
                    { model & cursor: { row: model.cursor.row + 1, col: model.cursor.col } }
    else
        model
