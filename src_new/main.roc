app [main!] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.19.0/Hj-J_zxz7V9YurCSTFcFdu6cQJie4guzsPMUi5kBYUk.tar.br",
    semver: "https://github.com/imclerran/roc-semver/releases/download/v0.2.0%2Bimclerran/ePmzscvLvhwfllSFZGgTp77uiTFIwZQPgK_TiM6k_1s.tar.br",
    weaver: "https://github.com/smores56/weaver/releases/download/0.6.0/4GmRnyE7EFjzv6dDpebJoWWwXV285OMt4ntHIc6qvmY.tar.br",
    parse: "https://github.com/imclerran/roc-tinyparse/releases/download/v0.3.3/kKiVNqjpbgYFhE-aFB7FfxNmkXQiIo2f_mGUwUlZ3O0.tar.br",
    ansi: "https://github.com/lukewilliamboswell/roc-ansi/releases/download/0.8.0/RQlGWlkQEfxtkSYKl0nHNQaOFT0-Jh7NNFEX2IPXlec.tar.br",
    rtils: "https://github.com/imclerran/rtils/releases/download/v0.1.4/jd2cTVkJeFFJIYwDSSzeFN7byd6QeLuozceWcLfFff8.tar.br",
    ansi: "https://github.com/lukewilliamboswell/roc-ansi/releases/download/0.8.0/RQlGWlkQEfxtkSYKl0nHNQaOFT0-Jh7NNFEX2IPXlec.tar.br",
    json: "https://github.com/lukewilliamboswell/roc-json/releases/download/0.12.0/1trwx8sltQ-e9Y2rOB4LWUWLS_sFVyETK8Twl0i9qpw.tar.gz",
}

import cli.Arg exposing [to_os_raw]
import cli.Stdout
import cli.Cmd
import cli.File
import cli.Dir
import cli.Http
import cli.Env
import cli.Path
import ansi.ANSI
import Theme exposing [Theme]
import ArgParser
import RepoManager {
        write_bytes!: File.write_bytes!,
        cmd_output!: Cmd.output!,
        cmd_new: Cmd.new,
        cmd_args: Cmd.args,
    } as RM exposing [RepositoryDict, RepositoryRelease]
import ScriptManager {
        http_send!: Http.send!,
        file_write_utf8!: File.write_utf8!,
        create_all_dirs!: Dir.create_all!,
        list_dir!: Dir.list!,
        path_to_str: Path.display,
    } exposing [cache_scripts!]
import Dotfile {
    env_var!: Env.var!,
    is_file!: File.is_file!,
    read_utf8!: File.read_utf8!,
    write_utf8!: File.write_utf8!,
} as DF
import Logger {
        write!: Stdout.write!,
    } exposing [LogLevel, log!]

main! = |args|
    config = get_config!({})
    when ArgParser.parse_or_display_message(args, to_os_raw) is
        Ok({ verbosity, color, subcommand }) ->
            theme =
                when color is
                    Ok(th) -> th
                    Err(NoTheme) -> config.theme
            log_level =
                when verbosity is
                    Ok(v) -> v
                    Err(NoLogLevel) -> config.verbosity
            logging = { log_level, theme }
            when subcommand is
                Ok(Update(update_args)) ->
                    do_update_command!(update_args, logging)

                Ok(App(app_args)) ->
                    args_with_defaults = app_args_with_defaults(app_args, config)
                    when do_app_command!(args_with_defaults, logging) is
                        Err(PlatformRepoLookupErrorHandled) -> Ok({})
                        Err(PlatformReleaseErrorHandled) -> Ok({})
                        Err(GetRepositoriesFailed) -> Ok({})
                        Err(FileExists) -> Ok({})
                        any_other -> any_other

                Ok(Package(_pkg_args)) ->
                    "Pkg: not implemented\n"
                    |> ANSI.color({ fg: theme.error })
                    |> Quiet
                    |> log!(log_level)
                    |> Ok

                Ok(Upgrade(_upgrade_args)) ->
                    "Upgrade: not implemented\n"
                    |> ANSI.color({ fg: theme.error })
                    |> Quiet
                    |> log!(log_level)
                    |> Ok

                Ok(Tui(_tui_args)) ->
                    "Tui: not implemented\n"
                    |> ANSI.color({ fg: theme.error })
                    |> Quiet
                    |> log!(log_level)
                    |> Ok

                Ok(Config(config_args)) ->
                    do_config_command!(config_args, logging)

                Err(NoSubcommand) ->
                    "TUI: not yet implemented\n"
                    |> ANSI.color({ fg: theme.error })
                    |> Quiet
                    |> log!(log_level)
                    |> Ok

        Err(e) ->
            "${e}\n" |> Quiet |> log!(Verbose) |> Ok

