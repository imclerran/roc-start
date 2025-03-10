module [str_to_slug, str_to_lower, str_to_upper]

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

