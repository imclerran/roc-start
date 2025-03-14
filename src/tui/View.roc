module [
    render,
    # render_main_menu,
    # render_settings_menu,
    # render_settings_submenu,
    # render_input_app_name,
    # render_platform_select,
    # render_package_select,
    # render_version_select,
    # render_update_select,
    # render_search,
    # render_confirmation,
    # render_splash,
    # render_box,
]

import AsciiArt
import BoxStyle exposing [BoxStyle, border]
import Controller exposing [UserAction]
import Model exposing [Model]
import ansi.ANSI
import Choices
import themes.Theme exposing [Theme]

# Main render function for rendering the model
render : Model, Theme -> List ANSI.DrawFn
render = |model, theme|
    when model.state is
        MainMenu(_) -> render_main_menu(model, theme)
        SettingsMenu(_) -> render_settings_menu(model, theme)
        SettingsSubmenu(_) -> render_settings_submenu(model, theme)
        InputAppName(_) -> render_input_app_name(model, theme)
        PlatformSelect(_) -> render_platform_select(model, theme)
        PackageSelect(_) -> render_package_select(model, theme)
        VersionSelect(_) -> render_version_select(model, theme)
        UpdateSelect(_) -> render_update_select(model, theme)
        Search(_) -> render_search(model, theme)
        Confirmation(_) -> render_confirmation(model, theme)
        Splash(_) -> render_splash(model, theme)
        _ -> []

## Render functions for each page
render_screen_prompt = |text, color| text |> ANSI.draw_text({ r: 1, c: 2, fg: color })
render_exit_prompt = |screen, color| " Ctrl+C : QUIT " |> ANSI.draw_text({ r: 0, c: screen.width - 17, fg: color })
render_controls_prompt = |text, screen, color| text |> ANSI.draw_text({ r: screen.height - 1, c: 2, fg: color })
render_outer_border = |screen, color| render_box(0, 0, screen.width, screen.height, CustomBorder({ tl: "╒", t: "═", tr: "╕" }), color)

## Control prompts for each user action
control_prompts_dict : Dict UserAction Str
control_prompts_dict =
    Dict.empty({})
    |> Dict.insert(SingleSelect, "ENTER : SELECT")
    |> Dict.insert(MultiSelect, "SPACE : SELECT")
    |> Dict.insert(VersionSelect, "V : VERSION")
    |> Dict.insert(MultiConfirm, "ENTER : CONFIRM")
    |> Dict.insert(TextSubmit, "ENTER : CONFIRM")
    |> Dict.insert(GoBack, "BKSP : BACK")
    |> Dict.insert(Search, "S : SEARCH")
    |> Dict.insert(ClearFilter, "ESC : FULL LIST")
    |> Dict.insert(SearchGo, "ENTER : SEARCH")
    |> Dict.insert(Cancel, "ESC : CANCEL")
    |> Dict.insert(Finish, "ENTER : FINISH")
    |> Dict.insert(CursorUp, "")
    |> Dict.insert(CursorDown, "")
    |> Dict.insert(TextInput(None), "")
    |> Dict.insert(TextBackspace, "")
    |> Dict.insert(Exit, "")
    |> Dict.insert(None, "")
    |> Dict.insert(Secret, "")
    |> Dict.insert(PrevPage, "< PREV")
    |> Dict.insert(NextPage, "> NEXT")

control_prompts_trunc_dict : Dict UserAction Str
control_prompts_trunc_dict =
    Dict.empty({})
    |> Dict.insert(SingleSelect, "ENTER : SEL")
    |> Dict.insert(MultiSelect, "SPACE : SEL")
    |> Dict.insert(VersionSelect, "V : VER")
    |> Dict.insert(MultiConfirm, "ENTER : CONF")
    |> Dict.insert(TextSubmit, "ENTER : CONF")
    |> Dict.insert(GoBack, "BKSP : BCK")
    |> Dict.insert(Search, "S : SRCH")
    |> Dict.insert(ClearFilter, "ESC : CLR")
    |> Dict.insert(SearchGo, "ENTER : SRCH")
    |> Dict.insert(Cancel, "ESC : CNCL")
    |> Dict.insert(Finish, "ENTER : GO")
    |> Dict.insert(CursorUp, "")
    |> Dict.insert(CursorDown, "")
    |> Dict.insert(TextInput(None), "")
    |> Dict.insert(TextBackspace, "")
    |> Dict.insert(Exit, "")
    |> Dict.insert(None, "")
    |> Dict.insert(Secret, "")
    |> Dict.insert(PrevPage, "<")
    |> Dict.insert(NextPage, ">")

