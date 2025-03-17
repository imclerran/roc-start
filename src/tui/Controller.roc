module [apply_action]

import Keys
import Model exposing [Model]
import UserAction exposing [UserAction]
import StateTransitions as ST

## Translate the user action into a state transition by dispatching to the appropriate handler
apply_action : Model, UserAction -> [Step Model, Done Model]
apply_action = |model, action|
    if action == Exit then
        Done(ST.to_user_exited_state(model))
    else if Model.action_is_available(model, action) then
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
            ChooseFlags(_) -> choose_flags_handler(model, action)
            Search(_) -> search_handler(model, action)
            Splash(_) -> splash_handler(model, action)
            _ -> default_handler(model, action)
    else
        Step(model)

## Default handler ensures program can always be exited
default_handler : Model, UserAction -> [Step Model, Done Model]
default_handler = |model, action|
    when action is
        CursorUp -> Step(Model.move_cursor(model, Up))
        CursorDown -> Step(Model.move_cursor(model, Down))
        NextPage -> Step(Model.next_page(model))
        PrevPage -> Step(Model.prev_page(model))
        _ -> Step(model)

## Map the user action to the appropriate state transition from the MainMenu state
main_menu_handler : Model, UserAction -> [Step Model, Done Model]
main_menu_handler = |model, action|
    when action is
        SingleSelect ->
            selected = Model.get_highlighted_item(model)
            if Str.contains(selected, "Start app") then
                Step(ST.to_input_app_name_state(model))
            else if selected == "Start package" then
                Step(ST.to_package_select_state(model))
            else if selected == "Upgrade app" then
                Step(ST.to_input_app_name_state(model))
            else if selected == "Upgrade package" then
                Step(ST.to_package_select_state(model))
            else if selected == "Update roc-start" then
                Step(ST.to_update_select_state(model))
            else if selected == "Settings" then
                Step(ST.to_settings_menu_state(model))
            else if selected == "Exit" then
                Done(ST.to_user_exited_state(model))
            else
                Step(model)

        CursorUp -> Step(Model.move_cursor(model, Up))
        CursorDown -> Step(Model.move_cursor(model, Down))
        NextPage -> Step(Model.next_page(model))
        PrevPage -> Step(Model.prev_page(model))
        Secret -> Step(ST.to_splash_state(model))
        _ -> Step(model)

settings_menu_handler : Model, UserAction -> [Step Model, Done Model]
settings_menu_handler = |model, action|
    when action is
        SingleSelect ->
            selected = Model.get_highlighted_item(model)
            if selected == "Theme" then
                Step(ST.to_settings_submenu_state(model, Theme))
            else if selected == "Verbosity" then
                Step(ST.to_settings_submenu_state(model, Verbosity))
            else if Str.contains(selected, "platform") then
                Step(ST.to_platform_select_state(model))
            else
                Step(ST.to_confirmation_state(model))

        CursorUp -> Step(Model.move_cursor(model, Up))
        CursorDown -> Step(Model.move_cursor(model, Down))
        NextPage -> Step(Model.next_page(model))
        PrevPage -> Step(Model.prev_page(model))
        GoBack -> Step(ST.to_main_menu_state(model))
        _ -> Step(model)

settings_submenu_handler : Model, UserAction -> [Step Model, Done Model]
settings_submenu_handler = |model, action|
    when action is
        SingleSelect -> Step(ST.to_settings_menu_state(model))
        CursorUp -> Step(Model.move_cursor(model, Up))
        CursorDown -> Step(Model.move_cursor(model, Down))
        NextPage -> Step(Model.next_page(model))
        PrevPage -> Step(Model.prev_page(model))
        GoBack -> Step(ST.to_settings_menu_state({ model & cursor: { row: 0, col: 2 } }))
        _ -> Step(model)

