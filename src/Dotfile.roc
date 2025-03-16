module
    {
        env_var!,
        is_file!,
        read_utf8!,
        write_utf8!,
        load_themes!,
    } -> [Config, get_config!, load_dotfile!, load_custom_themes!, create_default_dotfile!, default_config, save_to_dotfile!, save_config!]

import rtils.StrUtils
import rtils.ListUtils
import parse.Parse as P
import json.Json
import themes.Theme exposing [Theme]
LogLevel : [Silent, Quiet, Verbose]

Config : { verbosity : LogLevel, theme : Theme, platform : { name : Str, version : Str } }

get_config! : {} => Config
get_config! = |{}|
    when load_dotfile!({}) is
        Ok(config) -> config
        Err(NoDotFileFound) ->
            new = create_default_dotfile!({})
            when new is
                Ok(config) -> config
                Err(_) -> default_config

        Err(_) -> default_config

config_to_str : Config -> Str
config_to_str = |config|
    verbosity =
        when config.verbosity is
            Verbose -> "verbose"
            Quiet -> "quiet"
            Silent -> "silent"
    platform_str =
        if config.platform.version == "" then
            config.platform.name
        else
            "${config.platform.name}=${config.platform.version}"
    """
    verbosity: ${verbosity}
    theme: ${config.theme.name}
    platform: ${platform_str}\n
    """

load_dotfile! : {} => Result Config [HomeVarNotSet, NoDotFileFound, InvalidDotFile, FileReadError]
load_dotfile! = |{}|
    home = 
        env_var!("HOME") 
        ? |_| HomeVarNotSet
        |> Str.drop_suffix("/")
    file_path = "${home}/.rocstartconfig"
    if file_exists!(file_path) then
        file_contents = read_utf8!(file_path) ? |_| FileReadError
        theme_list = load_themes!({})
        parse_dotfile(file_contents, theme_list) |> Result.map_err(|_| InvalidDotFile)
    else
        Err(NoDotFileFound)

file_exists! = |path| is_file!(path) |> Result.with_default(Bool.false)

parse_dotfile : Str, List Theme -> Result Config [InvalidDotFile]
parse_dotfile = |str, theme_list|
    lines = Str.to_utf8(str) |> ListUtils.split_with_delims_tail(|c| c == '\n') |> List.map(Str.from_utf8_lossy)
    verbosity =
        when
            lines |> List.keep_oks(parse_verbosity)
        is
            [level, ..] -> level
            _ -> default_config.verbosity
    theme =
        when
            lines |> List.keep_oks(parse_theme(theme_list))
        is
            [colors, ..] -> colors
            _ -> default_config.theme
    platform =
        when
            lines |> List.keep_oks(parse_platform)
        is
            [pf, ..] -> pf
            _ -> default_config.platform
    Ok({ verbosity, theme, platform })

parse_theme = |theme_list|
    |str|
        theme_names = theme_list |> List.map(|t| t.name)
        themes = theme_names |> List.map(|s| P.string(s) |> P.lhs(newline))
        pattern = P.string("theme:") |> P.rhs(P.maybe(P.whitespace)) |> P.rhs(P.one_of(themes))
        parser = pattern |> P.map(|name| Theme.from_name(theme_list, name))
        parser(str) |> P.finalize |> Result.map_err(|_| InvalidTheme)

parse_verbosity = |str|
    verbosity_levels = ["silent", "quiet", "verbose"] |> List.map(|s| P.string(s))
    pattern = P.string("verbosity:") |> P.rhs(P.maybe(P.whitespace)) |> P.rhs(P.one_of(verbosity_levels)) |> P.lhs(newline)
    parser =
        pattern
        |> P.map(
            |s|
                when s is
                    "silent" -> Ok(Silent)
                    "quiet" -> Ok(Quiet)
                    "verbose" -> Ok(Verbose)
                    _ -> Err(InvalidLogLevel),
        )
    parser(str) |> P.finalize |> Result.map_err(|_| InvalidLogLevel)

parse_platform = |str|
    pattern = P.string("platform:") |> P.rhs(P.maybe(P.whitespace)) |> P.rhs(platform_string) |> P.lhs(newline)
    parser =
        pattern
        |> P.map(
            |s|
                when s |> StrUtils.split_first_if(|c| List.contains([':', '='], c)) is
                    Ok({ before: name, after: version }) -> Ok({ name, version })
                    _ -> Ok({ name: s, version: "latest" }),
        )
    parser(str) |> P.finalize |> Result.map_err(|_| InvalidPlatform)

platform_string = P.one_or_more(platform_chars) |> P.map(|chars| Str.from_utf8_lossy(chars) |> Ok)

platform_chars =
    P.char
    |> P.filter(
        |c|
            (c >= 'a' and c <= 'z')
            or
            (c >= 'A' and c <= 'Z')
            or
            (c >= '0' and c <= '9')
            or
            (List.contains(['-', '_', '/', '=', ':', '-', '+', '.'], c)),
    )

newline = P.char |> P.filter(|c| c == '\n')

create_default_dotfile! : {} => Result Config [HomeVarNotSet, FileWriteError]
create_default_dotfile! = |{}|
    save_config!(default_config)?
    Ok(default_config)

save_config! : Config => Result {} [HomeVarNotSet, FileWriteError]
save_config! = |config|
    home = 
        env_var!("HOME") 
        ? |_| HomeVarNotSet
        |> Str.drop_suffix("/")
    file_path = "${home}/.rocstartconfig"
    contents = config_to_str(config)
    write_utf8!(contents, file_path) |> Result.map_err(|_| FileWriteError)

default_config = { verbosity: Verbose, theme: Theme.default, platform: { name: "basic-cli", version: "latest" } }

save_to_dotfile! : { key : Str, value : Str } => Result {} [HomeVarNotSet, FileWriteError, FileReadError]
save_to_dotfile! = |{ key, value }|
    home = 
        env_var!("HOME") 
        ? |_| HomeVarNotSet
        |> Str.drop_suffix("/")
    file_path = "${home}/.rocstartconfig"
    if file_exists!(file_path) then
        file_contents = read_utf8!(file_path) ? |_| FileReadError
        Str.split_on(file_contents, "\n")
        |> List.map(
            |line|
                if Str.starts_with(line, key) then
                    "${key}: ${value}"
                else
                    line,
        )
        |> |lines|
            if List.contains(lines, "${key}: ${value}") then
                lines
            else
                List.append(lines, "${key}: ${value}\n")
        |> Str.join_with("\n")
        |> write_utf8!(file_path)
        |> Result.map_err(|_| FileWriteError)
    else
        "${key}: ${value}\n"
        |> write_utf8!(file_path)
        |> Result.map_err(|_| FileWriteError)

load_custom_themes! : {} => Result (List Theme) [HomeVarNotSet, NoDotFileFound, InvalidThemeFile, FileReadError]
load_custom_themes! = |{}|
    home_res = env_var!("HOME") |> Result.map_err(|_| HomeVarNotSet)
    home =
        if home_res == Err(HomeVarNotSet) then
            return Ok([])
        else
            home_res |> Result.with_default("") |> Str.drop_suffix("/")

    file_path = "${home}/.rocstartthemes"
    if file_exists!(file_path) then
        file_contents =
            read_utf8!(file_path)
            |> Result.with_default("")
            |> Str.to_utf8
        themes = Decode.from_bytes_partial(file_contents, Json.utf8) |> .result |> Result.with_default([]) |> List.map(json_to_theme)
        Ok(themes)
    else
        Ok([])

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
