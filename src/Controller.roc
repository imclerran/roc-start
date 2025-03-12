module [UserAction, get_actions, apply_action, action_is_available, paginate]

import Choices
import Keys exposing [Key]
import Model exposing [Model]
import Utils
import RepoManager as RM
import rtils.StrUtils
import rtils.Compare
import heck.Heck

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
    VersionSelect,
    NextPage,
    PrevPage,
    Search,
    SearchGo,
    SingleSelect,
    TextInput(Key),
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

        Confirmation(_) -> [Exit, Finish, GoBack]
        Search({ search_buffer }) -> 
            [Exit, SearchGo, Cancel, TextInput(None)] 
            |> |actions| List.append(actions, (if List.is_empty(search_buffer) then GoBack else TextBackspace))
            # [TextInput(None), TextBackspace]
        Splash(_) -> [Exit, GoBack]
        _ -> [Exit]

with_search_or_clear_filter = |actions, model| List.append(actions, (if Model.menu_is_filtered(model) then ClearFilter else Search))
with_prev_page = |actions, model| if Model.is_not_first_page(model) then List.append(actions, PrevPage) else actions
with_next_page = |actions, model| if Model.is_not_last_page(model) then List.append(actions, NextPage) else actions

## Check if the user action is available in the current state
action_is_available : Model, UserAction -> Bool
action_is_available = |model, action| 
    actions = get_actions(model)
    when action is
        TextInput(_) -> List.contains(actions, TextInput(None))
        _ -> List.contains(actions, action)

## Translate the user action into a state transition by dispatching to the appropriate handler
apply_action : Model, UserAction -> [Step Model, Done Model]
apply_action = |model, action|
    if action_is_available(model, action) then
        when model.state is
            MainMenu(_) -> main_menu_handler(model, action)
            SettingsMenu(_) -> settings_menu_handler(model, action)
            SettingsSubmenu(_) -> settings_submenu_handler(model, action)
            InputAppName(_) -> input_app_name_handler(model, action)
            PlatformSelect(_) -> platform_select_handler(model, action)
            PackageSelect(_) -> package_select_handler(model, action)
            VersionSelect(_) -> version_select_handler(model, action)
            UpdateSelect(_) -> update_select_handler(model, action)
            Confirmation(_) -> confirmation_handler(model, action)
            Search(_) -> search_handler(model, action)
            Splash(_) -> splash_handler(model, action)
            _ -> default_handler(model, action)
    else
        Step(model)

## Default handler ensures program can always be exited
default_handler : Model, UserAction -> [Step Model, Done Model]
default_handler = |model, action|
    when action is
        Exit -> Done(to_user_exited_state(model))
        CursorUp -> Step(move_cursor(model, Up))
        CursorDown -> Step(move_cursor(model, Down))
        NextPage -> Step(next_page(model))
        PrevPage -> Step(prev_page(model))
        _ -> Step(model)

## Map the user action to the appropriate state transition from the MainMenu state
main_menu_handler : Model, UserAction -> [Step Model, Done Model]
main_menu_handler = |model, action|
    when action is
        Exit -> Done(to_user_exited_state(model))
        SingleSelect ->
            selected = Model.get_highlighted_item(model)
            if Str.contains(selected, "Start app") then
                Step(to_input_app_name_state(model))
            else if selected == "Start package" then
                Step(to_package_select_state(model))
            else if selected == "Upgrade app" then
                Step(to_input_app_name_state(model))
            else if selected == "Upgrade package" then
                Step(to_package_select_state(model))
            else if selected == "Update roc-start" then
                Step(to_update_select_state(model))
            else if selected == "Settings" then
                Step(to_settings_menu_state(model))
            else
                Step(model)

        CursorUp -> Step(move_cursor(model, Up))
        CursorDown -> Step(move_cursor(model, Down))
        NextPage -> Step(next_page(model))
        PrevPage -> Step(prev_page(model))
        Secret -> Step(to_splash_state(model))
        _ -> Step(model)

settings_menu_handler : Model, UserAction -> [Step Model, Done Model]
settings_menu_handler = |model, action|
    when action is
        Exit -> Done(to_user_exited_state(model))
        SingleSelect ->
            selected = Model.get_highlighted_item(model)
            if selected == "Theme" then
                Step(to_settings_submenu_state(model, Theme))
            else if selected == "Verbosity" then
                Step(to_settings_submenu_state(model, Verbosity))
            else if Str.contains(selected, "platform") then
                Step(to_platform_select_state(model))
            else
                Step(to_confirmation_state(model))

        CursorUp -> Step(move_cursor(model, Up))
        CursorDown -> Step(move_cursor(model, Down))
        NextPage -> Step(next_page(model))
        PrevPage -> Step(prev_page(model))
        GoBack -> Step(to_main_menu_state(model))
        _ -> Step(model)

