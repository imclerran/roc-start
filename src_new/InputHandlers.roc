module [handle_input]

import ansi.ANSI
import Model exposing [Model]
import Controller

handle_input : Model, ANSI.Input -> [Step Model, Done Model]
handle_input = |model, input|
    when model.state is
        MainMenu(_) -> handle_main_menu_input(model, input)
        InputAppName(_) -> handle_input_app_name_input(model, input)
        PlatformSelect(_) -> handle_platform_select_input(model, input)
        PackageSelect(_) -> handle_package_select_input(model, input)
        Search(_) -> handle_search_input(model, input)
        Confirmation(_) -> handle_confirmation_input(model, input)
        Splash(_) -> handle_splash_input(model, input)
        _ -> handle_default_input(model, input)

## Default input handler which ensures that the program can always be exited.
## This ensures that even if you forget to handle input for a state, or end up
## in a state that doesn't have an input handler, the program can still be exited.
handle_default_input : Model, ANSI.Input -> [Step Model, Done Model]
handle_default_input = |model, input|
    action =
        when input is
            Ctrl(C) -> Exit
            _ -> None
    Controller.apply_action({ model, action })

handle_main_menu_input : Model, ANSI.Input -> [Step Model, Done Model]
handle_main_menu_input = |model, input|
    action =
        when input is
            Ctrl(C) -> Exit
            Action(Enter) -> SingleSelect
            Arrow(Up) -> CursorUp
            Arrow(Down) -> CursorDown
            Arrow(Right) -> NextPage
            Symbol(GreaterThanSign) -> NextPage
            Symbol(FullStop) -> NextPage
            Arrow(Left) -> PrevPage
            Symbol(LessThanSign) -> PrevPage
            Symbol(Comma) -> PrevPage
            _ -> None
    Controller.apply_action({ model, action })

## The input handler for the InputAppName state.
handle_input_app_name_input : Model, ANSI.Input -> [Step Model, Done Model]
handle_input_app_name_input = |model, input|
    buffer_len =
        when model.state is
            InputAppName({ name_buffer }) -> List.len(name_buffer)
            _ -> 0
    (action, key_press) =
        when input is
            Ctrl(C) -> (Exit, None)
            Action(Enter) -> (TextSubmit, None)
            Ctrl(H) -> if buffer_len == 0 then (GoBack, None) else (TextBackspace, None)
            Action(Delete) -> if buffer_len == 0 then (GoBack, None) else (TextBackspace, None)
            Action(Space) -> (TextInput, Action(Space))
            Symbol(symbol) -> (TextInput, Symbol(symbol))
            Number(number) -> (TextInput, Number(number))
            Lower(letter) -> (TextInput, Lower(letter))
            Upper(letter) -> (TextInput, Lower(letter))
            _ -> (None, None)
    Controller.apply_action({ model, action, key_press })

## The input handler for the PlatformSelect state.
handle_platform_select_input : Model, ANSI.Input -> [Step Model, Done Model]
handle_platform_select_input = |model, input|
    action =
        when input is
            Ctrl(C) -> Exit
            Lower(S) -> Search
            Upper(S) -> Search
            Action(Enter) -> SingleSelect
            Arrow(Up) -> CursorUp
            Arrow(Down) -> CursorDown
            Action(Delete) -> GoBack
            Action(Escape) -> ClearFilter
            Arrow(Right) -> NextPage
            Symbol(GreaterThanSign) -> NextPage
            Symbol(FullStop) -> NextPage
            Arrow(Left) -> PrevPage
            Symbol(LessThanSign) -> PrevPage
            Symbol(Comma) -> PrevPage
            _ -> None
    Controller.apply_action({ model, action })

## The input handler for the PackageSelect state.
handle_package_select_input : Model, ANSI.Input -> [Step Model, Done Model]
handle_package_select_input = |model, input|
    action =
        when input is
            Ctrl(C) -> Exit
            Lower(S) -> Search
            Upper(S) -> Search
            Action(Enter) -> MultiConfirm
            Action(Space) -> MultiSelect
            Arrow(Up) -> CursorUp
            Arrow(Down) -> CursorDown
            Action(Delete) -> GoBack
            Action(Escape) -> ClearFilter
            Arrow(Right) -> NextPage
            Symbol(GreaterThanSign) -> NextPage
            Symbol(FullStop) -> NextPage
            Arrow(Left) -> PrevPage
            Symbol(LessThanSign) -> PrevPage
            Symbol(Comma) -> PrevPage
            _ -> None
    Controller.apply_action({ model, action })

## The input handler for the Search state.
handle_search_input : Model, ANSI.Input -> [Step Model, Done Model]
handle_search_input = |model, input|
    (action, key_press) =
        when input is
            Ctrl(C) -> (Exit, None)
            Action(Enter) -> (SearchGo, None)
            Action(Escape) -> (Cancel, None)
            Ctrl(H) -> (TextBackspace, None)
            Action(Delete) -> (TextBackspace, None)
            Action(Space) -> (TextInput, Action(Space))
            Symbol(symbol) -> (TextInput, Symbol(symbol))
            Number(number) -> (TextInput, Number(number))
            Lower(letter) -> (TextInput, Lower(letter))
            Upper(letter) -> (TextInput, Upper(letter))
            _ -> (None, None)
    Controller.apply_action({ model, action, key_press })

## The input handler for the Confirmation state.
handle_confirmation_input : Model, ANSI.Input -> [Step Model, Done Model]
handle_confirmation_input = |model, input|
    action =
        when input is
            Ctrl(C) -> Exit
            Action(Enter) -> Finish
            Action(Delete) -> GoBack
            _ -> None
    Controller.apply_action({ model, action })

handle_splash_input : Model, ANSI.Input -> [Step Model, Done Model]
handle_splash_input = |model, input|
    action =
        when input is
            Ctrl(C) -> Exit
            Action(Delete) -> GoBack
            _ -> None
    Controller.apply_action({ model, action })
