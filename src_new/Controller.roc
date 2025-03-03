module [UserAction, get_actions, apply_action, action_is_available, paginate]

import Choices
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
get_actions : Model -> List UserAction
get_actions = |model|
    when model.state is
        PlatformSelect(_) ->
            [Exit, SingleSelect, CursorUp, CursorDown]
            |> |actions| List.append(actions, (if Model.menu_is_filtered(model) then ClearFilter else Search))
            |> List.append(GoBack)
            |> |actions| if Model.is_not_first_page(model) then List.append(actions, PrevPage) else actions
            |> |actions| if Model.is_not_last_page(model) then List.append(actions, NextPage) else actions

        PackageSelect(_) ->
            [Exit, MultiSelect, MultiConfirm, CursorUp, CursorDown]
            |> |actions| List.append(actions, (if Model.menu_is_filtered(model) then ClearFilter else Search))
            |> List.append(GoBack)
            |> |actions| if Model.is_not_first_page(model) then List.append(actions, PrevPage) else actions
            |> |actions| if Model.is_not_last_page(model) then List.append(actions, NextPage) else actions

        TypeSelect(_) ->
            [Exit, SingleSelect, CursorUp, CursorDown, Secret]
            |> |actions| if Model.is_not_first_page(model) then List.append(actions, PrevPage) else actions
            |> |actions| if Model.is_not_last_page(model) then List.append(actions, NextPage) else actions

        InputAppName({ name_buffer }) ->
            [Exit, TextSubmit, TextInput]
            |> |actions| List.append(actions, (if List.is_empty(name_buffer) then GoBack else TextBackspace))

        Confirmation(_) -> [Exit, Finish, GoBack]
        Search(_) -> [Exit, SearchGo, Cancel, TextInput, TextBackspace]
        Splash(_) -> [Exit, GoBack]
        _ -> [Exit]

## Check if the user action is available in the current state
action_is_available : Model, UserAction -> Bool
action_is_available = |model, action| List.contains(get_actions(model), action)

## Translate the user action into a state transition by dispatching to the appropriate handler
apply_action : { model : Model, action : UserAction, key_press ?? Key } -> [Step Model, Done Model]
apply_action = |{ model, action, key_press ?? None }|
    char = key_press |> Keys.key_to_str |> |str| if Str.is_empty(str) then None else Char(str)
    if action_is_available(model, action) then
        when model.state is
            TypeSelect(_) -> type_select_handler(model, action)
            InputAppName(_) -> input_app_name_handler(model, action, { char })
            PlatformSelect(_) -> platform_select_handler(model, action)
            PackageSelect(_) -> package_select_handler(model, action)
            Confirmation(_) -> confirmation_handler(model, action)
            Search({ sender }) -> search_handler(model, action, { sender, char })
            Splash(_) -> splash_handler(model, action)
            _ -> default_handler(model, action)
    else
        Step(model)

## Default handler ensures program can always be exited
default_handler : Model, UserAction -> [Step Model, Done Model]
default_handler = |model, action|
    when action is
        Exit -> Done(to_user_exited_state(model))
        _ -> Step(model)

## Map the user action to the appropriate state transition from the TypeSelect state
type_select_handler : Model, UserAction -> [Step Model, Done Model]
type_select_handler = |model, action|
    when action is
        Exit -> Done(to_user_exited_state(model))
        SingleSelect ->
            type = Model.get_highlighted_item(model) |> |str| if str == "App" then App else Pkg
            when type is
                App -> Step(to_input_app_name_state(model))
                Pkg -> Step(to_package_select_state(model))

        CursorUp -> Step(move_cursor(model, Up))
        CursorDown -> Step(move_cursor(model, Down))
        NextPage -> Step(next_page(model))
        PrevPage -> Step(prev_page(model))
        Secret -> Step(to_splash_state(model))
        _ -> Step(model)

## Map the user action to the appropriate state transition from the PlatformSelect state
platform_select_handler : Model, UserAction -> [Step Model, Done Model]
platform_select_handler = |model, action|
    when action is
        Exit -> Done(to_user_exited_state(model))
        Search -> Step(to_search_state(model))
        SingleSelect -> Step(to_package_select_state(model))
        CursorUp -> Step(move_cursor(model, Up))
        CursorDown -> Step(move_cursor(model, Down))
        GoBack ->
            if Model.menu_is_filtered(model) then
                Step(clear_search_filter(model))
            else
                Step(to_input_app_name_state(model))

        ClearFilter -> Step(clear_search_filter(model))
        NextPage -> Step(next_page(model))
        PrevPage -> Step(prev_page(model))
        _ -> Step(model)

