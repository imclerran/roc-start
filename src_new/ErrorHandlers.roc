module [
    handle_platform_repo_error,
    handle_upgrade_platform_repo_error,
    handle_package_repo_error,
    handle_get_repositories_error,
    handle_package_release_error,
    handle_platform_release_error,
    handle_upgrade_platform_release_error,
    handle_upgrade_file_read_error,
    handle_upgrade_split_file_error,
]

import RepoManager as RM

handle_platform_repo_error = |name, { log_level, theme, log!, colorize }|
    |err|
        when err is
            RepoNotFound ->
                log_strs = ["Platform: ", name, " : repo not found - valid platform is required\n"]
                message =
                    when log_level is
                        Verbose -> log_strs |> colorize([theme.primary, theme.secondary, theme.error]) |> Verbose
                        Quiet -> log_strs |> colorize([theme.error]) |> Quiet
                        _ -> Verbose("")
                log!(message, log_level)
                Err(Handled)

            RepoNotFoundButMaybe(suggestion) ->
                log_strs = ["Platform: ", name, " : repo not found; did you mean ${suggestion}? - valid platform is required\n"]
                message =
                    when log_level is
                        Verbose -> log_strs |> colorize([theme.primary, theme.secondary, theme.error]) |> Verbose
                        Quiet -> log_strs |> colorize([theme.error]) |> Quiet
                        _ -> Verbose("")
                log!(message, log_level)
                Err(Handled)

            AmbiguousName ->
                log_strs = ["Platform: ", name, " : ambiguous; use <owner>/${name} - valid platform is required\n"]
                message =
                    when log_level is
                        Verbose -> log_strs |> colorize([theme.primary, theme.secondary, theme.error]) |> Verbose
                        Quiet -> log_strs |> colorize([theme.error]) |> Quiet
                        _ -> Verbose("")
                log!(message, log_level)
                Err(Handled)

handle_upgrade_platform_repo_error = |name, { log_level, theme, log!, colorize }|
    |err|
        when err is
            RepoNotFound ->
                log_strs = ["Platform: ", name, " : repo not found - skipping\n"]
                log_strs |> colorize([theme.primary, theme.secondary, theme.error]) |> Verbose |> log!(log_level)
                Err(Handled)

            RepoNotFoundButMaybe(suggestion) ->
                log_strs = ["Platform: ", name, " : repo not found; did you mean ${suggestion}? - skipping\n"]
                log_strs |> colorize([theme.primary, theme.secondary, theme.error]) |> Verbose |> log!(log_level)
                Err(Handled)

            AmbiguousName ->
                log_strs = ["Platform: ", name, " : ambiguous; use <owner>/${name} - skipping\n"]
                log_strs |> colorize([theme.primary, theme.secondary, theme.error]) |> Verbose |> log!(log_level)
                Err(Handled)

handle_package_repo_error = |name, { log_level, theme, log!, colorize }|
    |err|
        when err is
            RepoNotFound ->
                _ =
                    ["| ", name, " : package repo not found - skipping\n"]
                    |> colorize([theme.error, theme.secondary, theme.error])
                    |> Verbose
                    |> log!(log_level)
                Err(Handled)

            RepoNotFoundButMaybe(suggestion) ->
                _ =
                    ["| ", name, " : package repo not found; did you mean ${suggestion}? - skipping\n"]
                    |> colorize([theme.error, theme.secondary, theme.error])
                    |> Verbose
                    |> log!(log_level)
                Err(Handled)

            AmbiguousName ->
                _ =
                    ["| ", name, " : ambiguous; use <owner>/${name} - skipping\n"]
                    |> colorize([theme.error, theme.secondary, theme.error])
                    |> Verbose
                    |> log!(log_level)
                Err(Handled)

# handle_get_repositories_error : { log_level : LogLevel, theme : Theme } -> ([FileReadError, FileWriteError, GhAuthError, GhNotInstalled, HomeVarNotSet, NetworkError, ParsingError, BadRepoReleasesData] => Result * _)
handle_get_repositories_error = |{ log_level, theme, log!, colorize }|
    |e|
        when e is
            HomeVarNotSet ->
                _ = ["HOME environment variable not set"] |> colorize([theme.error]) |> Quiet |> log!(log_level)
                Err(Handled)

            FileWriteError ->
                _ = ["Error writing to file"] |> colorize([theme.error]) |> Quiet |> log!(log_level)
                Err(Handled)

            FileReadError ->
                _ = ["Error reading from file"] |> colorize([theme.error]) |> Quiet |> log!(log_level)
                Err(Handled)

            GhAuthError ->
                _ = ["GitHub CLI tool not authenticated"] |> colorize([theme.error]) |> Quiet |> log!(log_level)
                Err(Handled)

            GhNotInstalled ->
                _ = ["GitHub CLI tool not installed"] |> colorize([theme.error]) |> Quiet |> log!(log_level)
                Err(Handled)

            NetworkError ->
                _ = ["Network error"] |> colorize([theme.error]) |> Quiet |> log!(log_level)
                Err(Handled)

            BadRepoReleasesData ->
                _ = ["Local repo data is corrupted"] |> colorize([theme.error]) |> Quiet |> log!(log_level)
                Err(Handled)

            ParsingError ->
                _ = ["Error parsing data"] |> colorize([theme.error]) |> Quiet |> log!(log_level)
                Err(Handled)

