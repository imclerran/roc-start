module [parse_platform_line, parse_package_line, parse_repo_owner_name]

import parse.Parse as P

parse_platform_line = |str|
    pattern = P.maybe(P.whitespace) |> P.rhs(alias) |> P.lhs(colon) |> P.lhs(P.whitespace) |> P.lhs(P.string("platform")) |> P.lhs(P.whitespace) |> P.lhs(double_quote) |> P.both(path) |> P.lhs(double_quote) |> P.lhs(P.maybe(comma)) |> P.lhs(P.maybe(P.whitespace))
    parser = pattern |> P.map(|(a, p)| Ok({ alias: a, path: p }))
    parser(str) |> P.finalize |> Result.map_err(|_| InvalidPlatformLine)

expect
    res = parse_platform_line("  cli: platform \"../basic-cli/platform/main.roc\",")
    res == Ok({ alias: "cli", path: "../basic-cli/platform/main.roc" })

expect
    res = parse_platform_line("    cli: platform \"https://github.com/roc-lang/basic-cli/releases/download/0.19.0/Hj-J_zxz7V9YurCSTFcFdu6cQJie4guzsPMUi5kBYUk.tar.br\",")
    res == Ok({ alias: "cli", path: "https://github.com/roc-lang/basic-cli/releases/download/0.19.0/Hj-J_zxz7V9YurCSTFcFdu6cQJie4guzsPMUi5kBYUk.tar.br" })

parse_package_line = |str|
    pattern = P.maybe(P.whitespace) |> P.rhs(alias) |> P.lhs(colon) |> P.lhs(P.whitespace) |> P.lhs(double_quote) |> P.both(path) |> P.lhs(double_quote) |> P.lhs(P.maybe(comma)) |> P.lhs(P.maybe(P.whitespace))
    parser = pattern |> P.map(|(a, p)| Ok({ alias: a, path: p }))
    parser(str) |> P.finalize |> Result.map_err(|_| InvalidPackageLine)

expect
    res = parse_package_line("    parse: \"../roc-tinyparse/package/main.roc\",")
    res == Ok({ alias: "parse", path: "../roc-tinyparse/package/main.roc" })

expect
    res = parse_package_line("    parse: \"https://github.com/imclerran/roc-tinyparse/releases/download/v0.3.3/kKiVNqjpbgYFhE-aFB7FfxNmkXQiIo2f_mGUwUlZ3O0.tar.br\",")
    res == Ok({ alias: "parse", path: "https://github.com/imclerran/roc-tinyparse/releases/download/v0.3.3/kKiVNqjpbgYFhE-aFB7FfxNmkXQiIo2f_mGUwUlZ3O0.tar.br" })

parse_repo_owner_name = |str|
    pattern = P.string("https://github.com/") |> P.rhs(slug) |> P.lhs(forward_slash) |> P.both(slug) |> P.lhs(forward_slash)
    parser = pattern |> P.map(|(owner, name)| Ok({ owner, name }))
    parser(str) |> P.finalize_lazy |> Result.map_err(|_| InvalidRepoUrl)

expect
    res = parse_repo_owner_name("https://github.com/roc-lang/basic-cli/releases/download/0.19.0/Hj-J_zxz7V9YurCSTFcFdu6cQJie4guzsPMUi5kBYUk.tar.br")
    res == Ok({ owner: "roc-lang", name: "basic-cli" })

colon = P.char |> P.filter(|c| c == ':')
comma = P.char |> P.filter(|c| c == ',')
double_quote = P.char |> P.filter(|c| c == '"')
forward_slash = P.char |> P.filter(|c| c == '/')

alias_char = P.char |> P.filter(|c| (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '_')
path_char = P.char |> P.filter(|c| (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or (List.contains(['/', '.', '-', '_', ':'], c)))
slug_char = P.char |> P.filter(|c| (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '-' or c == '_')

alias = P.one_or_more(alias_char) |> P.map(Str.from_utf8)
path = P.one_or_more(path_char) |> P.map(Str.from_utf8)
slug = P.one_or_more(slug_char) |> P.map(Str.from_utf8)

