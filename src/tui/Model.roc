module [
    Model,
    init,
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

State : [
    MainMenu { choices : Choices },
    SettingsMenu { choices : Choices },
    SettingsSubmenu { choices : Choices, submenu : [Theme, Verbosity] },
    InputAppName { name_buffer : List U8, choices : Choices },
    Search { search_buffer : List U8, choices : Choices, prior_sender : State },
    PlatformSelect { choices : Choices },
    PackageSelect { choices : Choices },
    VersionSelect { choices : Choices, repo : { name : Str, version : Str } },
    UpdateSelect { choices : Choices },
    Confirmation { choices : Choices },
    ChooseFlags { choices : Choices },
    Finished { choices : Choices },
    Splash { choices : Choices },
    UserExited,
]

no_choices = NothingToDo

## Initialize the model
init : Dict Str (List RepositoryRelease), Dict Str (List RepositoryRelease), { state ?? State, theme_names ?? List Str } -> Model
init = |platforms, packages, { state ?? MainMenu({ choices: no_choices }), theme_names ?? ["default"] }|
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
        _ -> no_choices

get_buffer_len : Model -> U64
get_buffer_len = |model|
    when model.state is
        InputAppName({ name_buffer }) -> List.len(name_buffer)
        Search({ search_buffer }) -> List.len(search_buffer)
        _ -> 0
