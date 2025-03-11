module
    {
        read_bytes!,
        write_bytes!,
        env_var!,
        is_file!,
        http_send!,
    } -> [load_themes!, update_themes!]

import parse.Parse as P
import json.Json
import Theme exposing [Theme]

themes_file_url = "https://raw.githubusercontent.com/imclerran/roc-repo/refs/heads/main/themes/.rocstartthemes"

update_themes! = |save_path|
    file_contents =
        http_send!(
            {
                uri: themes_file_url,
                method: GET,
                body: [],
                headers: [],
                timeout_ms: TimeoutMilliseconds(3000),
            },
        )
        |> Result.map_ok(|resp| if resp.status == 200 then resp.body else [])
        |> Result.map_err(|_| HttpError)?
    if !List.is_empty(file_contents) then
        write_bytes!(file_contents, save_path)
    else
        Ok({})

file_exists! = |path| is_file!(path) |> Result.with_default(Bool.false)

load_themes! : {} => List Theme
load_themes! = |{}|
    home_res = env_var!("HOME")
    home =
        if home_res == Err(HomeVarNotSet) then
            return [Theme.default]
        else
            home_res |> Result.with_default("")

    file_path = "${home}/.rocstartthemes"
    if file_exists!(file_path) then
        themes = read_theme_file!(file_path) |> List.map(json_to_theme)
        List.append(themes, Theme.default)
    else
        update_res = update_themes!(file_path)
        when update_res is
            Ok(_) ->
                themes = read_theme_file!(file_path) |> List.map(json_to_theme)
                List.append(themes, Theme.default)

            Err(_) ->
                [Theme.default]

read_theme_file! = |file_path|
    file_contents =
        read_bytes!(file_path)
        |> Result.with_default([])
    decoded : Decode.DecodeResult (List JsonTheme)
    decoded = Decode.from_bytes_partial(file_contents, Json.utf8)
    decoded |> .result |> Result.with_default([])

JsonTheme : {
    name : Str,
    primary : Str,
    secondary : Str,
    tertiary : Str,
    okay : Str,
    warn : Str,
    error : Str,
}

json_to_theme : JsonTheme -> Theme
json_to_theme = |json_theme| {
    name: json_theme.name,
    primary: parse_hex_color(json_theme.primary) |> Result.with_default(Default),
    secondary: parse_hex_color(json_theme.secondary) |> Result.with_default(Default),
    tertiary: parse_hex_color(json_theme.tertiary) |> Result.with_default(Default),
    okay: parse_hex_color(json_theme.okay) |> Result.with_default(Default),
    warn: parse_hex_color(json_theme.warn) |> Result.with_default(Default),
    error: parse_hex_color(json_theme.error) |> Result.with_default(Default),
}

parse_hex_color = |str| hex_color(str) |> P.finalize |> Result.map_err(|_| InvalidHexColor)

hex_color = pound_sign |> P.rhs(P.zip_3(hex_pair, hex_pair, hex_pair)) |> P.map(|(r, g, b)| Rgb((r, g, b)) |> Ok)

pound_sign = P.char |> P.filter(|c| c == '#')

hex_char = P.char |> P.filter(is_hex_digit)
is_hex_digit = |c| (c >= '0' and c <= '9') or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F')

hex_pair = P.zip(hex_char, hex_char) |> P.map(|(a, b)| num_from_hex_char(a) * 16 + num_from_hex_char(b) |> Ok)

num_from_hex_char = |c|
    if c >= '0' and c <= '9' then
        c - 48 |> Num.to_u8
    else if c >= 'a' and c <= 'f' then
        c - 87 |> Num.to_u8
    else if c >= 'A' and c <= 'F' then
        c - 55 |> Num.to_u8
    else
        0

expect num_from_hex_char('0') == 0
expect num_from_hex_char('9') == 9
expect num_from_hex_char('a') == 10
expect num_from_hex_char('f') == 15
expect num_from_hex_char('A') == 10
expect num_from_hex_char('F') == 15