## Shortened control prompts for smaller screens
control_prompts_short_dict : Dict UserAction Str
control_prompts_short_dict =
    Dict.empty({})
    |> Dict.insert(SingleSelect, "ENTER")
    |> Dict.insert(MultiSelect, "SPACE")
    |> Dict.insert(VersionSelect, "V")
    |> Dict.insert(MultiConfirm, "ENTER")
    |> Dict.insert(TextSubmit, "ENTER")
    |> Dict.insert(GoBack, "BKSP")
    |> Dict.insert(Search, "S")
    |> Dict.insert(ClearFilter, "ESC")
    |> Dict.insert(SearchGo, "ENTER")
    |> Dict.insert(Cancel, "ESC")
    |> Dict.insert(Finish, "ENTER")
    |> Dict.insert(CursorUp, "")
    |> Dict.insert(CursorDown, "")
    |> Dict.insert(TextInput(None), "")
    |> Dict.insert(TextBackspace, "")
    |> Dict.insert(Exit, "")
    |> Dict.insert(None, "")
    |> Dict.insert(Secret, "")
    |> Dict.insert(PrevPage, "<")
    |> Dict.insert(NextPage, ">")

## Build string with all available controls
controls_prompt_str : Model -> Str
controls_prompt_str = |model|
    actions = Controller.get_actions(model)
    long_str = build_control_prompt_str(actions, control_prompts_dict)
    prompt_len = Num.to_u16(Str.count_utf8_bytes(long_str))
    if prompt_len <= model.screen.width - 6 and prompt_len > 0 then
        " ${long_str} "
    else if prompt_len > 0 then
        prompt_med = build_control_prompt_str(actions, control_prompts_trunc_dict)
        prompt_med_len = Num.to_u16(Str.count_utf8_bytes(prompt_med))
        if prompt_med_len <= model.screen.width - 6 then
            " ${prompt_med} "
        else
            prompt_short = build_control_prompt_str(actions, control_prompts_short_dict)
            " ${prompt_short} "
    else
        ""

build_control_prompt_str : List UserAction, Dict UserAction Str -> Str
build_control_prompt_str = |actions, prompts_dict|
    divider = " | "
    actions
    |> List.map(
        |action|
            Dict.get(prompts_dict, action) |> Result.with_default(""),
    )
    |> List.drop_if(|str| Str.is_empty(str))
    |> Str.join_with(divider)

## Render a multi-line text with word wrapping
render_multi_line_text : List Str, { start_col : U16, start_row : U16, max_col : U16, wrap_col : U16, word_delim ?? Str, fg ?? ANSI.Color } -> List ANSI.DrawFn
render_multi_line_text = |words, { start_col, start_row, max_col, wrap_col, word_delim ?? " ", fg ?? Default }|
    first_line_width = max_col - start_col
    consecutive_widths = max_col - wrap_col
    delims = List.repeat(word_delim, (if List.len(words) == 0 then 0 else List.len(words) - 1)) |> List.append("")
    words_with_delims = List.map2(words, delims, |word, delim| Str.concat(word, delim))
    line_list =
        List.walk(
            words_with_delims,
            [],
            |lines, word|
                when lines is
                    [line] ->
                        if Num.to_u16((Str.count_utf8_bytes(line) + Str.count_utf8_bytes(word))) <= first_line_width then
                            [Str.concat(line, word)]
                        else
                            [line, word]

                    [.. as prev_lines, line] ->
                        if Num.to_u16((Str.count_utf8_bytes(line) + Str.count_utf8_bytes(word))) <= consecutive_widths then
                            List.concat(prev_lines, [Str.concat(line, word)])
                        else
                            List.concat(prev_lines, [line, word])

                    [] -> [word],
        )
    List.map_with_index(
        line_list,
        |line, idx|
            if idx == 0 then
                line |> ANSI.draw_text({ r: start_row, c: start_col, fg })
            else
                line |> ANSI.draw_text({ r: start_row + (Num.to_u16(idx)), c: wrap_col, fg }),
    )