## Map the user action to the appropriate state transition from the PlatformSelect state
platform_select_handler : Model, UserAction -> [Step Model, Done Model]
platform_select_handler = |model, action|
    when action is
        Search -> Step(ST.to_search_state(model))
        SingleSelect ->
            when model.sender is
                SettingsMenu(_) -> Step(ST.to_settings_menu_state(model))
                _ -> Step(ST.to_package_select_state(model))

        VersionSelect -> Step(ST.to_version_select_state(model))
        CursorUp -> Step(Model.move_cursor(model, Up))
        CursorDown -> Step(Model.move_cursor(model, Down))
        GoBack ->
            if Model.menu_is_filtered(model) then
                Step(Model.clear_search_filter(model))
            else
                when model.sender is
                    InputAppName(_) ->
                        Step(ST.to_input_app_name_state(model))

                    SettingsMenu(_) ->
                        Step(ST.to_settings_menu_state({ model & cursor: { row: 0, col: 2 } }))

                    VersionSelect({ choices }) ->
                        when choices is
                            App(_) -> Step(ST.to_input_app_name_state(model))
                            Config(_) -> Step(ST.to_settings_menu_state(model))
                            Upgrade(_) -> Step(ST.to_input_app_name_state(model))
                            _ -> Step(model)

                    Search({ choices }) ->
                        when choices is
                            App(_) -> Step(ST.to_input_app_name_state(model))
                            Config(_) -> Step(ST.to_settings_menu_state(model))
                            Upgrade(_) -> Step(ST.to_input_app_name_state(model))
                            _ -> Step(model)

                    PackageSelect(_) ->
                        Step(ST.to_input_app_name_state(model))

                    _ -> Step(model)

        ClearFilter -> Step(Model.clear_search_filter(model))
        NextPage -> Step(Model.next_page(model))
        PrevPage -> Step(Model.prev_page(model))
        _ -> Step(model)

## Map the user action to the appropriate state transition from the PackageSelect state
package_select_handler : Model, UserAction -> [Step Model, Done Model]
package_select_handler = |model, action|
    when action is
        Search -> Step(ST.to_search_state(model))
        MultiConfirm -> Step(ST.to_confirmation_state(model))
        MultiSelect -> Step(Model.toggle_selected(model))
        VersionSelect -> Step(ST.to_version_select_state(model))
        CursorUp -> Step(Model.move_cursor(model, Up))
        CursorDown -> Step(Model.move_cursor(model, Down))
        GoBack ->
            if Model.menu_is_filtered(model) then
                Step(Model.clear_search_filter(model))
            else
                when model.sender is
                    PlatformSelect(_) -> Step(ST.to_platform_select_state(model))
                    MainMenu(_) -> Step(ST.to_main_menu_state(model))
                    Confirmation({ choices }) ->
                        when choices is
                            App(_) -> Step(ST.to_platform_select_state(model))
                            Package(_) -> Step(ST.to_main_menu_state(model))
                            Upgrade({ platform, filename }) ->
                                when platform is
                                    Ok(_) -> Step(ST.to_platform_select_state(model))
                                    Err(_) if filename != "main.roc" -> Step(ST.to_platform_select_state(model))
                                    _ -> Step(ST.to_main_menu_state(model))

                            _ -> Step(model)

                    _ -> Step(model)

        ClearFilter -> Step(Model.clear_search_filter(model))
        NextPage -> Step(Model.next_page(model))
        PrevPage -> Step(Model.prev_page(model))
        _ -> Step(model)

version_select_handler : Model, UserAction -> [Step Model, Done Model]
version_select_handler = |model, action|
    when action is
        SingleSelect ->
            when model.sender is
                PackageSelect(_) -> Step(ST.to_package_select_state(model))
                PlatformSelect({ choices }) ->
                    when choices is
                        Config(_) -> Step(ST.to_settings_menu_state(model))
                        App(_) -> Step(ST.to_package_select_state(model))
                        Upgrade(_) -> Step(ST.to_package_select_state(model))
                        _ -> Step(model)

                _ -> Step(model)

        CursorUp -> Step(Model.move_cursor(model, Up))
        CursorDown -> Step(Model.move_cursor(model, Down))
        GoBack ->
            when model.sender is
                PackageSelect(_) -> Step(ST.to_package_select_state({ model & cursor: { row: 0, col: 2 } }))
                PlatformSelect(_) -> Step(ST.to_platform_select_state({ model & cursor: { row: 0, col: 2 } }))
                _ -> Step(model)

        NextPage -> Step(Model.next_page(model))
        PrevPage -> Step(Model.prev_page(model))
        _ -> Step(model)