get_config! : {} => DF.Config
get_config! = |{}|
    when DF.load_dotfile!({}) is
        Ok(config) -> config
        Err(NoDotFileFound) ->
            new = DF.create_default_dotfile!({})
            when new is
                Ok(config) -> config
                Err(_) -> DF.default_config

        Err(_) -> DF.default_config

app_args_with_defaults = |app_args, config|
    when app_args.platform.name is
        "" -> { app_args & platform: config.platform }
        _ -> app_args

colorize : List Str, List _ -> Str
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

do_config_command! = |config_args, logging|
    theme = logging.theme
    log_level = logging.log_level
    when config_args is
        ConfigVerbosity(verbosity) ->
            when DF.save_to_dotfile!({ key: "verbosity", value: verbosity }) is
                Ok({}) -> ["Saved. ", "✔️\n"] |> colorize([theme.primary, theme.okay]) |> Quiet |> log!(log_level) |> Ok
                Err(e) -> ["Error saving config:", Inspect.to_str(e), "\n"] |> colorize([theme.error]) |> Quiet |> log!(log_level) |> Ok

        ConfigColors(colors) ->
            when DF.save_to_dotfile!({ key: "theme", value: colors }) is
                Ok({}) -> ["Saved. ", "✔️\n"] |> colorize([theme.primary, theme.okay]) |> Quiet |> log!(log_level) |> Ok
                Err(e) -> ["Error saving config:", Inspect.to_str(e), "\n"] |> colorize([theme.error]) |> Quiet |> log!(log_level) |> Ok

        ConfigPlatform(platform) ->
            when DF.save_to_dotfile!({ key: "platform", value: platform }) is
                Ok({}) -> ["Saved. ", "✔️\n"] |> colorize([theme.primary, theme.okay]) |> Quiet |> log!(log_level) |> Ok
                Err(e) -> ["Error saving config:", Inspect.to_str(e), "\n"] |> colorize([theme.error]) |> Quiet |> log!(log_level) |> Ok

do_update_command! : { do_platforms : Bool, do_packages : Bool, do_scripts : Bool }, { log_level : LogLevel, theme : Theme } => Result {} _
do_update_command! = |{ do_platforms, do_packages, do_scripts }, logging|
    pf_res =
        if do_platforms or !(do_platforms or do_packages or do_scripts) then
            do_platform_update!(logging)
            |> Result.map_err(|_| PlatformsUpdateFailed)
        else
            Ok(Dict.empty({}))

    pk_res =
        if do_packages or !(do_platforms or do_packages or do_scripts) then
            do_package_update!(logging)
            |> Result.map_err(|_| PackagesUpdateFailed)
        else
            Ok(Dict.empty({}))

    sc_res =
        if do_scripts or !(do_platforms or do_packages or do_scripts) then
            maybe_pfs =
                when pf_res is
                    Ok(dict) if !Dict.is_empty(dict) -> Some(dict)
                    _ -> None
            do_scripts_update!(maybe_pfs, logging)
            |> Result.map_err(|_| ScriptsUpdateFailed)
        else
            Ok({})

    when (pf_res, pk_res, sc_res) is
        (Ok(_), Ok(_), Ok(_)) -> Ok({})
        (Err(e), _, _) -> Err(e)
        (_, Err(e), _) -> Err(e)
        (_, _, Err(e)) -> Err(e)

