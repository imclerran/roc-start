module { write! } -> [LogLevel, LogStr, log!]

LogLevel : [Silent, Quiet, Verbose]
LogStr : [Quiet Str, Verbose Str]

log! : LogStr, LogLevel => {}
log! = |log_str, level|
    _ =
        when (log_str, level) is
            (Verbose(str), Verbose) -> write!(str)
            (Quiet(str), Verbose) -> write!(str)
            (Quiet(str), Quiet) -> write!(str)
            _ -> Ok({})
    {}