settings_submenu_handler : Model, UserAction -> [Step Model, Done Model]
settings_submenu_handler = |model, action|
    when action is
        Exit -> Done(to_user_exited_state(model))
        SingleSelect -> Step(to_settings_menu_state(model))
        CursorUp -> Step(move_cursor(model, Up))
        CursorDown -> Step(move_cursor(model, Down))
        NextPage -> Step(next_page(model))
        PrevPage -> Step(prev_page(model))
        GoBack -> Step(to_settings_menu_state({ model & cursor: { row: 0, col: 2 } }))
        _ -> Step(model)

## Map the user action to the appropriate state transition from the PlatformSelect state
platform_select_handler : Model, UserAction -> [Step Model, Done Model]
platform_select_handler = |model, action|
    when action is
        Exit -> Done(to_user_exited_state(model))
        Search -> Step(to_search_state(model))
        SingleSelect ->
            when model.sender is
                SettingsMenu(_) -> Step(to_settings_menu_state(model))
                _ -> Step(to_package_select_state(model))

        VersionSelect -> Step(to_version_select_state(model))
        CursorUp -> Step(move_cursor(model, Up))
        CursorDown -> Step(move_cursor(model, Down))
        GoBack ->
            if Model.menu_is_filtered(model) then
                Step(clear_search_filter(model))
            else
                when model.sender is
                    InputAppName(_) ->
                        Step(to_input_app_name_state(model))

                    SettingsMenu(_) ->
                        Step(to_settings_menu_state({ model & cursor: { row: 0, col: 2 } }))

                    VersionSelect({ choices }) ->
                        when choices is
                            App(_) -> Step(to_input_app_name_state(model))
                            Config(_) -> Step(to_settings_menu_state(model))
                            Upgrade(_) -> Step(to_input_app_name_state(model))
                            _ -> Step(model)

                    Search({ choices }) ->
                        when choices is
                            App(_) -> Step(to_input_app_name_state(model))
                            Config(_) -> Step(to_settings_menu_state(model))
                            Upgrade(_) -> Step(to_input_app_name_state(model))
                            _ -> Step(model)

                    PackageSelect(_) ->
                        Step(to_input_app_name_state(model))

                    _ -> Step(model)

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
        VersionSelect -> Step(to_version_select_state(model))
        CursorUp -> Step(move_cursor(model, Up))
        CursorDown -> Step(move_cursor(model, Down))
        GoBack ->
            if Model.menu_is_filtered(model) then
                Step(clear_search_filter(model))
            else
                when model.state is
                    PackageSelect({ choices }) ->
                        when choices is
                            App(_) -> Step(to_platform_select_state(model))
                            Package(_) -> Step(to_main_menu_state(model))
                            Upgrade({ platform }) ->
                                when platform is
                                    Ok(_) -> Step(to_platform_select_state(model))
                                    Err(_) -> Step(to_main_menu_state(model))

                            _ -> Step(model)

                    _ -> Step(model)

        ClearFilter -> Step(clear_search_filter(model))
        NextPage -> Step(next_page(model))
        PrevPage -> Step(prev_page(model))
        _ -> Step(model)

version_select_handler : Model, UserAction -> [Step Model, Done Model]
version_select_handler = |model, action|
    when action is
        Exit -> Done(to_user_exited_state(model))
        SingleSelect ->
            when model.sender is
                PackageSelect(_) -> Step(to_package_select_state(model))
                PlatformSelect({ choices }) ->
                    when choices is
                        Config(_) -> Step(to_settings_menu_state(model))
                        App(_) -> Step(to_package_select_state(model))
                        Upgrade(_) -> Step(to_package_select_state(model))
                        _ -> Step(model)

                _ -> Step(model)

        CursorUp -> Step(move_cursor(model, Up))
        CursorDown -> Step(move_cursor(model, Down))
        GoBack ->
            when model.sender is
                PackageSelect(_) -> Step(to_package_select_state({ model & cursor: { row: 0, col: 2 } }))
                PlatformSelect(_) -> Step(to_platform_select_state({ model & cursor: { row: 0, col: 2 } }))
                _ -> Step(model)

        NextPage -> Step(next_page(model))
        PrevPage -> Step(prev_page(model))
        _ -> Step(model)