## Map the user action to the appropriate state transition from the PackageSelect state
package_select_handler : Model, UserAction -> [Step Model, Done Model]
package_select_handler = |model, action|
    when action is
        Exit -> Done(to_user_exited_state(model))
        Search -> Step(to_search_state(model))
        MultiConfirm -> Step(to_confirmation_state(model))
        MultiSelect -> Step(toggle_selected(model))
        CursorUp -> Step(move_cursor(model, Up))
        CursorDown -> Step(move_cursor(model, Down))
        GoBack ->
            if Model.menu_is_filtered(model) then
                Step(clear_search_filter(model))
            else
                type =
                    when model.state is
                        PackageSelect({ choices }) -> 
                            when choices is
                                App(_) -> App
                                Package(_) -> Pkg
                                Upgrade(_) -> crash "TODO: Upgrade not yet implemented"
                                _ -> crash "Invalid state... PackageSelect choices should only be of type App, Package, or Upgrade"
                        _ -> App
                when type is
                    App -> Step(to_platform_select_state(model))
                    Pkg -> Step(to_type_select_state(model))

        ClearFilter -> Step(clear_search_filter(model))
        NextPage -> Step(next_page(model))
        PrevPage -> Step(prev_page(model))
        _ -> Step(model)

## Map the user action to the appropriate state transition from the Search state
search_handler : Model, UserAction, { sender : [Platform, Package], char ?? [Char Str, None] } -> [Step Model, Done Model]
search_handler = |model, action, { sender, char ?? None }|
    when action is
        Exit -> Done(to_user_exited_state(model))
        SearchGo ->
            when sender is
                Platform -> Step(to_platform_select_state(model))
                Package -> Step(to_package_select_state(model))

        TextBackspace -> Step(backspace_buffer(model))
        TextInput ->
            when char is
                Char(c) -> Step(append_to_buffer(model, c))
                None -> Step(model)

        Cancel ->
            when sender is
                Platform -> Step((model |> clear_buffer |> to_platform_select_state))
                Package -> Step((model |> clear_buffer |> to_package_select_state))

        _ -> Step(model)

## Map the user action to the appropriate state transition from the InputAppName state
input_app_name_handler : Model, UserAction, { char ?? [Char Str, None] } -> [Step Model, Done Model]
input_app_name_handler = |model, action, { char ?? None }|
    when action is
        Exit -> Done(to_user_exited_state(model))
        TextSubmit -> Step(to_platform_select_state(model))
        TextInput ->
            when char is
                Char(c) -> Step(append_to_buffer(model, c))
                None -> Step(model)

        TextBackspace -> Step(backspace_buffer(model))
        GoBack -> Step(to_type_select_state(model))
        _ -> Step(model)

## Map the user action to the appropriate state transition from the Confirmation state
confirmation_handler : Model, UserAction -> [Step Model, Done Model]
confirmation_handler = |model, action|
    when action is
        Exit -> Done(to_user_exited_state(model))
        Finish -> Done(to_finished_state(model))
        GoBack -> Step(to_package_select_state(model))
        _ -> Step(model)

## Map the user action to the appropriate state transition from the Splash state
splash_handler : Model, UserAction -> [Step Model, Done Model]
splash_handler = |model, action|
    when action is
        Exit -> Done(to_user_exited_state(model))
        GoBack -> Step(to_type_select_state(model))
        _ -> Step(model)

## Transition to the UserExited state
to_user_exited_state : Model -> Model
to_user_exited_state = |model| { model & state: UserExited }

## Transition to the TypeSelect state
to_type_select_state : Model -> Model
to_type_select_state = |model|
    when model.state is
        InputAppName({ choices, name_buffer }) ->
            filename = name_buffer |> Str.from_utf8 |> Result.with_default("main")
            new_choices = choices |> Choices.set_filename(filename)
                #{ choices & file_name }
            { model &
                cursor: { row: 2, col: 2 },
                full_menu: ["App", "Package"],
                state: TypeSelect({ choices: new_choices }),
            }

        PackageSelect({ choices }) ->
            # config_with_packages =
            #     when (add_selected_packages_to_config(model)).state is
            #         PackageSelect(data) -> data.config
            #         _ -> config
            # if config.type == Pkg then
                # { model &
                #     full_menu: ["App", "Package"],
                #     cursor: { row: 2, col: 2 },
                #     state: TypeSelect({ choices: new_choices }),
                # }
            # else
            #     model
            new_choices = choices |> Choices.set_packages(model.selected)
            { model &
                cursor: { row: 2, col: 2 },
                full_menu: ["App", "Package"],
                state: TypeSelect({ choices: new_choices }),
            }


        Splash({ choices }) ->
            { model &
                cursor: { row: 2, col: 2 },
                full_menu: ["App", "Package"],
                state: TypeSelect({ choices }),
            }

        _ -> model

