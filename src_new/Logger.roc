module { write! } -> [LogLevel, LogStr, log!, colorize]

import ansi.Color
import ansi.ANSI

LogLevel : [Silent, Quiet, Verbose]
LogStr : [Quiet Str, Verbose Str]
Color : Color.Color

log! : LogStr, LogLevel => {}
log! = |log_str, level|
    _ =
        when (log_str, level) is
            (Verbose(str), Verbose) -> write!(str)
            (Quiet(str), Verbose) -> write!(str)
            (Quiet(str), Quiet) -> write!(str)
            _ -> Ok({})
    {}

colorize : List Str, List Color -> Str
colorize = |parts, colors|
    if List.len(parts) <= List.len(colors) then
        List.map2(parts, colors, |part, color| ANSI.color(part, { fg: color })) |> Str.join_with("")
    else
        rest =
            List.split_at(parts, List.len(colors))
            |> .others
            |> Str.join_with("")
            |> ANSI.color({ fg: List.last(colors) |> Result.with_default(Default) })
        List.map2(parts, colors, |part, color| ANSI.color(part, { fg: color }))
        |> Str.join_with("")
        |> Str.concat(rest)