update_select_handler : Model, UserAction -> [Step Model, Done Model]
update_select_handler = |model, action|
    when action is
        Exit -> Done(to_user_exited_state(model))
        MultiSelect -> Step(toggle_selected(model))
        MultiConfirm -> Step(to_confirmation_state(model))
        CursorUp -> Step(move_cursor(model, Up))
        CursorDown -> Step(move_cursor(model, Down))
        GoBack -> Step(to_main_menu_state(model))
        NextPage -> Step(next_page(model))
        PrevPage -> Step(prev_page(model))
        _ -> Step(model)

## Map the user action to the appropriate state transition from the Search state
search_handler : Model, UserAction -> [Step Model, Done Model]
search_handler = |model, action|
    when action is
        Exit -> Done(to_user_exited_state(model))
        SearchGo ->
            when model.sender is
                PlatformSelect(_) -> Step(to_platform_select_state(model))
                PackageSelect(_) -> Step(to_package_select_state(model))
                _ -> Step(model)

        TextBackspace -> Step(backspace_buffer(model))
        TextInput(key) ->
            ch = key |> Keys.key_to_str |> |str| if Str.is_empty(str) then None else Char(str)
            when ch is
                Char(c) -> Step(append_to_buffer(model, c))
                None -> Step(model)

        Cancel ->
            when model.sender is
                PlatformSelect(_) -> Step(model |> clear_buffer |> to_platform_select_state)
                PackageSelect(_) -> Step(model |> clear_buffer |> to_package_select_state)
                _ -> Step(model)

        GoBack ->
            when model.sender is
                PlatformSelect(_) -> Step(to_platform_select_state(model))
                PackageSelect(_) -> Step(to_package_select_state(model))
                _ -> Step(model)

        _ -> Step(model)

## Map the user action to the appropriate state transition from the InputAppName state
input_app_name_handler : Model, UserAction -> [Step Model, Done Model]
input_app_name_handler = |model, action|
    when action is
        Exit -> Done(to_user_exited_state(model))
        TextSubmit -> Step(to_platform_select_state(model))
        TextInput(key) ->
            ch = key |> Keys.key_to_str |> |str| if Str.is_empty(str) then None else Char(str)
            when ch is
                Char(c) -> Step(append_to_buffer(model, c))
                None -> Step(model)

        TextBackspace -> Step(backspace_buffer(model))
        GoBack -> Step(to_main_menu_state(model))
        _ -> Step(model)

## Map the user action to the appropriate state transition from the Confirmation state
confirmation_handler : Model, UserAction -> [Step Model, Done Model]
confirmation_handler = |model, action|
    when action is
        Exit -> Done(to_user_exited_state(model))
        Finish -> Done(to_finished_state(model))
        GoBack ->
            when model.sender is
                PackageSelect(_) -> Step(to_package_select_state(model))
                UpdateSelect(_) -> Step(to_update_select_state(model))
                SettingsMenu(_) -> Step(to_settings_menu_state(model))
                _ -> Step(model)

        # Step(to_package_select_state(model))
        _ -> Step(model)

## Map the user action to the appropriate state transition from the Splash state
splash_handler : Model, UserAction -> [Step Model, Done Model]
splash_handler = |model, action|
    when action is
        Exit -> Done(to_user_exited_state(model))
        GoBack -> Step(to_main_menu_state(model))
        _ -> Step(model)

## Transition to the UserExited state
to_user_exited_state : Model -> Model
to_user_exited_state = |model| { model & state: UserExited, sender: model.state }

## Transition to the MainMenu state
to_main_menu_state : Model -> Model
to_main_menu_state = |model|
    menu = ["Start app", "Start package", "Upgrade app", "Upgrade package", "Update roc-start", "Settings"]
    { row, choices: new_choices } =
        when model.state is
            InputAppName({ choices, name_buffer }) ->
                menu_row =
                    when choices is
                        App(_) -> model.menu_row
                        Upgrade(_) -> model.menu_row + 2
                        _ -> model.menu_row
                filename = name_buffer |> Str.from_utf8 |> Result.with_default("main")
                { choices: choices |> Choices.set_filename(filename), row: menu_row }

            PlatformSelect({ choices }) ->
                platform = Model.get_highlighted_item(model) |> menu_item_to_repo
                { choices: choices |> Choices.set_platform(platform), row: model.menu_row }

            PackageSelect({ choices }) ->
                menu_row =
                    when choices is
                        Package(_) -> model.menu_row + 1
                        Upgrade(_) -> model.menu_row + 3
                        _ -> model.menu_row
                package_repos = model.selected |> List.map(menu_item_to_repo)
                { choices: choices |> Choices.set_packages(package_repos), row: menu_row }

            UpdateSelect({ choices }) ->
                selected = Model.get_selected_items(model)
                { choices: choices |> Choices.set_updates(selected), row: model.menu_row + 4 }

            SettingsMenu({ choices }) -> { choices, row: model.menu_row + 5 }
            MainMenu({ choices }) -> { choices, row: 2 }
            SettingsSubmenu({ choices }) -> { choices, row: 2 }
            Search({ choices }) -> { choices, row: 2 }
            VersionSelect({ choices }) -> { choices, row: 2 }
            Confirmation({ choices }) -> { choices, row: 2 }
            Finished({ choices }) -> { choices, row: 2 }
            Splash({ choices }) -> { choices, row: 2 }
            UserExited -> { choices: NothingToDo, row: 2 }

    { model &
        cursor: { row, col: 2 },
        menu,
        full_menu: menu,
        state: MainMenu({ choices: new_choices }),
        sender: model.state,
    }