render_main_menu : Model, Theme -> List ANSI.DrawFn
render_main_menu = |model, theme|
    List.join(
        [
            [
                render_exit_prompt(model.screen, theme.error),
                render_controls_prompt(controls_prompt_str(model), model.screen, theme.secondary),
            ],
            render_outer_border(model.screen, theme.primary),
            [
                "MAIN MENU:" |> render_screen_prompt(theme.secondary),
                ANSI.draw_cursor({ fg: theme.primary, char: ">" }),
            ],
            render_menu(model, theme),
        ],
    )

render_settings_menu : Model, Theme -> List ANSI.DrawFn
render_settings_menu = |model, theme|
    List.join(
        [
            [
                render_exit_prompt(model.screen, theme.error),
                render_controls_prompt(controls_prompt_str(model), model.screen, theme.secondary),
            ],
            render_outer_border(model.screen, theme.primary),
            [
                "SETTINGS:" |> render_screen_prompt(theme.secondary),
                ANSI.draw_cursor({ fg: theme.primary, char: ">" }),
            ],
            render_menu(model, theme),
        ],
    )

render_settings_submenu : Model, Theme -> List ANSI.DrawFn
render_settings_submenu = |model, theme|
    when model.state is
        SettingsSubmenu({ submenu }) ->
            prompt =
                when submenu is
                    Theme -> "DEFAULT THEME:"
                    Verbosity -> "DEFAULT VERBOSITY:"
            List.join(
                [
                    [
                        render_exit_prompt(model.screen, theme.error),
                        render_controls_prompt(controls_prompt_str(model), model.screen, theme.secondary),
                    ],
                    render_outer_border(model.screen, theme.primary),
                    [
                        prompt |> render_screen_prompt(theme.secondary),
                        ANSI.draw_cursor({ fg: theme.primary, char: ">" }),
                    ],
                    render_menu(model, theme),
                ],
            )

        _ -> []

## Generate the list of functions to draw the platform select page.
render_platform_select : Model, Theme -> List ANSI.DrawFn
render_platform_select = |model, theme|
    List.join(
        [
            [
                render_exit_prompt(model.screen, theme.error),
                render_controls_prompt(controls_prompt_str(model), model.screen, theme.secondary),
            ],
            render_outer_border(model.screen, theme.primary),
            [
                "SELECT A PLATFORM:" |> render_screen_prompt(theme.secondary),
                ANSI.draw_cursor({ fg: theme.primary, char: ">" }),
            ],
            render_menu(model, theme),
        ],
    )

## Generate the list of functions to draw the package select page.
render_package_select : Model, Theme -> List ANSI.DrawFn
render_package_select = |model, theme|
    List.join(
        [
            [
                render_exit_prompt(model.screen, theme.error),
                render_controls_prompt(controls_prompt_str(model), model.screen, theme.secondary),
            ],
            render_outer_border(model.screen, theme.primary),
            [
                "SELECT 0+ PACKAGES:" |> render_screen_prompt(theme.secondary),
                ANSI.draw_cursor({ fg: theme.primary, char: ">" }),
            ],
            render_multiple_choice_menu(model, theme),
        ],
    )

## Generate the list of functions to draw the version select page.
render_version_select : Model, Theme -> List ANSI.DrawFn
render_version_select = |model, theme|
    when model.state is
        VersionSelect({ repo }) ->
            List.join(
                [
                    [
                        render_exit_prompt(model.screen, theme.error),
                        render_controls_prompt(controls_prompt_str(model), model.screen, theme.secondary),
                    ],
                    render_outer_border(model.screen, theme.primary),
                    [
                        "SELECT A VERSION (${repo.name}):" |> render_screen_prompt(theme.secondary),
                        ANSI.draw_cursor({ fg: theme.primary, char: ">" }),
                    ],
                    render_menu(model, theme),
                ],
            )

        _ -> []