do_app_command! : { file_name : Str, force : Bool, packages : List { name : Str, version : Str }*, platform : { name : Str, version : Str }* }*, { log_level : LogLevel, theme : Theme } => Result {} _
do_app_command! = |arg_data, logging|
    log_level = logging.log_level
    theme = logging.theme
    when File.is_file!(arg_data.file_name) is
        Ok(bool) if bool and !arg_data.force ->
            "File <${arg_data.file_name}> already exists. Choose a different name or use --force\n"
            |> ANSI.color({ fg: theme.error })
            |> Quiet
            |> log!(log_level)
            Err(FileExists)

        _ ->
            { packages, platforms } =
                get_repositories!(logging)
                |> Result.on_err!(handle_get_repositories_error(logging))
                |> Result.map_err(|_| GetRepositoriesFailed)?
            _ =
                repo_dir = get_repo_dir!({}) ? |_| HomeVarNotSet
                scripts_exists =
                    when File.is_dir!("${repo_dir}/scripts") is
                        Ok(bool) -> bool
                        Err(_) -> Bool.false
                if !(scripts_exists) then
                    do_scripts_update!(Some(platforms), logging)
                else
                    Ok({})
            ["Creating ", "${arg_data.file_name}", "...\n"]
            |> colorize([theme.primary, theme.secondary, theme.primary])
            |> Verbose
            |> log!(log_level)
            repo_names = List.join([Dict.keys(packages), Dict.keys(platforms)])
            repo_name_map = RM.build_repo_name_map(repo_names)
            platform_repo =
                RM.get_full_repo_name(repo_name_map, arg_data.platform.name, Platform)
                |> Result.on_err!(handle_platform_repo_error(arg_data.platform.name, logging))?
            platform_release =
                RM.get_repo_release(platforms, platform_repo, arg_data.platform.version, Platform)
                |> Result.on_err!(handle_platform_release_error(platforms, platform_repo, arg_data.platform.name, arg_data.platform.version, logging))?
            ["Platform: ", platform_release.repo, " : ${platform_release.tag}\n"]
            |> colorize([theme.primary, theme.secondary, theme.primary])
            |> Verbose
            |> log!(log_level)
            if !List.is_empty(arg_data.packages) then
                "Packages:\n"
                |> ANSI.color({ fg: theme.primary })
                |> Verbose
                |> log!(log_level)
            else
                {}
            package_releases = resolve_package_releases!(packages, repo_name_map, arg_data, logging)
            cmd_args = build_script_args(arg_data.file_name, platform_release, package_releases)
            num_packages = List.len(package_releases)
            num_skipped = List.len(arg_data.packages) - num_packages
            cache_dir = get_repo_dir!({})? |> Str.concat("/scripts/")
            scripts = ScriptManager.get_available_scripts!(cache_dir, platform_repo)
            script_path_res =
                ScriptManager.choose_script(platform_release.tag, scripts)
                |> Result.map_ok(|s| "${cache_dir}/${platform_repo}/${s}")
            when script_path_res is
                Ok(script_path) ->
                    Cmd.exec!("chmod", ["+x", script_path])?
                    _ =
                        Cmd.new(script_path)
                        |> Cmd.args(cmd_args)
                        |> Cmd.output!
                    print_app_finish_message!(arg_data.file_name, num_packages, num_skipped, logging)
                    Ok({})

                Err(_) ->
                    build_default_app!(arg_data.file_name, platform_release, package_releases)?
                    print_app_finish_message!(arg_data.file_name, num_packages, num_skipped, logging)
                    Ok({})

build_script_args : Str, RepositoryRelease, List RepositoryRelease -> List Str
build_script_args = |filename, platform, packages|
    List.join(
        [
            [filename, platform.alias, platform.url],
            alias_url_pairs(packages),
        ],
    )

alias_url_pairs = |releases|
    List.map(releases, |release| [release.alias, release.url]) |> List.join