to_settings_menu_state : Model -> Model
to_settings_menu_state = |model|
    menu = ["Theme", "Verbosity", "Default platform", "Save changes"]
    when model.state is
        MainMenu({ choices }) ->
            new_choices = Choices.to_config(choices)
            { model &
                cursor: { row: 2, col: 2 },
                full_menu: menu,
                state: SettingsMenu({ choices: new_choices }),
                sender: model.state,
            }

        SettingsSubmenu({ choices, submenu }) ->
            { row, choices: new_choices } = 
                if model.cursor.row < model.menu_row then
                    when submenu is
                        Theme ->
                            { row: model.menu_row, choices }
                        Verbosity ->
                            { row: model.menu_row + 1, choices }
                else
                    selection = Model.get_highlighted_item(model)
                    when submenu is
                        Theme -> 
                            { row: model.menu_row, choices: choices |> Choices.set_config_theme(selection |> Heck.to_kebab_case) }
                        Verbosity -> 
                            { row: model.menu_row + 1, choices: choices |> Choices.set_config_verbosity(selection |> Heck.to_kebab_case) }

            { model &
                cursor: { row, col: 2 },
                full_menu: menu,
                state: SettingsMenu({ choices: new_choices }),
                sender: model.state,
            }

        PlatformSelect({ choices }) ->
            new_choices = 
                if model.cursor.row < model.menu_row then
                    choices
                else
                    platform = Model.get_highlighted_item(model)
                    choices |> Choices.set_config_platform(platform)
            { model &
                cursor: { row: model.menu_row + 2, col: 2 },
                full_menu: menu,
                state: SettingsMenu({ choices: new_choices }),
                sender: model.state,
            }

        VersionSelect({ choices, repo }) ->
            selected_version = Model.get_highlighted_item(model) |> |v| if v == "latest" then "" else v
            new_repo = { repo & version: selected_version }
            platform_menu = add_or_update_platform_menu(model.platform_menu, new_repo)
            new_repo_str = if Str.is_empty(new_repo.version) then new_repo.name else "${new_repo.name}:${new_repo.version}"
            new_choices = choices |> Choices.set_config_platform(new_repo_str)
            { model &
                platform_menu,
                cursor: { row: model.menu_row + 2, col: 2 },
                full_menu: menu,
                state: SettingsMenu({ choices: new_choices }),
                sender: model.state,
            }

        Confirmation({ choices }) ->
            { model &
                cursor: { row: model.menu_row + 3, col: 2 },
                full_menu: menu,
                state: SettingsMenu({ choices }),
                sender: model.state,
            }

        _ -> model

to_settings_submenu_state : Model, [Theme, Verbosity] -> Model
to_settings_submenu_state = |model, submenu|
    menu =
        when submenu is
            Theme -> model.theme_names |> List.sort_with(Compare.str) |> List.map(Heck.to_title_case)
            Verbosity -> ["Verbose", "Quiet", "Silent"]
            # Platform -> model.platform_menu

    choices = Model.get_choices(model)
    { model &
        cursor: { row: 2, col: 2 },
        full_menu: menu,
        state: SettingsSubmenu({ choices, submenu }),
        sender: model.state,
    }

