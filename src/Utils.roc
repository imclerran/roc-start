module [strToSlug, strToLower, strToUpper]

strToSlug : Str -> Str
strToSlug = \str ->
    str
    |> Str.toUtf8
    |> List.dropIf \c ->
        if
            (c == '-')
            || (c == '_')
            || (c == ' ')
            || (c >= 'A' && c <= 'Z')
            || (c >= 'a' && c <= 'z')
            || (c >= '0' && c <= '9')
        then
            Bool.false
        else
            Bool.true
    |> List.map \c -> if c == ' ' then '_' else c
    |> Str.fromUtf8
    |> Result.withDefault ""

expect strToSlug "AZ" == "AZ"
expect strToSlug "az" == "az"
expect strToSlug "@" == ""
expect strToSlug "[" == ""
expect strToSlug "a z" == "a_z"
expect strToSlug "a-z" == "a-z"

strToLower : Str -> Str
strToLower = \str ->
    str
    |> Str.toUtf8
    |> List.map \c -> if c >= 'A' && c <= 'Z' then c + 32 else c
    |> Str.fromUtf8
    |> Result.withDefault ""

expect strToLower "AZ" == "az"
expect strToLower "az" == "az"
expect strToLower "@" == "@"
expect strToLower "[" == "["

strToUpper : Str -> Str
strToUpper = \str ->
    str
    |> Str.toUtf8
    |> List.map \c -> if c >= 'a' && c <= 'z' then c - 32 else c
    |> Str.fromUtf8
    |> Result.withDefault ""

expect strToUpper "AZ" == "AZ"
expect strToUpper "az" == "AZ"
expect strToUpper "@" == "@"
expect strToUpper "[" == "["