print_app_finish_message! = |file_name, num_packages, num_skipped, { log_level, theme }|
    if num_skipped == 0 then
        ["Created ", file_name, " with ", Num.to_str(num_packages), " packages ", "✔\n"]
        |> colorize([theme.primary, theme.secondary, theme.primary, theme.secondary, theme.primary, theme.okay])
        |> Quiet
        |> log!(log_level)
    else
        ["Created ", file_name, " with ", Num.to_str(num_packages), " packages and skipped ", Num.to_str(num_skipped), " packages ", "✔\n"]
        |> colorize([theme.primary, theme.secondary, theme.primary, theme.secondary, theme.primary, theme.error, theme.primary, theme.okay])
        |> Quiet
        |> log!(log_level)

build_default_app! = |file_name, platform, packages|
    "app [main!] {\n"
    |> Str.concat("    ${platform.alias}: platform \"${platform.url}\",\n")
    |> Str.concat(
        List.map(packages, |pkg| "    ${pkg.alias}: \"${pkg.url}\",\n")
        |> Str.join_with(""),
    )
    |> Str.concat("}\n")
    |> File.write_utf8!(file_name)
    |> Result.map_err(|_| FileWriteError)?
    Ok({})

handle_get_repositories_error : { log_level : LogLevel, theme : Theme } -> ([FileReadError, FileWriteError, GhAuthError, GhNotInstalled, HomeVarNotSet, NetworkError, ParsingError, BadRepoReleasesData] => Result * _)
handle_get_repositories_error = |{ log_level, theme }|
    |e|
        when e is
            HomeVarNotSet ->
                _ = "HOME environment variable not set" |> ANSI.color({ fg: theme.error }) |> Quiet |> log!(log_level)
                Err(e)

            FileWriteError ->
                _ = "Error writing to file" |> ANSI.color({ fg: theme.error }) |> Quiet |> log!(log_level)
                Err(e)

            FileReadError ->
                _ = "Error reading from file" |> ANSI.color({ fg: theme.error }) |> Quiet |> log!(log_level)
                Err(e)

            GhAuthError ->
                _ = "GitHub CLI tool not authenticated" |> ANSI.color({ fg: theme.error }) |> Quiet |> log!(log_level)
                Err(e)

            GhNotInstalled ->
                _ = "GitHub CLI tool not installed" |> ANSI.color({ fg: theme.error }) |> Quiet |> log!(log_level)
                Err(e)

            NetworkError ->
                _ = "Network error" |> ANSI.color({ fg: theme.error }) |> Quiet |> log!(log_level)
                Err(e)

            BadRepoReleasesData ->
                _ = "Local repo data is corrupted" |> ANSI.color({ fg: theme.error }) |> Quiet |> log!(log_level)
                Err(e)

            ParsingError ->
                _ = "Error parsing data" |> ANSI.color({ fg: theme.error }) |> Quiet |> log!(log_level)
                Err(e)

resolve_package_releases! = |packages, repo_name_map, processed_args, { log_level, theme }|
    List.walk_try!(
        processed_args.packages,
        [],
        |releases, package|
            package_repo_res =
                RM.get_full_repo_name(repo_name_map, package.name, Package)
                |> Result.on_err!(handle_package_repo_error(package.name, { log_level, theme }))
            when package_repo_res is
                Ok(package_repo) ->
                    pkg_res =
                        RM.get_repo_release(packages, package_repo, package.version, Package)
                        |> Result.on_err!(handle_package_release_error(packages, package_repo, package.name, package.version, { log_level, theme }))
                    when pkg_res is
                        Ok(release) ->
                            ["| ", release.repo, " : ${release.tag}\n"]
                            |> colorize([theme.primary, theme.secondary, theme.primary])
                            |> Verbose
                            |> log!(log_level)
                            List.append(releases, release) |> Ok

                        Err(PackageReleaseErrorHandled) -> Ok(releases)

                Err(PackageRepoLookupErrorHandled) -> Ok(releases),
    )
    |> Result.with_default([])