## Transition to the InputAppName state
to_input_app_name_state : Model -> Model
to_input_app_name_state = |model|
    when model.state is
        MainMenu({ choices }) ->
            menu_choice = Model.get_highlighted_item(model) |> |s| if s == "Start app" then App else if Str.contains(s, "Upgrade") then Upgrade else Invalid
            new_choices =
                when menu_choice is
                    App -> Choices.to_app(choices)
                    Upgrade -> Choices.to_upgrade(choices)
                    Invalid -> choices
            when menu_choice is
                Invalid -> model
                App | Upgrade ->
                    { model &
                        cursor: { row: 2, col: 2 },
                        menu: [],
                        full_menu: [],
                        state: InputAppName({ choices: new_choices, name_buffer: [] }),
                        sender: model.state,
                    }

        PlatformSelect({ choices }) ->
            filename = Choices.get_filename(choices) |> Str.drop_suffix(".roc")
            { model &
                cursor: { row: 2, col: 2 },
                menu: [],
                full_menu: [],
                state: InputAppName({ choices, name_buffer: filename |> Str.to_utf8 }),
                sender: model.state,
            }

        Splash({ choices }) ->
            filename = Choices.get_filename(choices) |> Str.drop_suffix(".roc")
            { model &
                cursor: { row: 2, col: 2 },
                state: InputAppName({ choices, name_buffer: filename |> Str.to_utf8 }),
                sender: model.state,
            }

        _ -> model

## Transition to the Splash state
to_splash_state : Model -> Model
to_splash_state = |model|
    when model.state is
        MainMenu({ choices }) ->
            { model &
                state: Splash({ choices }),
                sender: model.state,
            }

        _ -> model

## Transition to the PlatformSelect state
to_platform_select_state : Model -> Model
to_platform_select_state = |model|
    when model.state is
        InputAppName({ choices, name_buffer }) ->
            filename = name_buffer |> Str.from_utf8 |> Result.with_default("main") |> |name| if Str.is_empty(name) then "main" else name
            new_choices = choices |> Choices.set_filename(filename)
            menu =
                when new_choices is
                    Upgrade(_) -> [["No change"], model.platform_menu] |> List.join
                    _ -> model.platform_menu
            { model &
                page_first_item: 0,
                menu,
                full_menu: menu,
                cursor: { row: 2, col: 2 },
                state: PlatformSelect({ choices: new_choices }),
                sender: model.state,
            }

        Search({ choices, search_buffer }) ->
            filtered_menu =
                model.platform_menu
                |> List.keep_if(|item| Str.contains(item, (search_buffer |> Str.from_utf8 |> Result.with_default(""))))
            { model &
                page_first_item: 0,
                menu: filtered_menu,
                full_menu: filtered_menu,
                cursor: { row: 2, col: 2 },
                state: PlatformSelect({ choices }),
                sender: model.state,
            }

        PackageSelect({ choices }) ->
            package_repos = model.selected |> List.map(menu_item_to_repo)
            new_choices = choices |> Choices.set_packages(package_repos)
            menu =
                when new_choices is
                    Upgrade(_) -> [["No change"], model.platform_menu] |> List.join
                    _ -> model.platform_menu
            { model &
                page_first_item: 0,
                menu: menu,
                full_menu: menu,
                cursor: { row: 2, col: 2 },
                state: PlatformSelect({ choices: new_choices }),
                sender: model.state,
            }

        VersionSelect({ choices }) ->
            { model &
                page_first_item: 0,
                menu: model.platform_menu,
                full_menu: model.platform_menu,
                cursor: { row: 2, col: 2 },
                state: PlatformSelect({ choices }),
                sender: model.state,
            }

        SettingsMenu({ choices }) ->
            { model &
                page_first_item: 0,
                menu: model.platform_menu,
                full_menu: model.platform_menu,
                cursor: { row: 2, col: 2 },
                state: PlatformSelect({ choices }),
                sender: model.state,
            }

        _ -> model

to_version_select_state : Model -> Model
to_version_select_state = |model|
    when model.state is
        PackageSelect({ choices }) ->
            package_repos = model.selected |> List.map(menu_item_to_repo)
            new_choices = choices |> Choices.set_packages(package_repos)
            package_choice = Model.get_highlighted_item(model) |> menu_item_to_repo
            { package_name, package_version } = Str.split_first(package_choice, ":") |> Result.with_default({ before: package_choice, after: "" }) |> |{ before, after }| { package_name: before, package_version: after }
            package_repo = RM.get_full_repo_name(model.package_name_map, package_name, Package) |> Result.with_default(package_name)
            package_releases = Dict.get(model.packages, package_repo) |> Result.with_default([])
            when package_releases is
                [] -> model
                _ ->
                    versions = package_releases |> List.map(|{ tag }| tag) |> List.prepend("latest")
                    { model &
                        page_first_item: 0,
                        menu: versions,
                        full_menu: versions,
                        cursor: { row: 2, col: 2 },
                        state: VersionSelect({ choices: new_choices, repo: { name: package_name, version: package_version } }),
                        sender: model.state,
                    }

        PlatformSelect({ choices }) ->
            platform = Model.get_highlighted_item(model) |> menu_item_to_repo
            new_choices = choices |> Choices.set_platform(platform)
            { platform_name, platform_version } = Str.split_first(platform, ":") |> Result.with_default({ before: platform, after: "" }) |> |{ before, after }| { platform_name: before, platform_version: after }
            platform_repo = RM.get_full_repo_name(model.platform_name_map, platform_name, Platform) |> Result.with_default(platform_name)
            platform_releases = Dict.get(model.platforms, platform_repo) |> Result.with_default([])
            when platform_releases is
                [] -> model
                _ ->
                    versions = platform_releases |> List.map(|{ tag }| tag) |> List.prepend("latest")
                    { model &
                        page_first_item: 0,
                        menu: versions,
                        full_menu: versions,
                        cursor: { row: 2, col: 2 },
                        state: VersionSelect({ choices: new_choices, repo: { name: platform_name, version: platform_version } }),
                        sender: model.state,
                    }

        _ -> model

