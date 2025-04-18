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
    handle_cache_plugins_error,
    handle_update_local_repos_error,
]

import repos.Manager as RM

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
                log_strs |> colorize([theme.primary, theme.secondary, theme.warn]) |> Verbose |> log!(log_level)
                Err(Handled)

            RepoNotFoundButMaybe(suggestion) ->
                log_strs = ["Platform: ", name, " : repo not found; did you mean ${suggestion}? - skipping\n"]
                log_strs |> colorize([theme.primary, theme.secondary, theme.warn]) |> Verbose |> log!(log_level)
                Err(Handled)

            AmbiguousName ->
                log_strs = ["Platform: ", name, " : ambiguous; use <owner>/${name} - skipping\n"]
                log_strs |> colorize([theme.primary, theme.secondary, theme.warn]) |> Verbose |> log!(log_level)
                Err(Handled)

handle_package_repo_error = |name, { log_level, theme, log!, colorize }|
    |err|
        when err is
            RepoNotFound ->
                _ =
                    ["| ", name, " : package repo not found - skipping\n"]
                    |> colorize([theme.warn, theme.secondary, theme.warn])
                    |> Verbose
                    |> log!(log_level)
                Err(Handled)

            RepoNotFoundButMaybe(suggestion) ->
                _ =
                    ["| ", name, " : package repo not found; did you mean ${suggestion}? - skipping\n"]
                    |> colorize([theme.warn, theme.secondary, theme.warn])
                    |> Verbose
                    |> log!(log_level)
                Err(Handled)

            AmbiguousName ->
                _ =
                    ["| ", name, " : ambiguous; use <owner>/${name} - skipping\n"]
                    |> colorize([theme.warn, theme.secondary, theme.warn])
                    |> Verbose
                    |> log!(log_level)
                Err(Handled)

handle_package_release_error = |packages, repo, name, version, { log_level, theme, log!, colorize }|
    |err|
        when err is
            RepoNotFound ->
                _ =
                    ["| ", name, " : package not found - skipping\n"]
                    |> colorize([theme.error, theme.secondary, theme.warn])
                    |> Verbose
                    |> log!(log_level)
                Err(Handled)

            RepoNotFoundButMaybe(suggestion) ->
                _ =
                    ["| ", name, " : package not found; did you mean ${suggestion}? - skipping\n"]
                    |> colorize([theme.warn, theme.secondary, theme.warn])
                    |> Verbose
                    |> log!(log_level)
                Err(Handled)

            VersionNotFound ->
                when RM.get_repo_release(packages, repo, "latest", Package) is
                    Ok(suggestion) ->
                        _ =
                            ["| ", name, " : version not found; latest is ${suggestion.tag} - skipping\n"]
                            |> colorize([theme.warn, theme.secondary, theme.warn])
                            |> Verbose
                            |> log!(log_level)
                        Err(Handled)

                    Err(_) ->
                        _ =
                            ["| ", name, " : version ${version} not found - skipping\n"]
                            |> colorize([theme.warn, theme.secondary, theme.warn])
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
                log_strs |> colorize([theme.primary, theme.secondary, theme.warn]) |> Verbose |> log!(log_level)
                Err(Handled)

            RepoNotFoundButMaybe(suggestion) ->
                log_strs = ["Platform: ", name, " : repo not found; did you mean ${suggestion}? - skipping\n"]
                log_strs |> colorize([theme.primary, theme.secondary, theme.warn]) |> Verbose |> log!(log_level)
                Err(Handled)

            VersionNotFound ->
                when RM.get_repo_release(platforms, repo, "latest", Platform) is
                    Ok(suggestion) ->
                        log_strs = ["Platform: ", name, " : version not found; latest is ${suggestion.tag} - skipping\n"]
                        log_strs |> colorize([theme.primary, theme.secondary, theme.warn]) |> Verbose |> log!(log_level)
                        Err(Handled)

                    Err(_) ->
                        log_strs = ["Platform: ", name, " : version ${version} not found - skipping\n"]
                        log_strs |> colorize([theme.primary, theme.secondary, theme.warn]) |> Verbose |> log!(log_level)
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

handle_upgrade_split_file_error = |filename, { log_level, theme, colorize }|
    |_err|
        if log_level == Silent then
            Err(Exit(1, ""))
        else
            err_message = "Invalid roc file: ${filename}"
            Err(Exit(1, [err_message] |> colorize([theme.error])))

handle_get_repositories_error = |{ log_level, theme, colorize }|
    |err|
        if log_level == Silent then
            Err(Exit(1, ""))
        else
            err_message =
                when err is
                    Exit(_, s) -> s
                    BadRepoReleasesData -> "Error getting repositories: bad release data - running an update may fix this."
                    FileReadError -> "Error getting repositories: file read error - running an update may fix this."
                    FileWriteError -> "Error getting repositories: file write error while saving repo data."
                    GhAuthError -> "Error getting repositories: gh cli tool not authenticated - run `gh auth login` to fix."
                    GhNotInstalled -> "Error getting repositories: gh cli tool not installed - install it from https://cli.github.com."
                    HomeVarNotSet -> "Error getting repositories: HOME environment variable not set."
                    NetworkError -> "Error getting repositories: network error - check your connection."
                    ParsingError -> "Error getting repositories: error parsing remote data - please file an issue at https://github.com/imclerran/roc-start."
            Err(Exit(1, [err_message] |> colorize([theme.error])))

handle_cache_plugins_error = |{ log_level, theme, colorize }|
    |err|
        if log_level == Silent then
            Err(Exit(1, ""))
        else
            err_message =
                when err is
                    FileWriteError -> "Error caching plugins: file write error."
                    NetworkError -> "Error caching plugins: network error - check your connection."
            Err(Exit(1, [err_message] |> colorize([theme.error])))

handle_update_local_repos_error = |{ log_level, theme, colorize }|
    |err|
        if log_level == Silent then
            Err(Exit(1, ""))
        else
            err_message =
                when err is
                    FileWriteError -> "Error updating local repositories: file write error."
                    GhAuthError -> "Error updating local repositories: gh cli tool not authenticated - run `gh auth login` to fix."
                    GhNotInstalled -> "Error updating local repositories: gh cli tool not installed - install it from https://cli.github.com."
                    GhError(e) -> "Error updating local repositories: when calling `gh` cmd: ${Inspect.to_str(e)}"
                    ParsingError -> "Error updating local repositories: error parsing remote data - please file an issue at https://github.com/imclerran/roc-start"

            Err(Exit(1, [err_message] |> colorize([theme.error])))
