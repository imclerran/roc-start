module [handle_input]

import ansi.ANSI exposing [Input]
import Model exposing [Model]
import UserAction exposing [UserAction]
import Controller

handle_input : Model, ANSI.Input -> [Step Model, Done Model]
handle_input = |model, input|
    input_handlers = Model.get_actions(model) |> List.map(action_to_input_handler)
    action = List.walk_until(
        input_handlers,
        None,
        |_, handler|
            when handler(model, input) is
                Ok(act) -> Break(act)
                Err(Unhandled) -> Continue(None),
    )
    Controller.apply_action(model, action)

action_to_input_handler = |action|
    when action is
        Cancel -> handle_cancel
        ClearFilter -> handle_clear_filter
        CursorDown -> handle_cursor_down
        CursorUp -> handle_cursor_up
        Exit -> handle_exit
        Finish -> handle_finish
        GoBack -> handle_go_back
        MultiConfirm -> handle_multi_confirm
        MultiSelect -> handle_multi_select
        VersionSelect -> handle_version_select
        NextPage -> handle_next_page
        PrevPage -> handle_prev_page
        Search -> handle_search
        SearchGo -> handle_search_go
        SingleSelect -> handle_single_select
        TextInput(None) -> handle_text_input
        TextBackspace -> handle_text_backspace
        TextSubmit -> handle_text_submit
        SetFlags -> handle_set_flags
        Secret -> handle_secret
        Continue -> handle_continue
        _ -> unhandled

handle_cancel : Model, Input -> Result UserAction [Unhandled]
handle_cancel = |_model, input|
    when input is
        Action(Escape) -> Ok(Cancel)
        _ -> Err(Unhandled)

handle_clear_filter : Model, Input -> Result UserAction [Unhandled]
handle_clear_filter = |_model, input|
    when input is
        Action(Escape) -> Ok(ClearFilter)
        _ -> Err(Unhandled)

handle_cursor_down : Model, Input -> Result UserAction [Unhandled]
handle_cursor_down = |_model, input|
    when input is
        Arrow(Down) | Lower(J) -> Ok(CursorDown)
        _ -> Err(Unhandled)

handle_cursor_up : Model, Input -> Result UserAction [Unhandled]
handle_cursor_up = |_model, input|
    when input is
        Arrow(Up) | Lower(K) -> Ok(CursorUp)
        _ -> Err(Unhandled)

handle_exit : Model, Input -> Result UserAction [Unhandled]
handle_exit = |_model, input|
    when input is
        Ctrl(C) -> Ok(Exit)
        _ -> Err(Unhandled)

handle_finish : Model, Input -> Result UserAction [Unhandled]
handle_finish = |_model, input|
    when input is
        Action(Enter) -> Ok(Finish)
        _ -> Err(Unhandled)

handle_go_back : Model, Input -> Result UserAction [Unhandled]
handle_go_back = |model, input|
    buffer_len = Model.get_buffer_len(model)
    when input is
        Action(Delete) | Ctrl(H) if buffer_len == 0 -> Ok(GoBack)
        _ -> Err(Unhandled)

handle_multi_confirm : Model, Input -> Result UserAction [Unhandled]
handle_multi_confirm = |_model, input|
    when input is
        Action(Enter) -> Ok(MultiConfirm)
        _ -> Err(Unhandled)

handle_multi_select : Model, Input -> Result UserAction [Unhandled]
handle_multi_select = |_model, input|
    when input is
        Action(Space) -> Ok(MultiSelect)
        _ -> Err(Unhandled)

handle_version_select : Model, Input -> Result UserAction [Unhandled]
handle_version_select = |_model, input|
    when input is
        Upper(V) | Lower(V) -> Ok(VersionSelect)
        _ -> Err(Unhandled)

handle_next_page : Model, Input -> Result UserAction [Unhandled]
handle_next_page = |_model, input|
    when input is
        Arrow(Right) | Symbol(GreaterThanSign) | Symbol(FullStop) | Lower(L) -> Ok(NextPage)
        _ -> Err(Unhandled)

handle_prev_page : Model, Input -> Result UserAction [Unhandled]
handle_prev_page = |_model, input|
    when input is
        Arrow(Left) | Symbol(LessThanSign) | Symbol(Comma) | Lower(H) -> Ok(PrevPage)
        _ -> Err(Unhandled)

handle_search : Model, Input -> Result UserAction [Unhandled]
handle_search = |_model, input|
    when input is
        Lower(S) | Upper(S) -> Ok(Search)
        _ -> Err(Unhandled)

handle_search_go : Model, Input -> Result UserAction [Unhandled]
handle_search_go = |_model, input|
    when input is
        Action(Enter) -> Ok(SearchGo)
        _ -> Err(Unhandled)

handle_single_select : Model, Input -> Result UserAction [Unhandled]
handle_single_select = |_model, input|
    when input is
        Action(Enter) -> Ok(SingleSelect)
        _ -> Err(Unhandled)

handle_text_input : Model, Input -> Result UserAction [Unhandled]
handle_text_input = |_model, input|
    when input is
        Action(Space) -> Ok(TextInput(Action(Space)))
        Symbol(s) -> Ok(TextInput(Symbol(s)))
        Number(n) -> Ok(TextInput(Number(n)))
        Lower(l) | Upper(l) -> Ok(TextInput(Lower(l)))
        _ -> Err(Unhandled)

handle_text_backspace : Model, Input -> Result UserAction [Unhandled]
handle_text_backspace = |model, input|
    buffer_len = Model.get_buffer_len(model)
    when input is
        Ctrl(H) if buffer_len > 0 -> Ok(TextBackspace)
        Action(Delete) if buffer_len > 0 -> Ok(TextBackspace)
        _ -> Err(Unhandled)

handle_text_submit : Model, Input -> Result UserAction [Unhandled]
handle_text_submit = |_model, input|
    when input is
        Action(Enter) -> Ok(TextSubmit)
        _ -> Err(Unhandled)

handle_set_flags : Model, Input -> Result UserAction [Unhandled]
handle_set_flags = |_model, input|
    when input is
        Lower(F) | Upper(F) -> Ok(SetFlags)
        _ -> Err(Unhandled)

handle_secret : Model, Input -> Result UserAction [Unhandled]
handle_secret = |_model, input|
    when input is
        Symbol(GraveAccent) -> Ok(Secret)
        _ -> Err(Unhandled)

handle_continue : Model, Input -> Result UserAction [Unhandled]
handle_continue = |_model, input|
    when input is
        Action(Enter) -> Ok(Continue)
        _ -> Err(Unhandled)

unhandled : Model, Input -> Result UserAction [Unhandled]
unhandled = |_model, _input|
    Err(Unhandled)