## Transition to the InputAppName state
to_input_app_name_state : Model -> Model
to_input_app_name_state = |model|
    when model.state is
        TypeSelect({ choices }) ->
            type = Model.get_highlighted_item(model) |> |str| if str == "App" then App else Pkg
            when type is
                Pkg -> model
                App -> 
                    new_choices = 
                        when choices is
                            App(_) -> choices
                            Package({ force, packages }) -> App({ filename: "main", force, packages, platform: { name: "basic-cli", version: "latest" } })
                            _ -> App({ filename: "main", force: Bool.false, packages: [], platform: { name: "basic-cli", version: "latest" } })
                    filename = Choices.get_filename(new_choices)
                    { model &
                        cursor: { row: 2, col: 2 },
                        menu: [],
                        full_menu: [],
                        state: InputAppName({ choices: new_choices, name_buffer: filename |> Str.to_utf8 }),
                    }
            # type = Model.get_highlighted_item(model) |> |str| if str == "App" then App else Pkg
            # { model &
            #     cursor: { row: 2, col: 2 },
            #     menu: [],
            #     full_menu: [],
            #     state: InputAppName({ config: { config & type }, name_buffer: config.file_name |> Str.to_utf8 }),
            # }

        PlatformSelect({ choices }) ->
            filename = Choices.get_filename(choices)
            { model &
                cursor: { row: 2, col: 2 },
                menu: [],
                full_menu: [],
                state: InputAppName({ choices, name_buffer: filename |> Str.to_utf8 }),
            }

        Splash({ choices }) ->
            filename = Choices.get_filename(choices)
            { model &
                cursor: { row: 2, col: 2 },
                state: InputAppName({ choices, name_buffer: filename |> Str.to_utf8 }),
            }

        _ -> model

## Transition to the Splash state
to_splash_state : Model -> Model
to_splash_state = |model|
    when model.state is
        TypeSelect({ choices }) ->
            { model &
                state: Splash({ choices }),
            }

        _ -> model

## Transition to the PlatformSelect state
to_platform_select_state : Model -> Model
to_platform_select_state = |model|
    when model.state is
        InputAppName({ choices, name_buffer }) ->
            filename = name_buffer |> Str.from_utf8 |> Result.with_default("main") |> |name| if Str.is_empty(name) then "main" else name
            new_choices = choices |> Choices.set_filename(filename) #{ choices & file_name }
            { model &
                page_first_item: 0,
                menu: model.platform_list,
                full_menu: model.platform_list,
                cursor: { row: 2, col: 2 },
                state: PlatformSelect({ choices: new_choices }),
            }

        Search({ choices, search_buffer }) ->
            filtered_menu =
                model.platform_list
                |> List.keep_if(|item| Str.contains(item, (search_buffer |> Str.from_utf8 |> Result.with_default(""))))
            { model &
                page_first_item: 0,
                menu: filtered_menu,
                full_menu: filtered_menu,
                cursor: { row: 2, col: 2 },
                state: PlatformSelect({ choices }),
            }

        PackageSelect({ choices }) ->
            # config_with_packages =
            #     when (add_selected_packages_to_config(model)).state is
            #         PackageSelect(data) -> data.config
            #         _ -> config
            new_choices = choices |> Choices.set_packages(model.selected)
            { model &
                page_first_item: 0,
                menu: model.platform_list,
                full_menu: model.platform_list,
                cursor: { row: 2, col: 2 },
                state: PlatformSelect({ choices: new_choices }),
            }

        _ -> model