## Transition to the PackageSelect state
to_package_select_state : Model -> Model
to_package_select_state = |model|
    when model.state is
        MainMenu({ choices }) ->
            menu_choice = Model.get_highlighted_item(model) |> |s| if s == "Start package" then Package else if Str.contains(s, "Upgrade") then Upgrade else Invalid
            when menu_choice is
                Package | Upgrade ->
                    new_choices =
                        when menu_choice is
                            Package -> Choices.to_package(choices)
                            Upgrade -> Choices.to_upgrade(choices)
                            Invalid -> choices
                    selected = Choices.get_packages(new_choices) |> packages_to_menu_items
                    { model &
                        page_first_item: 0,
                        menu: model.package_menu,
                        full_menu: model.package_menu,
                        cursor: { row: 2, col: 2 },
                        selected,
                        state: PackageSelect({ choices: new_choices }),
                        sender: model.state,
                    }

                _ -> model

        PlatformSelect({ choices }) ->
            platform = Model.get_highlighted_item(model) |> |s| if s == "No change" then "" else s
            new_choices = choices |> Choices.set_platform(platform)
            selected = Choices.get_packages(new_choices) |> packages_to_menu_items
            { model &
                page_first_item: 0,
                menu: model.package_menu,
                full_menu: model.package_menu,
                cursor: { row: 2, col: 2 },
                selected,
                state: PackageSelect({ choices: new_choices }),
                sender: model.state,
            }

        Search({ choices, search_buffer }) ->
            filtered_menu =
                model.package_menu
                |> List.keep_if(|item| Str.contains(item, (search_buffer |> Str.from_utf8 |> Result.with_default(""))))
            selected = Choices.get_packages(choices) |> packages_to_menu_items
            { model &
                page_first_item: 0,
                menu: filtered_menu,
                full_menu: filtered_menu,
                cursor: { row: 2, col: 2 },
                selected,
                state: PackageSelect({ choices }),
                sender: model.state,
            }

        Confirmation({ choices }) ->
            selected = Choices.get_packages(choices) |> packages_to_menu_items
            { model &
                page_first_item: 0,
                menu: model.package_menu,
                full_menu: model.package_menu,
                selected,
                cursor: { row: 2, col: 2 },
                state: PackageSelect({ choices }),
                sender: model.state,
            }

        VersionSelect({ choices, repo }) ->
            when model.sender is
                PackageSelect(_) if model.cursor.row != 0 ->
                    selected_version = Model.get_highlighted_item(model) |> |v| if v == "latest" then "" else v
                    new_repo = { repo & version: selected_version }
                    selected = Choices.get_packages(choices) |> packages_to_menu_items |> add_or_update_package_menu(new_repo)
                    package_menu = update_menu_with_version(model.package_menu, new_repo)
                    new_choices = choices |> Choices.set_packages(selected |> List.map(menu_item_to_repo))
                    { model &
                        page_first_item: 0,
                        package_menu,
                        menu: package_menu,
                        full_menu: package_menu,
                        selected,
                        cursor: { row: 2, col: 2 },
                        state: PackageSelect({ choices: new_choices }),
                        sender: model.state,
                    }

                PackageSelect(_) ->
                    selected = Choices.get_packages(choices) |> packages_to_menu_items
                    { model &
                        page_first_item: 0,
                        menu: model.package_menu,
                        full_menu: model.package_menu,
                        selected,
                        cursor: { row: 2, col: 2 },
                        state: PackageSelect({ choices }),
                        sender: model.state,
                    }

                PlatformSelect(_) ->
                    selected_version = Model.get_highlighted_item(model) |> |v| if v == "latest" then "" else v
                    new_repo = { repo & version: selected_version }
                    platform_menu = add_or_update_platform_menu(model.platform_menu, new_repo)
                    new_platform = if Str.is_empty(selected_version) then new_repo.name else "${new_repo.name}:${selected_version}"
                    new_choices = choices |> Choices.set_platform(new_platform)
                    { model &
                        page_first_item: 0,
                        platform_menu,
                        menu: model.package_menu,
                        full_menu: model.package_menu,
                        cursor: { row: 2, col: 2 },
                        selected: Choices.get_packages(new_choices) |> packages_to_menu_items,
                        state: PackageSelect({ choices: new_choices }),
                        sender: model.state,
                    }

                _ -> model

        _ -> model