handle_package_release_error = |packages, repo, name, version, { log_level, theme, log!, colorize }|
    |err|
        when err is
            RepoNotFound ->
                _ =
                    ["| ", name, " : package not found - skipping\n"]
                    |> colorize([theme.error, theme.secondary, theme.error])
                    |> Verbose
                    |> log!(log_level)
                Err(Handled)

            RepoNotFoundButMaybe(suggestion) ->
                _ =
                    ["| ", name, " : package not found; did you mean ${suggestion}? - skipping\n"]
                    |> colorize([theme.error, theme.secondary, theme.error])
                    |> Verbose
                    |> log!(log_level)
                Err(Handled)

            VersionNotFound ->
                when RM.get_repo_release(packages, repo, "latest", Package) is
                    Ok(suggestion) ->
                        _ =
                            ["| ", name, " : version not found; latest is ${suggestion.tag} - skipping\n"]
                            |> colorize([theme.error, theme.secondary, theme.error])
                            |> Verbose
                            |> log!(log_level)
                        Err(Handled)

                    Err(_) ->
                        _ =
                            ["| ", name, " : version ${version} not found - skipping\n"]
                            |> colorize([theme.error, theme.secondary, theme.error])
                            |> Verbose
                            |> log!(log_level)
                        Err(Handled)

handle_platform_release_error = |platforms, repo, name, version, { log_level, theme, log!, colorize }|
    |err|
        when err is
            RepoNotFound ->
                log_strs = ["Platform: ", name, " : repo not found - valid platform is required\n"]
                message =
                    when log_level is
                        Verbose -> log_strs |> colorize([theme.primary, theme.secondary, theme.error]) |> Verbose
                        Quiet -> log_strs |> colorize([theme.error]) |> Quiet
                        _ -> Verbose("")
                log!(message, log_level)
                Err(Handled)

            RepoNotFoundButMaybe(suggestion) ->
                log_strs = ["Platform: ", name, " : repo not found; did you mean ${suggestion}? - valid platform is required\n"]
                message =
                    when log_level is
                        Verbose -> log_strs |> colorize([theme.primary, theme.secondary, theme.error]) |> Verbose
                        Quiet -> log_strs |> colorize([theme.error]) |> Quiet
                        _ -> Verbose("")
                log!(message, log_level)
                Err(Handled)

            VersionNotFound ->
                when RM.get_repo_release(platforms, repo, "latest", Platform) is
                    Ok(suggestion) ->
                        log_strs = ["Platform: ", name, " : version not found; latest is ${suggestion.tag} - valid platform is required\n"]
                        message =
                            when log_level is
                                Verbose -> log_strs |> colorize([theme.primary, theme.secondary, theme.error]) |> Verbose
                                Quiet -> log_strs |> colorize([theme.error]) |> Quiet
                                _ -> Verbose("")
                        log!(message, log_level)
                        Err(Handled)

                    Err(_) ->
                        log_strs = ["Platform: ", name, " : version ${version} not found - valid platform is required\n"]
                        message =
                            when log_level is
                                Verbose -> log_strs |> colorize([theme.primary, theme.secondary, theme.error]) |> Verbose
                                Quiet -> log_strs |> colorize([theme.error]) |> Quiet
                                _ -> Verbose("")
                        log!(message, log_level)
                        Err(Handled)

handle_upgrade_platform_release_error = |platforms, repo, name, version, { log_level, theme, log!, colorize }|
    |err|
        when err is
            RepoNotFound ->
                log_strs = ["Platform: ", name, " : repo not found - skipping\n"]
                log_strs |> colorize([theme.primary, theme.secondary, theme.error]) |> Verbose |> log!(log_level)
                Err(Handled)

            RepoNotFoundButMaybe(suggestion) ->
                log_strs = ["Platform: ", name, " : repo not found; did you mean ${suggestion}? - skipping\n"]
                log_strs |> colorize([theme.primary, theme.secondary, theme.error]) |> Verbose |> log!(log_level)
                Err(Handled)

            VersionNotFound ->
                when RM.get_repo_release(platforms, repo, "latest", Platform) is
                    Ok(suggestion) ->
                        log_strs = ["Platform: ", name, " : version not found; latest is ${suggestion.tag} - skipping\n"]
                        log_strs |> colorize([theme.primary, theme.secondary, theme.error]) |> Verbose |> log!(log_level)
                        Err(Handled)

                    Err(_) ->
                        log_strs = ["Platform: ", name, " : version ${version} not found - skipping\n"]
                        log_strs |> colorize([theme.primary, theme.secondary, theme.error]) |> Verbose |> log!(log_level)
                        Err(Handled)

handle_upgrade_file_read_error = |filename, { log_level, theme, log!, colorize }|
    |err|
        when err is
            FileReadErr _path NotFound ->
                ["Target file not found: ", filename, "\n"] |> colorize([theme.error]) |> Quiet |> log!(log_level)
                Err(Handled)

            FileReadErr _path PermissionDenied ->
                ["Permission denied reading file: ", filename, "\n"] |> colorize([theme.error]) |> Quiet |> log!(log_level)
                Err(Handled)

            FileReadErr _path _ioerr ->
                ["Error reading file: ", filename, "\n"] |> colorize([theme.error]) |> Quiet |> log!(log_level)
                Err(Handled)

            FileReadUtf8Err _path BadUtf8(_) ->
                ["Error reading file: ", filename, " - invalid utf8\n"] |> colorize([theme.error]) |> Quiet |> log!(log_level)
                Err(Handled)

handle_upgrade_split_file_error = |filename, { log_level, theme, log!, colorize }|
    |_err|
        ["Invalid roc file: ", filename, "\n"] |> colorize([theme.error]) |> Quiet |> log!(log_level)
        Err(Handled)