## Transition to the PackageSelect state
to_package_select_state : Model -> Model
to_package_select_state = |model|
    when model.state is
        TypeSelect({ choices }) ->
            type = Model.get_highlighted_item(model) |> |str| if str == "App" then App else Pkg
            when type is
                App -> model
                Pkg ->
                    force = Choices.get_force(choices)
                    packages = Choices.get_packages(choices)
                    new_choices = Package({ force, packages: [] }) |> Choices.set_packages(packages)
                    # file_name = "main"
                    { model &
                        page_first_item: 0,
                        menu: model.package_list,
                        full_menu: model.package_list,
                        cursor: { row: 2, col: 2 },
                        selected: packages,
                        state: PackageSelect({ choices: new_choices }),
                    }

        PlatformSelect({ choices }) ->
            platform = Model.get_highlighted_item(model)
            new_choices = choices |> Choices.set_app_platform(platform)
            { model &
                page_first_item: 0,
                menu: model.package_list,
                full_menu: model.package_list,
                cursor: { row: 2, col: 2 },
                selected: Choices.get_packages(new_choices),
                state: PackageSelect({ choices: new_choices }),
            }

        Search({ choices, search_buffer }) ->
            filtered_menu =
                model.package_list
                |> List.keep_if(|item| Str.contains(item, (search_buffer |> Str.from_utf8 |> Result.with_default(""))))
            { model &
                page_first_item: 0,
                menu: filtered_menu,
                full_menu: filtered_menu,
                cursor: { row: 2, col: 2 },
                selected: Choices.get_packages(choices),
                state: PackageSelect({ choices }),
            }

        Confirmation({ choices }) ->
            { model &
                page_first_item: 0,
                menu: model.package_list,
                full_menu: model.package_list,
                selected: Choices.get_packages(choices),
                cursor: { row: 2, col: 2 },
                state: PackageSelect({ choices }),
            }

        _ -> model

## Transition to the Finished state
to_finished_state : Model -> Model
to_finished_state = |model|
    model_with_packages = add_selected_packages_to_config(model)
    when model_with_packages.state is
        PlatformSelect({ choices }) -> { model & state: Finished({ choices }) }
        PackageSelect({ choices }) -> { model & state: Finished({ choices }) }
        Confirmation({ choices }) -> { model & state: Finished({ choices }) }
        _ -> model

## Transition to the Confirmation state
to_confirmation_state : Model -> Model
to_confirmation_state = |model|
    model_with_packages = add_selected_packages_to_config(model)
    when model_with_packages.state is
        PlatformSelect({ choices }) -> { model & state: Confirmation({ choices }) }
        PackageSelect({ choices }) -> { model & state: Confirmation({ choices }) }
        _ -> model

## Transition to the Search state
to_search_state : Model -> Model
to_search_state = |model|
    when model.state is
        PlatformSelect({ choices }) ->
            { model &
                cursor: { row: model.menu_row, col: 2 },
                state: Search({ choices, search_buffer: [], sender: Platform }),
            }

        PackageSelect({ choices }) ->
            new_choices = choices |> Choices.set_packages(model.selected) #{ config & packages: model.selected }
            { model &
                cursor: { row: model.menu_row, col: 2 },
                state: Search({ choices: new_choices, search_buffer: [], sender: Package }),
            }

        _ -> model

## Clear the search filter
clear_search_filter : Model -> Model
clear_search_filter = |model|
    when model.state is
        PackageSelect(_) ->
            { model &
                full_menu: model.package_list,
                # cursor: { row: model.menuRow, col: 2 },
            }

        PlatformSelect(_) ->
            { model &
                full_menu: model.platform_list,
                # cursor: { row: model.menuRow, col: 2 },
            }

        _ -> model

## Append a key to the name or search buffer
append_to_buffer : Model, Str -> Model
append_to_buffer = |model, str|
    when model.state is
        Search({ search_buffer, choices, sender }) ->
            new_buffer = List.concat(search_buffer, (Utils.str_to_slug(str) |> Str.to_utf8))
            { model & state: Search({ choices, sender, search_buffer: new_buffer }) }

        InputAppName({ name_buffer, choices }) ->
            new_buffer = List.concat(name_buffer, (Utils.str_to_slug(str) |> Str.to_utf8))
            { model & state: InputAppName({ choices, name_buffer: new_buffer }) }

        _ -> model

## Remove the last character from the name or search buffer
backspace_buffer : Model -> Model
backspace_buffer = |model|
    when model.state is
        Search({ search_buffer, choices, sender }) ->
            new_buffer = List.drop_last(search_buffer, 1)
            { model & state: Search({ choices, sender, search_buffer: new_buffer }) }

        InputAppName({ name_buffer, choices }) ->
            new_buffer = List.drop_last(name_buffer, 1)
            { model & state: InputAppName({ choices, name_buffer: new_buffer }) }

        _ -> model

## Clear the search buffer
clear_buffer : Model -> Model
clear_buffer = |model|
    when model.state is
        Search({ choices, sender }) ->
            { model & state: Search({ choices, sender, search_buffer: [] }) }

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

## Add the selected packages to the configuration
add_selected_packages_to_config : Model -> Model
add_selected_packages_to_config = |model|
    when model.state is
        PackageSelect(data) ->
            packages = Model.get_selected_items(model)
            new_choices = data.choices |> Choices.set_packages(packages)
            { model & state: PackageSelect({ data & choices: new_choices }) }

        _ -> model

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
