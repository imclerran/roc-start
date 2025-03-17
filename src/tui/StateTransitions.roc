module [
    to_user_exited_state,
    to_main_menu_state,
    to_settings_menu_state,
    to_settings_submenu_state,
    to_input_app_name_state,
    to_splash_state,
    to_platform_select_state,
    to_package_select_state,
    to_version_select_state,
    to_update_select_state,
    to_finished_state,
    to_confirmation_state,
    to_choose_flags_state,
    to_search_state,
]

import Choices
import Utils
import Model exposing [Model]
import repos.Manager as RM
import heck.Heck
import rtils.Compare

## Transition to the UserExited state
to_user_exited_state : Model -> Model
to_user_exited_state = |model| { model & state: UserExited, sender: model.state }

## Transition to the MainMenu state
to_main_menu_state : Model -> Model
to_main_menu_state = |model|
    menu = ["Start app", "Start package", "Upgrade app", "Upgrade package", "Update roc-start", "Settings", "Exit"]
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
                platform = Model.get_highlighted_item(model) |> Utils.menu_item_to_repo
                { choices: choices |> Choices.set_platform(platform), row: model.menu_row }

            PackageSelect({ choices }) ->
                menu_row =
                    when choices is
                        Package(_) -> model.menu_row + 1
                        Upgrade(_) -> model.menu_row + 3
                        _ -> model.menu_row
                package_repos = model.selected |> List.map(Utils.menu_item_to_repo)
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
            ChooseFlags({ choices }) -> { choices, row: 2 }
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

## Transition to the SettingsMenu state
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

## Transition to the SettingsSubmenu state
to_settings_submenu_state : Model, [Theme, Verbosity] -> Model
to_settings_submenu_state = |model, submenu|
    menu =
        when submenu is
            Theme -> model.theme_names |> List.sort_with(Compare.str) |> List.map(Heck.to_title_case)
            Verbosity -> ["Verbose", "Quiet", "Silent"]

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

        Search({ choices, search_buffer, prior_sender }) ->
            filtered_menu =
                model.platform_menu
                |> List.keep_if(|item| Str.contains(item, (search_buffer |> Str.from_utf8 |> Result.with_default(""))))
            { model &
                page_first_item: 0,
                menu: filtered_menu,
                full_menu: filtered_menu,
                cursor: { row: 2, col: 2 },
                state: PlatformSelect({ choices }),
                sender: prior_sender,
            }

        PackageSelect({ choices }) ->
            package_repos = model.selected |> List.map(Utils.menu_item_to_repo)
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

        Search({ choices, search_buffer, prior_sender }) ->
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
                sender: prior_sender,
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
                    new_choices = choices |> Choices.set_packages(selected |> List.map(Utils.menu_item_to_repo))
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


## Transition to the VersionSelect state
to_version_select_state : Model -> Model
to_version_select_state = |model|
    when model.state is
        PackageSelect({ choices }) ->
            package_repos = model.selected |> List.map(Utils.menu_item_to_repo)
            new_choices = choices |> Choices.set_packages(package_repos)
            package_choice = Model.get_highlighted_item(model) |> Utils.menu_item_to_repo
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
            platform = Model.get_highlighted_item(model) |> Utils.menu_item_to_repo
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

## Transition to the UpdateSelect state
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
    model_with_packages = Model.add_selected_packages_to_config(model)
    when model_with_packages.state is
        Confirmation({ choices }) -> { model & state: Finished({ choices }), sender: model.state }
        UpdateSelect({ choices }) ->
            new_choices = choices |> Choices.set_updates(Model.get_selected_items(model))
            { model & state: Finished({ choices: new_choices }), sender: model.state }

        _ -> model

## Transition to the Confirmation state
to_confirmation_state : Model -> Model
to_confirmation_state = |model|
    model_with_packages = Model.add_selected_packages_to_config(model)
    when model_with_packages.state is
        PlatformSelect({ choices }) -> { model & state: Confirmation({ choices }), sender: model.state }
        PackageSelect({ choices }) -> { model & state: Confirmation({ choices }), sender: model.state }
        UpdateSelect({ choices }) ->
            new_choices = choices |> Choices.set_updates(Model.get_selected_items(model))
            { model & state: Confirmation({ choices: new_choices }), sender: model.state }

        ChooseFlags({ choices }) ->
            new_choices = choices |> Choices.set_flags(Model.get_selected_items(model))
            { model & state: Confirmation({ choices: new_choices }), sender: model.state }

        SettingsMenu({ choices }) -> { model & state: Confirmation({ choices }), sender: model.state }
        _ -> model

# # Transition to the ChooseFlags state
to_choose_flags_state : Model -> Model
to_choose_flags_state = |model|
    when model.state is
        Confirmation({ choices }) ->
            menu =
                when choices is
                    App(_) -> ["Force", "No Script"]
                    Package(_) -> ["Force"]
                    _ -> []
            when choices is
                App(_) | Package(_) ->
                    selected = Choices.get_flags(choices) |> List.map(Heck.to_title_case)
                    { model &
                        cursor: { row: 2, col: 2 },
                        full_menu: menu,
                        state: ChooseFlags({ choices }),
                        selected,
                        sender: model.state,
                    }

                _ -> model

        _ -> model

## Transition to the Search state
to_search_state : Model -> Model
to_search_state = |model|
    when model.state is
        PlatformSelect({ choices }) ->
            { model &
                cursor: { row: model.menu_row, col: 2 },
                state: Search({ choices, search_buffer: [], prior_sender: model.sender }),
                sender: model.state,
            }

        PackageSelect({ choices }) ->
            package_repos = model.selected |> List.map(Utils.menu_item_to_repo)
            new_choices = choices |> Choices.set_packages(package_repos)
            { model &
                cursor: { row: model.menu_row, col: 2 },
                state: Search({ choices: new_choices, search_buffer: [], prior_sender: model.sender }),
                sender: model.state,
            }

        _ -> model

# =============================================================================
# Helpers functions


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
    match_name = name |> Utils.repo_to_menu_item
    insert_item = if Str.is_empty(version) then name else "${name}:${version}" |> Utils.repo_to_menu_item
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
    match_name = name |> Utils.repo_to_menu_item
    insert_item = if Str.is_empty(version) then name else "${name}:${version}" |> Utils.repo_to_menu_item
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