render_update_select : Model, Theme -> List ANSI.DrawFn
render_update_select = |model, theme|
    List.join(
        [
            [
                render_exit_prompt(model.screen, theme.error),
                render_controls_prompt(controls_prompt_str(model), model.screen, theme.secondary),
            ],
            render_outer_border(model.screen, theme.primary),
            [
                "SELECT 0+ UPDATES:" |> render_screen_prompt(theme.secondary),
                ANSI.draw_cursor({ fg: theme.primary, char: ">" }),
            ],
            render_multiple_choice_menu(model, theme),
        ],
    )

## Generate the list of functions to draw the app name input page.
render_input_app_name : Model, Theme -> List ANSI.DrawFn
render_input_app_name = |model, theme|
    when model.state is
        InputAppName({ name_buffer }) ->
            buffer_text = name_buffer |> Str.from_utf8_lossy
            List.join(
                [
                    [
                        render_exit_prompt(model.screen, theme.error),
                        render_controls_prompt(controls_prompt_str(model), model.screen, theme.secondary),
                    ],
                    render_outer_border(model.screen, theme.primary),
                    if List.is_empty(name_buffer) then [" (Leave blank for \"main\"):" |> ANSI.draw_text({ r: 1, c: 20, fg: theme.secondary })] else [],
                    [
                        "ENTER THE APP NAME:" |> render_screen_prompt(theme.secondary),
                        ANSI.draw_cursor({ fg: theme.primary, char: ">" }),
                        buffer_text |> ANSI.draw_text({ r: model.menu_row, c: 4, fg: theme.secondary }),
                    ],
                ],
            )

        _ -> []

## Generate the list of functions to draw the search page.
render_search : Model, Theme -> List ANSI.DrawFn
render_search = |model, theme|
    when model.state is
        Search({ search_buffer }) ->
            search_prompt =
                when model.sender is
                    PackageSelect(_) -> "SEARCH FOR A PACKAGE:"
                    PlatformSelect(_) -> "SEARCH FOR A PLATFORM:"
                    _ -> "SEARCH:"
            # if sender == Package then "SEARCH FOR A PACKAGE:" else "SEARCH FOR A PLATFORM:"
            buffer_text = search_buffer |> Str.from_utf8_lossy
            List.join(
                [
                    [
                        render_exit_prompt(model.screen, theme.error),
                        render_controls_prompt(controls_prompt_str(model), model.screen, theme.secondary),
                    ],
                    render_outer_border(model.screen, theme.primary),
                    [
                        search_prompt |> render_screen_prompt(theme.secondary),
                        ANSI.draw_cursor({ fg: theme.primary, char: ">" }),
                        buffer_text |> ANSI.draw_text({ r: model.menu_row, c: 4, fg: theme.secondary }),
                    ],
                ],
            )

        _ -> []

## Generate the list of functions to draw the confirmation page.
render_confirmation : Model, Theme -> List ANSI.DrawFn
render_confirmation = |model, theme|
    when Model.get_choices(model) is
        App(_) -> render_app_confirmation(model, theme)
        Package(_) -> render_package_confirmation(model, theme)
        Upgrade(_) -> render_upgrade_confirmation(model, theme)
        Update(_) -> render_update_confirmation(model, theme)
        Config(_) -> render_config_confirmation(model, theme)
        _ -> []