update_select_handler : Model, UserAction -> [Step Model, Done Model]
update_select_handler = |model, action|
    when action is
        MultiSelect -> Step(Model.toggle_selected(model))
        MultiConfirm -> Step(ST.to_confirmation_state(model))
        CursorUp -> Step(Model.move_cursor(model, Up))
        CursorDown -> Step(Model.move_cursor(model, Down))
        GoBack -> Step(ST.to_main_menu_state(model))
        NextPage -> Step(Model.next_page(model))
        PrevPage -> Step(Model.prev_page(model))
        _ -> Step(model)

## Map the user action to the appropriate state transition from the Search state
search_handler : Model, UserAction -> [Step Model, Done Model]
search_handler = |model, action|
    when action is
        SearchGo ->
            when model.sender is
                PlatformSelect(_) -> Step(ST.to_platform_select_state(model))
                PackageSelect(_) -> Step(ST.to_package_select_state(model))
                _ -> Step(model)

        TextBackspace -> Step(Model.backspace_buffer(model))
        TextInput(key) ->
            ch = key |> Keys.key_to_str |> |str| if Str.is_empty(str) then None else Char(str)
            when ch is
                Char(c) -> Step(Model.append_to_buffer(model, c))
                None -> Step(model)

        Cancel ->
            when model.sender is
                PlatformSelect(_) -> Step(model |> Model.clear_buffer |> ST.to_platform_select_state)
                PackageSelect(_) -> Step(model |> Model.clear_buffer |> ST.to_package_select_state)
                _ -> Step(model)

        GoBack ->
            when model.sender is
                PlatformSelect(_) -> Step(ST.to_platform_select_state(model))
                PackageSelect(_) -> Step(ST.to_package_select_state(model))
                _ -> Step(model)

        _ -> Step(model)

## Map the user action to the appropriate state transition from the InputAppName state
input_app_name_handler : Model, UserAction -> [Step Model, Done Model]
input_app_name_handler = |model, action|
    when action is
        TextSubmit -> Step(ST.to_platform_select_state(model))
        TextInput(key) ->
            ch = key |> Keys.key_to_str |> |str| if Str.is_empty(str) then None else Char(str)
            when ch is
                Char(c) -> Step(Model.append_to_buffer(model, c))
                None -> Step(model)

        TextBackspace -> Step(Model.backspace_buffer(model))
        GoBack -> Step(ST.to_main_menu_state(model))
        _ -> Step(model)

## Map the user action to the appropriate state transition from the Confirmation state
confirmation_handler : Model, UserAction -> [Step Model, Done Model]
confirmation_handler = |model, action|
    when action is
        Finish -> Done(ST.to_finished_state(model))
        GoBack ->
            when model.sender is
                PackageSelect(_) -> Step(ST.to_package_select_state(model))
                UpdateSelect(_) -> Step(ST.to_update_select_state(model))
                SettingsMenu(_) -> Step(ST.to_settings_menu_state(model))
                ChooseFlags({ choices }) ->
                    when choices is
                        App(_) | Package(_) -> Step(ST.to_package_select_state(model))
                        _ -> Step(model)

                _ -> Step(model)

        SetFlags -> Step(ST.to_choose_flags_state(model))
        _ -> Step(model)

choose_flags_handler : Model, UserAction -> [Step Model, Done Model]
choose_flags_handler = |model, action|
    when action is
        MultiSelect -> Step(Model.toggle_selected(model))
        MultiConfirm -> Step(ST.to_confirmation_state(model))
        CursorUp -> Step(Model.move_cursor(model, Up))
        CursorDown -> Step(Model.move_cursor(model, Down))
        NextPage -> Step(Model.next_page(model))
        PrevPage -> Step(Model.prev_page(model))
        GoBack -> Step(ST.to_confirmation_state(model))
        _ -> Step(model)

## Map the user action to the appropriate state transition from the Splash state
splash_handler : Model, UserAction -> [Step Model, Done Model]
splash_handler = |model, action|
    when action is
        GoBack -> Step(ST.to_main_menu_state(model))
        _ -> Step(model)