to_update_select_state : Model -> Model
to_update_select_state = |model|
    menu = ["Platforms", "Packages", "Scripts", "Themes"]
    when model.state is
        MainMenu({ choices }) ->
            new_choices = Choices.to_update(choices)
            selected = Choices.get_updates(new_choices)
            { model &
                page_first_item: 0,
                menu,
                full_menu: menu,
                cursor: { row: 2, col: 2 },
                selected,
                state: UpdateSelect({ choices: new_choices }),
                sender: model.state,
            }

        Confirmation({ choices }) ->
            selected = Choices.get_updates(choices)
            { model &
                page_first_item: 0,
                menu,
                full_menu: menu,
                cursor: { row: 2, col: 2 },
                selected,
                state: UpdateSelect({ choices }),
                sender: model.state,
            }

        _ -> model

## Transition to the Finished state
to_finished_state : Model -> Model
to_finished_state = |model|
    model_with_packages = add_selected_packages_to_config(model)
    when model_with_packages.state is
        Confirmation({ choices }) -> { model & state: Finished({ choices }), sender: model.state }
        UpdateSelect({ choices }) ->
            new_choices = choices |> Choices.set_updates(Model.get_selected_items(model))
            { model & state: Finished({ choices: new_choices }), sender: model.state }

        _ -> model

## Transition to the Confirmation state
to_confirmation_state : Model -> Model
to_confirmation_state = |model|
    model_with_packages = add_selected_packages_to_config(model)
    when model_with_packages.state is
        PlatformSelect({ choices }) -> { model & state: Confirmation({ choices }), sender: model.state }
        PackageSelect({ choices }) -> { model & state: Confirmation({ choices }), sender: model.state }
        UpdateSelect({ choices }) ->
            new_choices = choices |> Choices.set_updates(Model.get_selected_items(model))
            { model & state: Confirmation({ choices: new_choices }), sender: model.state }

        SettingsMenu({ choices }) -> { model & state: Confirmation({ choices }), sender: model.state }
        _ -> model

## Transition to the Search state
to_search_state : Model -> Model
to_search_state = |model|
    when model.state is
        PlatformSelect({ choices }) ->
            { model &
                cursor: { row: model.menu_row, col: 2 },
                state: Search({ choices, search_buffer: [] }),
                sender: model.state,
            }

        PackageSelect({ choices }) ->
            package_repos = model.selected |> List.map(menu_item_to_repo)
            new_choices = choices |> Choices.set_packages(package_repos)
            { model &
                cursor: { row: model.menu_row, col: 2 },
                state: Search({ choices: new_choices, search_buffer: [] }),
                sender: model.state,
            }

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
        Search({ search_buffer, choices }) ->
            new_buffer = List.concat(search_buffer, (Utils.str_to_slug(str) |> Str.to_utf8))
            { model & state: Search({ choices, search_buffer: new_buffer }) }

        InputAppName({ name_buffer, choices }) ->
            new_buffer = List.concat(name_buffer, (Utils.str_to_slug(str) |> Str.to_utf8))
            { model & state: InputAppName({ choices, name_buffer: new_buffer }) }

        _ -> model

## Remove the last character from the name or search buffer
backspace_buffer : Model -> Model
backspace_buffer = |model|
    when model.state is
        Search({ search_buffer, choices }) ->
            new_buffer = List.drop_last(search_buffer, 1)
            { model & state: Search({ choices, search_buffer: new_buffer }) }

        InputAppName({ name_buffer, choices }) ->
            new_buffer = List.drop_last(name_buffer, 1)
            { model & state: InputAppName({ choices, name_buffer: new_buffer }) }

        _ -> model