handle_platform_repo_error = |name, { log_level, theme }|
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
                Err(PlatformRepoLookupErrorHandled)

            RepoNotFoundButMaybe(suggestion) ->
                log_strs = ["Platform: ", name, " : repo not found; did you mean ${suggestion}? - valid platform is required\n"]
                message =
                    when log_level is
                        Verbose -> log_strs |> colorize([theme.primary, theme.secondary, theme.error]) |> Verbose
                        Quiet -> log_strs |> colorize([theme.error]) |> Quiet
                        _ -> Verbose("")
                log!(message, log_level)
                Err(PlatformRepoLookupErrorHandled)

            AmbiguousName ->
                log_strs = ["Platform: ", name, " : ambiguous; use <owner>/${name} - valid platform is required\n"]
                message =
                    when log_level is
                        Verbose -> log_strs |> colorize([theme.primary, theme.secondary, theme.error]) |> Verbose
                        Quiet -> log_strs |> colorize([theme.error]) |> Quiet
                        _ -> Verbose("")
                log!(message, log_level)
                Err(PlatformRepoLookupErrorHandled)

handle_package_repo_error = |name, { log_level, theme }|
    |err|
        when err is
            RepoNotFound ->
                _ =
                    ["| ", name, " : package repo not found - skipping\n"]
                    |> colorize([theme.error, theme.secondary, theme.error])
                    |> Verbose
                    |> log!(log_level)
                Err(PackageRepoLookupErrorHandled)

            RepoNotFoundButMaybe(suggestion) ->
                _ =
                    ["| ", name, " : package repo not found; did you mean ${suggestion}? - skipping\n"]
                    |> colorize([theme.error, theme.secondary, theme.error])
                    |> Verbose
                    |> log!(log_level)
                Err(PackageRepoLookupErrorHandled)

            AmbiguousName ->
                _ =
                    ["| ", name, " : ambiguous; use <owner>/${name} - skipping\n"]
                    |> colorize([theme.error, theme.secondary, theme.error])
                    |> Verbose
                    |> log!(log_level)
                Err(PackageRepoLookupErrorHandled)

handle_package_release_error = |packages, repo, name, version, { log_level, theme }|
    |err|
        when err is
            RepoNotFound ->
                _ =
                    ["| ", name, " : package not found - skipping\n"]
                    |> colorize([theme.error, theme.secondary, theme.error])
                    |> Verbose
                    |> log!(log_level)
                Err(PackageReleaseErrorHandled)

            RepoNotFoundButMaybe(suggestion) ->
                _ =
                    ["| ", name, " : package not found; did you mean ${suggestion}? - skipping\n"]
                    |> colorize([theme.error, theme.secondary, theme.error])
                    |> Verbose
                    |> log!(log_level)
                Err(PackageReleaseErrorHandled)

            VersionNotFound ->
                when RM.get_repo_release(packages, repo, "latest", Package) is
                    Ok(suggestion) ->
                        _ =
                            ["| ", name, " : version not found; latest is ${suggestion.tag} - skipping\n"]
                            |> colorize([theme.error, theme.secondary, theme.error])
                            |> Verbose
                            |> log!(log_level)
                        Err(PackageReleaseErrorHandled)

                    Err(_) ->
                        _ =
                            ["| ", name, " : version ${version} not found - skipping\n"]
                            |> colorize([theme.error, theme.secondary, theme.error])
                            |> Verbose
                            |> log!(log_level)
                        Err(PackageReleaseErrorHandled)

handle_platform_release_error = |platforms, repo, name, version, { log_level, theme }|
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
                Err(PlatformReleaseErrorHandled)

            RepoNotFoundButMaybe(suggestion) ->
                log_strs = ["Platform: ", name, " : repo not found; did you mean ${suggestion}? - valid platform is required\n"]
                message =
                    when log_level is
                        Verbose -> log_strs |> colorize([theme.primary, theme.secondary, theme.error]) |> Verbose
                        Quiet -> log_strs |> colorize([theme.error]) |> Quiet
                        _ -> Verbose("")
                log!(message, log_level)
                Err(PlatformReleaseErrorHandled)

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
                        Err(PlatformReleaseErrorHandled)

                    Err(_) ->
                        log_strs = ["Platform: ", name, " : version ${version} not found - valid platform is required\n"]
                        message =
                            when log_level is
                                Verbose -> log_strs |> colorize([theme.primary, theme.secondary, theme.error]) |> Verbose
                                Quiet -> log_strs |> colorize([theme.error]) |> Quiet
                                _ -> Verbose("")
                        log!(message, log_level)
                        Err(PlatformReleaseErrorHandled)