render_app_confirmation : Model, Theme -> List ANSI.DrawFn
render_app_confirmation = |model, theme|
    choices = Model.get_choices(model)
    filename = choices |> Choices.get_filename
    platform = choices |> Choices.get_platform |> |p| if Str.is_empty(p.version) then p.name else "${p.name}:${p.version}"
    packages = choices |> Choices.get_packages |> List.map(|p| if Str.is_empty(p.version) then p.name else "${p.name}:${p.version}")
    List.join(
        [
            [
                render_exit_prompt(model.screen, theme.error),
                render_controls_prompt(controls_prompt_str(model), model.screen, theme.secondary),
            ],
            render_outer_border(model.screen, theme.primary),
            [
                "APP CHOICES:" |> render_screen_prompt(theme.secondary),
                "App name:" |> ANSI.draw_text({ r: model.menu_row, c: 2, fg: theme.primary }),
                filename |> ANSI.draw_text({ r: model.menu_row, c: 12, fg: theme.secondary }),
                "Platform:" |> ANSI.draw_text({ r: model.menu_row + 1, c: 2, fg: theme.primary }),
                platform |> ANSI.draw_text({ r: model.menu_row + 1, c: 12, fg: theme.secondary }),
                "Packages:" |> ANSI.draw_text({ r: model.menu_row + 2, c: 2, fg: theme.primary }),
            ],
            if List.is_empty(packages) then
                [
                    "none" |> ANSI.draw_text({ r: model.menu_row + 2, c: 12, fg: theme.secondary }),
                ]
            else
                render_multi_line_text(
                    packages,
                    {
                        start_col: 12,
                        start_row: model.menu_row + 2,
                        max_col: model.screen.width - 1,
                        wrap_col: 2,
                        word_delim: ", ",
                        fg: theme.secondary,
                    },
                ),
        ],
    )

render_package_confirmation : Model, Theme -> List ANSI.DrawFn
render_package_confirmation = |model, theme|
    choices = Model.get_choices(model)
    packages = choices |> Choices.get_packages |> List.map(|p| if Str.is_empty(p.version) then p.name else "${p.name}:${p.version}")
    List.join(
        [
            [
                render_exit_prompt(model.screen, theme.error),
                render_controls_prompt(controls_prompt_str(model), model.screen, theme.secondary),
            ],
            render_outer_border(model.screen, theme.primary),
            [
                "PACKAGE CHOICES:" |> render_screen_prompt(theme.secondary),
                "Packages:" |> ANSI.draw_text({ r: model.menu_row, c: 2, fg: theme.primary }),
            ],
            if List.is_empty(packages) then
                [
                    "none" |> ANSI.draw_text({ r: model.menu_row, c: 12, fg: theme.secondary }),
                ]
            else
                render_multi_line_text(
                    packages,
                    {
                        start_col: 12,
                        start_row: model.menu_row,
                        max_col: model.screen.width - 1,
                        wrap_col: 2,
                        word_delim: ", ",
                        fg: theme.secondary,
                    },
                ),
        ],
    )

render_update_confirmation : Model, Theme -> List ANSI.DrawFn
render_update_confirmation = |model, theme|
    choices = Model.get_choices(model)
    updates = choices |> Choices.get_updates |> |lu| if List.is_empty(lu) then ["Platforms", "Packages", "Scripts", "Themes"] else lu
    List.join(
        [
            [
                render_exit_prompt(model.screen, theme.error),
                render_controls_prompt(controls_prompt_str(model), model.screen, theme.secondary),
            ],
            render_outer_border(model.screen, theme.primary),
            [
                "UPDATE CHOICES:" |> render_screen_prompt(theme.secondary),
                "Updates:" |> ANSI.draw_text({ r: model.menu_row, c: 2, fg: theme.primary }),
            ],
            render_multi_line_text(
                updates,
                {
                    start_col: 11,
                    start_row: model.menu_row,
                    max_col: model.screen.width - 1,
                    wrap_col: 2,
                    word_delim: ", ",
                    fg: theme.secondary,
                },
            ),
        ],
    )

