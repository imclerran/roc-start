module [
    Model,
    # empty_app_config,
    init,
    is_not_first_page,
    is_not_last_page,
    get_highlighted_index,
    get_highlighted_item,
    get_selected_items,
    menu_is_filtered,
]

import ansi.ANSI
import Choices exposing [Choices]

Model : {
    screen : ANSI.ScreenSize,
    cursor : ANSI.CursorPosition,
    menu_row : U16,
    page_first_item : U64,
    menu : List Str,
    full_menu : List Str,
    selected : List Str,
    inputs : List ANSI.Input,
    package_list : List Str,
    platform_list : List Str,
    state : State,
}

State : [
    TypeSelect { choices : Choices },
    InputAppName { name_buffer : List U8, choices : Choices },
    Search { search_buffer : List U8, choices : Choices, sender : [Platform, Package] },
    PlatformSelect { choices : Choices },
    PackageSelect { choices : Choices },
    Confirmation { choices : Choices },
    Finished { choices : Choices },
    Splash { choices : Choices },
    UserExited,
]

# empty_app_config = { file_name: "", platform: "", packages: [], type: App }

no_choices = NothingToDo

## Initialize the model
init : List Str, List Str, { state ?? State } -> Model
init = |platform_list, package_list, { state ?? TypeSelect({ choices: no_choices }) }| {
    screen: { width: 0, height: 0 },
    cursor: { row: 2, col: 2 },
    menu_row: 2,
    page_first_item: 0,
    menu: ["App", "Package"],
    full_menu: ["App", "Package"],
    platform_list,
    package_list,
    selected: [],
    inputs: List.with_capacity(1000),
    state,
}

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
        PlatformSelect(_) -> List.len(model.full_menu) < List.len(model.platform_list)
        PackageSelect(_) -> List.len(model.full_menu) < List.len(model.package_list)
        _ -> Bool.false