## Clear the search buffer
clear_buffer : Model -> Model
clear_buffer = |model|
    when model.state is
        Search({ choices }) ->
            { model & state: Search({ choices, search_buffer: [] }) }

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
            package_repos = Model.get_selected_items(model) |> List.map(menu_item_to_repo)
            new_choices = data.choices |> Choices.set_packages(package_repos)
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

repo_to_menu_item : Str -> Str
repo_to_menu_item = |repo|
    when Str.split_first(repo, "/") is
        Ok({ before: owner, after: name_maybe_version }) ->
            when Str.split_first(name_maybe_version, ":") is
                Ok({ before: name, after: version }) -> "${name} (${owner}) : ${version}"
                _ -> "${name_maybe_version} (${owner})"

        _ ->
            when Str.split_first(repo, ":") is
                Ok({ before: name, after: version }) -> "${name} : ${version}"
                _ -> repo

expect repo_to_menu_item("owner/name:version") == "name (owner) : version"
expect repo_to_menu_item("owner/name") == "name (owner)"
expect repo_to_menu_item("name:version") == "name : version"
expect repo_to_menu_item("name") == "name"

menu_item_to_repo : Str -> Str
menu_item_to_repo = |item|
    when StrUtils.split_if(item, |c| List.contains(['(', ')'], c)) is
        [name_dirty, owner, version_dirty] ->
            name = Str.trim(name_dirty)
            version = Str.drop_prefix(version_dirty, " : ") |> Str.trim
            "${owner}/${name}:${version}"

        [name_dirty, owner] ->
            name = Str.trim(name_dirty)
            "${owner}/${name}"

        _ ->
            when Str.split_first(item, " : ") is
                Ok({ before: name, after: version }) -> "${name}:${version}"
                _ -> item

expect menu_item_to_repo("name (owner) : version") == "owner/name:version"
expect menu_item_to_repo("name (owner)") == "owner/name"
expect menu_item_to_repo("name : version") == "name:version"
expect menu_item_to_repo("name") == "name"

expect menu_item_to_repo(repo_to_menu_item("owner/name:version")) == "owner/name:version"
expect menu_item_to_repo(repo_to_menu_item("owner/name")) == "owner/name"
expect menu_item_to_repo(repo_to_menu_item("name:version")) == "name:version"
expect menu_item_to_repo(repo_to_menu_item("name")) == "name"

expect repo_to_menu_item(menu_item_to_repo("name (owner) : version")) == "name (owner) : version"
expect repo_to_menu_item(menu_item_to_repo("name (owner)")) == "name (owner)"
expect repo_to_menu_item(menu_item_to_repo("name : version")) == "name : version"
expect repo_to_menu_item(menu_item_to_repo("name")) == "name"

packages_to_menu_items : List { name : Str, version : Str } -> List Str
packages_to_menu_items = |packages|
    List.map(
        packages,
        |{ name: repo, version }|
            when Str.split_first(repo, "/") is
                Ok({ before: owner, after: name }) ->
                    "${name} (${owner})"
                    |> |s| if Str.is_empty(version) then s else "${s} : ${version}"

                _ -> if Str.is_empty(version) then repo else "${repo} : ${version}",
    )

update_menu_with_version : List Str, { name : Str, version : Str } -> List Str
update_menu_with_version = |menu, { name, version }|
    match_name = name |> repo_to_menu_item
    insert_item = if Str.is_empty(version) then name else "${name}:${version}" |> repo_to_menu_item
    List.map(
        menu,
        |item|
            when Str.split_first(item, " : ") is
                Ok({ before: item_name }) ->
                    if item_name == match_name then insert_item else item

                _ ->
                    if item == match_name then insert_item else item,
    )

add_or_update_package_menu : List Str, { name : Str, version : Str } -> List Str
add_or_update_package_menu = |menu, { name, version }|
    match_name = name |> repo_to_menu_item
    insert_item = if Str.is_empty(version) then name else "${name}:${version}" |> repo_to_menu_item
    List.walk(
        menu,
        (Bool.false, []),
        |(found, new_menu), item|
            when Str.split_first(item, " : ") is
                Ok({ before: item_name }) ->
                    if item_name == match_name then
                        (Bool.true, List.append(new_menu, insert_item))
                    else
                        (Bool.false, List.append(new_menu, item))

                _ ->
                    if item == match_name then
                        (Bool.true, List.append(new_menu, insert_item))
                    else
                        (found, List.append(new_menu, item)),
    )
    |> |(found, new_menu)| if found then new_menu else List.append(new_menu, insert_item)

add_or_update_platform_menu : List Str, { name : Str, version : Str } -> List Str
add_or_update_platform_menu = |menu, { name, version }| add_or_update_package_menu(menu, { name, version })