render_config_confirmation : Model, Theme -> List ANSI.DrawFn
render_config_confirmation = |model, theme|
    choices = Model.get_choices(model)
    colors = ("Theme", Choices.get_config_theme(choices))
    verbosity = ("Verbosity", Choices.get_config_verbosity(choices))
    platform = ("Platform", Choices.get_config_platform(choices))
    changes =
        List.keep_oks(
            [colors, verbosity, platform],
            |config|
                when config.1 is
                    Ok(value) -> Ok("${config.0}: ${value}")
                    Err(_) -> Err(NoValue),
        )
        |> |cs| if List.is_empty(cs) then ["Settings unchanged"] else cs
    List.join(
        [
            [
                render_exit_prompt(model.screen, theme.error),
                render_controls_prompt(controls_prompt_str(model), model.screen, theme.secondary),
            ],
            render_outer_border(model.screen, theme.primary),
            [
                "CONFIG CHOICES:" |> render_screen_prompt(theme.secondary),
                "Changes:" |> ANSI.draw_text({ r: model.menu_row, c: 2, fg: theme.primary }),
            ],
            changes |> List.map_with_index(|change, i| change |> ANSI.draw_text({ r: model.menu_row + Num.int_cast(i + 1), c: 2, fg: theme.secondary })),
        ],
    )

render_upgrade_confirmation : Model, Theme -> List ANSI.DrawFn
render_upgrade_confirmation = |model, theme|
    choices = Model.get_choices(model)
    when choices is
        Upgrade({ filename, platform: maybe_platform, packages: package_repos }) ->
            { platform, render_platform, platform_offset } =
                when maybe_platform is
                    Ok({ name, version }) ->
                        platform_str = if Str.is_empty(version) then name else "${name}:${version}"
                        { platform: platform_str, render_platform: Bool.true, platform_offset: 1 }

                    Err(_) -> { platform: "", render_platform: Bool.false, platform_offset: 0 }
            packages = package_repos |> List.map(|p| if Str.is_empty(p.version) then p.name else "${p.name}:${p.version}")
            List.join(
                [
                    [
                        render_exit_prompt(model.screen, theme.error),
                        render_controls_prompt(controls_prompt_str(model), model.screen, theme.secondary),
                    ],
                    render_outer_border(model.screen, theme.primary),
                    [
                        "UPGRADE CHOICES:" |> render_screen_prompt(theme.secondary),
                        "File name: " |> ANSI.draw_text({ r: model.menu_row, c: 2, fg: theme.primary }),
                        filename |> ANSI.draw_text({ r: model.menu_row, c: 13, fg: theme.secondary }),
                    ],
                    if render_platform then
                        [
                            "Platform:" |> ANSI.draw_text({ r: model.menu_row + 1, c: 2, fg: theme.primary }),
                            platform |> ANSI.draw_text({ r: model.menu_row + 1, c: 12, fg: theme.secondary }),
                        ]
                    else
                        [],
                    [
                        "Packages:" |> ANSI.draw_text({ r: model.menu_row + platform_offset + 1, c: 2, fg: theme.primary }),
                    ],
                    if List.is_empty(packages) then
                        [
                            "none" |> ANSI.draw_text({ r: model.menu_row + platform_offset + 1, c: 12, fg: theme.secondary }),
                        ]
                    else
                        render_multi_line_text(
                            packages,
                            {
                                start_col: 12,
                                start_row: model.menu_row + platform_offset + 1,
                                max_col: model.screen.width - 1,
                                wrap_col: 2,
                                word_delim: ", ",
                                fg: theme.secondary,
                            },
                        ),
                ],
            )

        _ -> []

## Generate the list of functions to draw a box.
render_box : U16, U16, U16, U16, BoxStyle, ANSI.Color -> List ANSI.DrawFn
render_box = |col, row, width, height, style, color| [
    ANSI.draw_h_line({ r: row, c: col, len: 1, char: border(TopLeft, style), fg: color }),
    ANSI.draw_h_line({ r: row, c: col + 1, len: width - 2, char: border(Top, style), fg: color }),
    ANSI.draw_h_line({ r: row, c: col + width - 1, len: 1, char: border(TopRight, style), fg: color }),
    ANSI.draw_v_line({ r: row + 1, c: col, len: height - 2, char: border(Left, style), fg: color }),
    ANSI.draw_v_line({ r: row + 1, c: col + width - 1, len: height - 2, char: border(Right, style), fg: color }),
    ANSI.draw_h_line({ r: row + height - 1, c: col, len: 1, char: border(BotLeft, style), fg: color }),
    ANSI.draw_h_line({ r: row + height - 1, c: col + 1, len: width - 2, char: border(Bot, style), fg: color }),
    ANSI.draw_h_line({ r: row + height - 1, c: col + width - 1, len: 1, char: border(BotRight, style), fg: color }),
]