known_packages_url = "https://raw.githubusercontent.com/imclerran/roc-repo/refs/heads/main/known-packages.csv"
known_platforms_url = "https://raw.githubusercontent.com/imclerran/roc-repo/refs/heads/main/known-platforms.csv"

get_repo_dir! = |{}| Env.var!("HOME")? |> Str.concat("/.cache/roc-start") |> Ok

get_repositories! : { log_level : LogLevel, theme : Theme } => Result { packages : RepositoryDict, platforms : RepositoryDict } [FileReadError, FileWriteError, GhAuthError, GhNotInstalled, HomeVarNotSet, NetworkError, ParsingError, BadRepoReleasesData]
get_repositories! = |logging|
    repo_dir = get_repo_dir!({}) ? |_| HomeVarNotSet
    Dir.create_all!(repo_dir) ? |_| FileWriteError
    packages_path = repo_dir |> Str.drop_suffix("/") |> Str.concat("/package-releases")
    platforms_path = repo_dir |> Str.drop_suffix("/") |> Str.concat("/platform-releases")
    packages =
        when File.is_file!(packages_path) is
            Ok(bool) if bool ->
                File.read_bytes!(packages_path)
                ? |_| FileReadError
                |> RM.get_repos_from_json_bytes?

            _ -> do_package_update!(logging)?

    platforms =
        when File.is_file!(platforms_path) is
            Ok(bool) if bool ->
                File.read_bytes!(platforms_path)
                ? |_| FileReadError
                |> RM.get_repos_from_json_bytes?

            _ -> do_platform_update!(logging)?

    Ok({ packages, platforms })

do_package_update! : { log_level : LogLevel, theme : Theme } => Result RepositoryDict []_
do_package_update! = |{ log_level, theme }|
    repo_dir = get_repo_dir!({}) ? |_| HomeVarNotSet
    "Updating packages... " |> ANSI.color({ fg: theme.tertiary }) |> Quiet |> log!(log_level)
    known_packages_csv =
        Http.send!({ Http.default_request & uri: known_packages_url })
        ? |_| NetworkError
        |> .body
        |> Str.from_utf8_lossy
    packages = known_packages_csv |> RM.update_local_repos!("${repo_dir}/package-releases")?
    "✔\n" |> ANSI.color({ fg: theme.okay }) |> Quiet |> log!(log_level)
    Ok(packages)

do_platform_update! : { log_level : LogLevel, theme : Theme } => Result RepositoryDict []_
do_platform_update! = |{ log_level, theme }|
    repo_dir = get_repo_dir!({}) ? |_| HomeVarNotSet
    "Updating platforms... " |> ANSI.color({ fg: theme.tertiary }) |> Quiet |> log!(log_level)
    known_platforms_csv =
        Http.send!({ Http.default_request & uri: known_platforms_url })
        ? |_| NetworkError
        |> .body
        |> Str.from_utf8_lossy
    platforms = known_platforms_csv |> RM.update_local_repos!("${repo_dir}/platform-releases")?
    "✔\n" |> ANSI.color({ fg: theme.okay }) |> Quiet |> log!(log_level)
    Ok(platforms)

do_scripts_update! : [Some RepositoryDict, None], { log_level : LogLevel, theme : Theme } => Result {} []_
do_scripts_update! = |maybe_pfs, { log_level, theme }|
    "Updating scripts... " |> ANSI.color({ fg: theme.tertiary }) |> Quiet |> log!(log_level)
    platforms =
        when maybe_pfs is
            Some(pfs) -> pfs
            None -> get_repositories!({ log_level, theme })? |> .platforms
    cache_dir =
        get_repo_dir!({})
        ? |_| HomeVarNotSet
        |> Str.concat("/scripts")
    cache_scripts!(platforms, cache_dir) ? |_| FileWriteError
    "✔\n" |> ANSI.color({ fg: theme.okay }) |> Quiet |> log!(log_level)
    Ok({})
