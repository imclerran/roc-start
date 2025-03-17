module [
    str_to_slug, 
    str_to_lower, 
    str_to_upper,
    repo_to_menu_item,
    menu_item_to_repo,
]

import rtils.StrUtils

str_to_slug : Str -> Str
str_to_slug = |str|
    str
    |> Str.to_utf8
    |> List.drop_if(
        |c|
            if
                (c == '-')
                or (c == '_')
                or (c == ' ')
                or (c >= 'A' and c <= 'Z')
                or (c >= 'a' and c <= 'z')
                or (c >= '0' and c <= '9')
            then
                Bool.false
            else
                Bool.true,
    )
    |> List.map(|c| if c == ' ' then '_' else c)
    |> Str.from_utf8
    |> Result.with_default("")

expect str_to_slug("AZ") == "AZ"
expect str_to_slug("az") == "az"
expect str_to_slug("@") == ""
expect str_to_slug("[") == ""
expect str_to_slug("a z") == "a_z"
expect str_to_slug("a-z") == "a-z"

str_to_lower : Str -> Str
str_to_lower = |str|
    str
    |> Str.to_utf8
    |> List.map(|c| if c >= 'A' and c <= 'Z' then c + 32 else c)
    |> Str.from_utf8
    |> Result.with_default("")

expect str_to_lower("AZ") == "az"
expect str_to_lower("az") == "az"
expect str_to_lower("@") == "@"
expect str_to_lower("[") == "["

str_to_upper : Str -> Str
str_to_upper = |str|
    str
    |> Str.to_utf8
    |> List.map(|c| if c >= 'a' and c <= 'z' then c - 32 else c)
    |> Str.from_utf8
    |> Result.with_default("")

expect str_to_upper("AZ") == "AZ"
expect str_to_upper("az") == "AZ"
expect str_to_upper("@") == "@"
expect str_to_upper("[") == "["

repo_to_menu_item : Str -> Str
repo_to_menu_item = |repo|
    when Str.split_first(repo, "/") is
        Ok({ before: owner, after: name_maybe_version }) ->
            when Str.split_first(name_maybe_version, ":") is
                Ok({ before: name, after: version }) -> "${name} (${owner}) : ${version}"
                _ -> "${name_maybe_version} (${owner})"

        _ ->
            when Str.split_first(repo, ":") is
                Ok({ before: name, after: version }) -> "${name} : ${version}"
                _ -> repo

expect repo_to_menu_item("owner/name:version") == "name (owner) : version"
expect repo_to_menu_item("owner/name") == "name (owner)"
expect repo_to_menu_item("name:version") == "name : version"
expect repo_to_menu_item("name") == "name"

menu_item_to_repo : Str -> Str
menu_item_to_repo = |item|
    when StrUtils.split_if(item, |c| List.contains(['(', ')'], c)) is
        [name_dirty, owner, version_dirty] ->
            name = Str.trim(name_dirty)
            version = Str.drop_prefix(version_dirty, " : ") |> Str.trim
            "${owner}/${name}:${version}"

        [name_dirty, owner] ->
            name = Str.trim(name_dirty)
            "${owner}/${name}"

        _ ->
            when Str.split_first(item, " : ") is
                Ok({ before: name, after: version }) -> "${name}:${version}"
                _ -> item

expect menu_item_to_repo("name (owner) : version") == "owner/name:version"
expect menu_item_to_repo("name (owner)") == "owner/name"
expect menu_item_to_repo("name : version") == "name:version"
expect menu_item_to_repo("name") == "name"

expect menu_item_to_repo(repo_to_menu_item("owner/name:version")) == "owner/name:version"
expect menu_item_to_repo(repo_to_menu_item("owner/name")) == "owner/name"
expect menu_item_to_repo(repo_to_menu_item("name:version")) == "name:version"
expect menu_item_to_repo(repo_to_menu_item("name")) == "name"

expect repo_to_menu_item(menu_item_to_repo("name (owner) : version")) == "name (owner) : version"
expect repo_to_menu_item(menu_item_to_repo("name (owner)")) == "name (owner)"
expect repo_to_menu_item(menu_item_to_repo("name : version")) == "name : version"
expect repo_to_menu_item(menu_item_to_repo("name")) == "name"