## Generate the list of functions to draw a single select menu.
render_menu : Model, Theme -> List ANSI.DrawFn
render_menu = |model, theme|
    List.map_with_index(
        model.menu,
        |item, idx|
            row = Num.to_u16(idx) + model.menu_row
            if model.cursor.row == row then
                color = if item != "Exit" then theme.primary else theme.error
                "> ${item}" |> ANSI.draw_text({ r: row, c: 2, fg: color })
            else
                "- ${item}" |> ANSI.draw_text({ r: row, c: 2, fg: theme.tertiary }),
    )

## Generate the list of functions to draw a multiple choice menu.
render_multiple_choice_menu : Model, Theme -> List ANSI.DrawFn
render_multiple_choice_menu = |model, theme|
    is_selected = |item| List.contains(model.selected, item)
    checked_items = List.map(model.menu, |item| if is_selected(item) then "[X] ${item}" else "[ ] ${item}")
    List.map_with_index(
        checked_items,
        |item, idx|
            row = Num.to_u16(idx) + model.menu_row
            if model.cursor.row == row then
                "> ${item}" |> ANSI.draw_text({ r: row, c: 2, fg: theme.primary })
            else
                "- ${item}" |> ANSI.draw_text({ r: row, c: 2, fg: theme.tertiary }),
    )

render_splash : Model, Theme -> List ANSI.DrawFn
render_splash = |model, theme|
    List.join(
        [
            [
                render_exit_prompt(model.screen, theme.error),
                render_controls_prompt(controls_prompt_str(model), model.screen, theme.secondary),
            ],
            render_outer_border(model.screen, theme.primary),
            render_splash_by_size(model.screen),
        ],
    )

render_splash_by_size : ANSI.ScreenSize -> List ANSI.DrawFn
render_splash_by_size = |screen|
    art = choose_splash_art(screen)
    start_row = (screen.height - art.height) // 2
    start_col = (screen.width - art.width) // 2
    List.join(
        [
            render_art_accent(art, screen),
            render_ascii_art(art, start_row, start_col),
        ],
    )

render_ascii_art : AsciiArt.Art, U16, U16 -> List ANSI.DrawFn
render_ascii_art = |art, start_row, start_col|
    List.map(
        art.art,
        |elem|
            ANSI.draw_text(elem.text, { r: start_row + elem.r, c: start_col + elem.c, fg: elem.color }),
    )

choose_splash_art : ANSI.ScreenSize -> AsciiArt.Art
choose_splash_art = |screen|
    if
        (screen.height >= (AsciiArt.roc_large_colored.height + 2))
        and (screen.width >= (AsciiArt.roc_large_colored.width + 2))
    then
        AsciiArt.roc_large_colored
    else if
        (screen.height >= (AsciiArt.roc_small_colored.height + 2))
        and (screen.width >= (AsciiArt.roc_small_colored.width + 2))
    then
        AsciiArt.roc_small_colored
    else
        AsciiArt.roc_start_colored

render_art_accent : AsciiArt.Art, ANSI.ScreenSize -> List ANSI.DrawFn
render_art_accent = |art, screen|
    start_row = (screen.height - art.height) // 2
    start_col = (screen.width - art.width) // 2
    if art == AsciiArt.roc_large_colored then
        List.map_with_index(
            AsciiArt.roc_start,
            |line, idx|
                ANSI.draw_text(line, { r: start_row + 30 + Num.to_u16(idx), c: start_col + 50, fg: Standard Cyan }),
        )
    else if art == AsciiArt.roc_small_colored then
        [
            "roc start" |> ANSI.draw_text({ r: start_row + 11, c: start_col + 16, fg: Standard Cyan }),
            "quick start cli" |> ANSI.draw_text({ r: start_row + 12, c: start_col + 16, fg: Standard Cyan }),
        ]
    else
        [" quick start cli" |> ANSI.draw_text({ r: start_row + 5, c: start_col, fg: Standard Cyan })]
