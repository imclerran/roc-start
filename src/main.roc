app [main!] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.19.0/Hj-J_zxz7V9YurCSTFcFdu6cQJie4guzsPMUi5kBYUk.tar.br",
    semver: "https://github.com/imclerran/roc-semver/releases/download/v0.2.0%2Bimclerran/ePmzscvLvhwfllSFZGgTp77uiTFIwZQPgK_TiM6k_1s.tar.br",
    weaver: "https://github.com/smores56/weaver/releases/download/0.6.0/4GmRnyE7EFjzv6dDpebJoWWwXV285OMt4ntHIc6qvmY.tar.br",
    parse: "https://github.com/imclerran/roc-tinyparse/releases/download/v0.3.3/kKiVNqjpbgYFhE-aFB7FfxNmkXQiIo2f_mGUwUlZ3O0.tar.br",
    ansi: "https://github.com/lukewilliamboswell/roc-ansi/releases/download/0.8.0/RQlGWlkQEfxtkSYKl0nHNQaOFT0-Jh7NNFEX2IPXlec.tar.br",
    rtils: "https://github.com/imclerran/rtils/releases/download/v0.1.5/qkk2T6MxEFLNKfQFq9GBk3nq6S2TMkbtHPt7KIHnIew.tar.br",
    json: "https://github.com/lukewilliamboswell/roc-json/releases/download/0.12.0/1trwx8sltQ-e9Y2rOB4LWUWLS_sFVyETK8Twl0i9qpw.tar.gz",
    heck: "https://github.com/imclerran/roc-heck/releases/download/v0.1.0/jxGXBo18syk4Ej1V5Y7lP5JnjKlCg_yIzdadvx7Tqc8.tar.br",
}

import cli.Arg exposing [to_os_raw]
import cli.Stdout
import cli.Stdin
import cli.Cmd
import cli.File
import cli.Dir
import cli.Http
import cli.Env
import cli.Path
import cli.Tty
import ansi.ANSI
import Model exposing [Model]
import View
import Controller
import InputHandlers exposing [handle_input]
import Theme exposing [Theme]
import ArgParser
import RepoUpdater {
    write_bytes!: File.write_bytes!,
    cmd_output!: Cmd.output!,
    cmd_new: Cmd.new,
    cmd_args: Cmd.args,
} as RU
import RepoManager as RM exposing [RepositoryDict, RepositoryRelease]
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
} as Df
import Logger {
        write!: Stdout.write!,
    } exposing [LogLevel, log!, colorize]
import RocParser as RP
import ErrorHandlers as E

known_packages_url = "https://raw.githubusercontent.com/imclerran/roc-repo/refs/heads/main/packages.csv"
known_platforms_url = "https://raw.githubusercontent.com/imclerran/roc-repo/refs/heads/main/platforms.csv"

main! = |args|
    config = Df.get_config!({})
    when ArgParser.parse_or_display_message(args, to_os_raw) is
        Ok({ verbosity, theme: colors, subcommand }) ->
            theme =
                when colors is
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
                    |> Result.map_err(handle_unhandled_errors(log_level, theme))

                Ok(App(app_args)) ->
                    args_with_defaults = app_args_with_defaults(app_args, config)
                    do_app_command!(args_with_defaults, logging)
                    |> Result.map_err(handle_unhandled_errors(log_level, theme))

                Ok(Package(pkg_args)) ->
                    do_package_command!(pkg_args, logging)
                    |> Result.map_err(handle_unhandled_errors(log_level, theme))

                Ok(Upgrade(upgrade_args)) ->
                    do_upgrade_command!(upgrade_args, logging)
                    |> Result.map_err(handle_unhandled_errors(log_level, theme))

                Ok(Tui(_tui_args)) ->
                    do_tui_command!(logging)
                    |> Result.map_err(handle_unhandled_errors(log_level, theme))

                Ok(Config(config_args)) ->
                    do_config_command!(config_args, logging)
                    |> Result.map_err(handle_unhandled_errors(log_level, theme))

                Err(NoSubcommand) ->
                    do_tui_command!(logging)
                    |> Result.map_err(handle_unhandled_errors(log_level, theme))

        Err(e) ->
            "${e}\n" |> Quiet |> log!(Verbose)
            Err(Exit(1, ""))

handle_unhandled_errors = |log_level, theme|
    |e|
        when e is
            _ if log_level == Silent -> Exit(1, "")
            Handled -> Exit(1, "")
            Exit(_, _) -> e
            _ -> Exit(1, [Inspect.to_str(e)] |> colorize([theme.error]))

app_args_with_defaults = |app_args, config|
    when app_args.platform.name is
        "" -> { app_args & platform: config.platform }
        _ -> app_args

do_config_command! = |args, logging|
    theme = logging.theme
    log_level = logging.log_level
    changes =
        [("theme", args.theme), ("verbosity", args.verbosity), ("platform", args.platform)]
        |> List.keep_oks(
            |(key, maybe_value)|
                when maybe_value is
                    Ok(value) -> Ok({ key, value })
                    Err(NoValue) -> Err(NoValue),
        )
    if List.is_empty(changes) then
        ["Nothing to configure.\n"] |> colorize([theme.primary]) |> Quiet |> log!(log_level) |> Ok
    else
        List.for_each_try!(
            changes,
            |{ key, value }|
                Df.save_to_dotfile!({ key, value }),
        )
        |> Result.map_err(
            |e|
                when log_level is
                    Quiet | Verbose ->
                        when e is
                            FileReadError -> Exit(1, ["Error saving config: error reading current config."] |> colorize([theme.error]))
                            FileWriteError -> Exit(1, ["Error saving config: error writing to config file."] |> colorize([theme.error]))
                            HomeVarNotSet -> Exit(1, ["Error saving config: HOME variable not set."] |> colorize([theme.error]))

                    Silent ->
                        Exit(1, ""),
        )?
        ["Configuration saved. ", "✔️\n"] |> colorize([theme.primary, theme.okay]) |> Quiet |> log!(log_level) |> Ok

do_update_command! : { do_platforms : Bool, do_packages : Bool, do_scripts : Bool }, { log_level : LogLevel, theme : Theme } => Result {} _
do_update_command! = |{ do_platforms, do_packages, do_scripts }, logging|
    pf_res =
        if do_platforms or !(do_platforms or do_packages or do_scripts) then
            do_platform_update!(logging)
        else
            Ok(Dict.empty({}))

    pk_res =
        if do_packages or !(do_platforms or do_packages or do_scripts) then
            do_package_update!(logging)
        else
            Ok(Dict.empty({}))

    sc_res =
        if do_scripts or !(do_platforms or do_packages or do_scripts) then
            maybe_pfs =
                when pf_res is
                    Ok(dict) if !Dict.is_empty(dict) -> Some(dict)
                    _ -> None
            do_scripts_update!(maybe_pfs, logging)
        else
            Ok({})

    when (pf_res, pk_res, sc_res) is
        (Ok(_), Ok(_), Ok(_)) -> Ok({})
        (Err(e), _, _) -> Err(e)
        (_, Err(e), _) -> Err(e)
        (_, _, Err(e)) -> Err(e)

do_app_command! : { filename : Str, force : Bool, packages : List { name : Str, version : Str }*, platform : { name : Str, version : Str }* }*, { log_level : LogLevel, theme : Theme } => Result {} _
do_app_command! = |arg_data, logging|
    log_level = logging.log_level
    theme = logging.theme
    when File.is_file!(arg_data.filename) is
        Ok(bool) if bool and !arg_data.force ->
            "File <${arg_data.filename}> already exists. Choose a different name or use --force\n"
            |> ANSI.color({ fg: theme.error })
            |> Quiet
            |> log!(log_level)
            Err(Handled)

        _ ->
            { packages, platforms } =
                get_repositories!(logging)
                |> Result.on_err(E.handle_get_repositories_error({ log_level, theme, colorize }))?
            _ =
                repo_dir = get_repo_dir!({}) ? |_| if log_level == Silent then Exit(1, "") else Exit(1, ["Error: HOME enviornmental variable not set."] |> colorize([theme.error]))
                scripts_exists =
                    when File.is_dir!("${repo_dir}/scripts") is
                        Ok(bool) -> bool
                        Err(_) -> Bool.false
                if !(scripts_exists) then
                    do_scripts_update!(Some(platforms), logging)
                else
                    Ok({})
            ["Creating ", "${arg_data.filename}", "...\n"]
            |> colorize([theme.primary, theme.secondary, theme.primary])
            |> Verbose
            |> log!(log_level)
            repo_name_map = List.join([Dict.keys(packages), Dict.keys(platforms)]) |> RM.build_repo_name_map
            platform_repo =
                RM.get_full_repo_name(repo_name_map, arg_data.platform.name, Platform)
                |> Result.on_err!(E.handle_platform_repo_error(arg_data.platform.name, { log_level, theme, log!, colorize }))?
            platform_release =
                RM.get_repo_release(platforms, platform_repo, arg_data.platform.version, Platform)
                |> Result.on_err!(E.handle_platform_release_error(platforms, platform_repo, arg_data.platform.name, arg_data.platform.version, { log_level, theme, log!, colorize }))?
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
            package_releases = resolve_package_releases!(packages, repo_name_map, arg_data.packages, logging)
            cmd_args = build_script_args(arg_data.filename, platform_release, package_releases)
            num_packages = List.len(package_releases)
            num_skipped = List.len(arg_data.packages) - num_packages
            cache_dir =
                get_repo_dir!({})
                ? |_| if log_level == Silent then Exit(1, "") else Exit(1, ["Error: HOME enviornmental variable not set."] |> colorize([theme.error]))
                |> Str.concat("/scripts/")
            scripts = ScriptManager.get_available_scripts!(cache_dir, platform_repo)
            script_path_res =
                ScriptManager.choose_script(platform_release.tag, scripts)
                |> Result.map_ok(|s| "${cache_dir}/${platform_repo}/${s}")
            when script_path_res is
                Ok(script_path) ->
                    Cmd.exec!("chmod", ["+x", script_path]) ? |_| Exit(1, ["Failed to make generation script executable."] |> colorize([theme.error]))
                    res =
                        Cmd.new(script_path)
                        |> Cmd.args(cmd_args)
                        |> Cmd.output!
                    when res.status is
                        Ok(_) ->
                            print_app_finish_message!(arg_data.filename, num_packages, num_skipped, logging) |> Ok

                        Err(_) ->
                            Err(Exit(1, ["Failed to run generation script."] |> colorize([theme.error])))

                Err(_) ->
                    build_default_app!(arg_data.filename, platform_release, package_releases)
                    |> Result.map_err(|_| Exit(1, ["Error writing to ${arg_data.filename}."] |> colorize([theme.error])))?
                    print_app_finish_message!(arg_data.filename, num_packages, num_skipped, logging) |> Ok

build_script_args : Str, RepositoryRelease, List RepositoryRelease -> List Str
build_script_args = |filename, platform, packages|
    List.join(
        [
            [filename, platform.alias, platform.url],
            alias_url_pairs(packages),
        ],
    )

do_package_command! = |args, logging|
    log_level = logging.log_level
    theme = logging.theme
    when File.is_file!("main.roc") is
        Ok(exists) if exists and !args.force ->
            "File <main.roc> already exists. Use `--force` to overwrite, or `upgrade` instead of `package` to upgrade or add dependencies.\n"
            |> ANSI.color({ fg: theme.error })
            |> Quiet
            |> log!(log_level)
            Err(Exit(1, ""))

        _ ->
            { packages } =
                get_repositories!(logging)
                |> Result.on_err(E.handle_get_repositories_error({ log_level, theme, colorize }))?
            ["Creating ", "main.roc", "...\n"]
            |> colorize([theme.primary, theme.secondary, theme.primary])
            |> Verbose
            |> log!(log_level)
            repo_name_map = Dict.keys(packages) |> RM.build_repo_name_map
            if !List.is_empty(args.packages) then
                "Packages:\n"
                |> ANSI.color({ fg: theme.primary })
                |> Verbose
                |> log!(log_level)
            else
                {}
            package_releases = resolve_package_releases!(packages, repo_name_map, args.packages, logging)
            num_packages = List.len(package_releases)
            num_skipped = List.len(args.packages) - num_packages

            build_package!(package_releases)
            |> Result.map_err(|_| Exit(1, ["Error writing to main.roc."] |> colorize([theme.error])))?
            print_app_finish_message!("main.roc", num_packages, num_skipped, logging) |> Ok

alias_url_pairs = |releases|
    List.map(releases, |release| [release.alias, release.url]) |> List.join

print_app_finish_message! = |filename, num_packages, num_skipped, { log_level, theme }|
    package_s = if num_packages == 1 then "package" else "packages"
    skipped_package_s = if num_skipped == 1 then "package" else "packages"
    if num_skipped == 0 then
        ["Created ", filename, " with ", Num.to_str(num_packages), " ${package_s} ", "✔\n"]
        |> colorize([theme.primary, theme.secondary, theme.primary, theme.secondary, theme.primary, theme.okay])
        |> Quiet
        |> log!(log_level)
    else
        ["Created ", filename, " with ", Num.to_str(num_packages), " ${package_s} and skipped ", Num.to_str(num_skipped), " ${skipped_package_s} ", "✔\n"]
        |> colorize([theme.primary, theme.secondary, theme.primary, theme.secondary, theme.primary, theme.warn, theme.primary, theme.okay])
        |> Quiet
        |> log!(log_level)

build_default_app! = |filename, platform, packages|
    "app [main!] {\n"
    |> Str.concat("    ${platform.alias}: platform \"${platform.url}\",\n")
    |> Str.concat(
        List.map(packages, |pkg| "    ${pkg.alias}: \"${pkg.url}\",\n")
        |> Str.join_with(""),
    )
    |> Str.concat("}\n")
    |> File.write_utf8!(filename)
    |> Result.map_err(|_| FileWriteError)?
    Ok({})

build_package! = |packages|
    "package [] {\n"
    |> Str.concat(
        List.map(packages, |pkg| "    ${pkg.alias}: \"${pkg.url}\",\n")
        |> Str.join_with(""),
    )
    |> Str.concat("}\n")
    |> File.write_utf8!("main.roc")
    |> Result.map_err(|_| FileWriteError)?
    Ok({})

resolve_package_releases! = |packages, repo_name_map, requested_packages, { log_level, theme }|
    List.walk_try!(
        requested_packages,
        [],
        |releases, package|
            package_repo_res =
                RM.get_full_repo_name(repo_name_map, package.name, Package)
                |> Result.on_err!(E.handle_package_repo_error(package.name, { log_level, theme, log!, colorize }))
            when package_repo_res is
                Ok(package_repo) ->
                    pkg_res =
                        RM.get_repo_release(packages, package_repo, package.version, Package)
                        |> Result.on_err!(E.handle_package_release_error(packages, package_repo, package.name, package.version, { log_level, theme, log!, colorize }))
                    when pkg_res is
                        Ok(release) ->
                            ["| ", release.repo, " : ${release.tag}\n"]
                            |> colorize([theme.primary, theme.secondary, theme.primary])
                            |> Verbose
                            |> log!(log_level)
                            List.append(releases, release) |> Ok

                        Err(Handled) -> Ok(releases)

                Err(Handled) -> Ok(releases),
    )
    |> Result.with_default([])

get_repo_dir! = |{}| Env.var!("HOME")? |> Str.concat("/.cache/roc-start") |> Ok

get_repositories! : { log_level : LogLevel, theme : Theme } => Result { packages : RepositoryDict, platforms : RepositoryDict } _ # [FileReadError, FileWriteError, GhAuthError, GhNotInstalled, HomeVarNotSet, NetworkError, ParsingError, BadRepoReleasesData, Exit (Num *) Str]
get_repositories! = |logging|
    repo_dir =
        get_repo_dir!({})
        ? |_| Exit(1, ["Error: HOME enviornmental variable not set."] |> colorize([logging.theme.error]))
    Dir.create_all!(repo_dir)
    ? |_| Exit(1, ["Error creating cache directory."] |> colorize([logging.theme.error]))
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

do_package_update! : { log_level : LogLevel, theme : Theme } => Result RepositoryDict [Exit (Num *) Str]
do_package_update! = |{ log_level, theme }|
    repo_dir =
        get_repo_dir!({})
        ? |_| if log_level == Silent then Exit(1, "") else Exit(1, ["Error: HOME enviornmental variable not set."] |> colorize([theme.error]))
    # ? |_| HomeVarNotSet
    "Updating packages " |> ANSI.color({ fg: theme.primary }) |> Quiet |> log!(log_level)
    known_packages_csv =
        Http.send!({ Http.default_request & uri: known_packages_url })
        ? |e| Exit(1, ["Error fetching package data: ${Inspect.to_str(e)}"] |> colorize([theme.error]))
        |> .body
        |> Str.from_utf8_lossy
    logger! = |str| str |> ANSI.color({ fg: theme.secondary }) |> Quiet |> log!(log_level)
    packages =
        known_packages_csv
        |> RU.update_local_repos!("${repo_dir}/package-releases", logger!)
        |> Result.on_err(E.handle_update_local_repos_error({ log_level, theme, colorize }))?
    "✔\n" |> ANSI.color({ fg: theme.okay }) |> Quiet |> log!(log_level)
    Ok(packages)

do_platform_update! : { log_level : LogLevel, theme : Theme } => Result RepositoryDict [Exit (Num *) Str]
do_platform_update! = |{ log_level, theme }|
    repo_dir =
        get_repo_dir!({})
        ? |_| Exit(1, ["Error: HOME enviornmental variable not set."] |> colorize([theme.error]))
    # ? |_| HomeVarNotSet
    "Updating platforms " |> ANSI.color({ fg: theme.primary }) |> Quiet |> log!(log_level)
    known_platforms_csv =
        Http.send!({ Http.default_request & uri: known_platforms_url })
        ? |e| Exit(1, ["Error fetching platform data: ${Inspect.to_str(e)}"] |> colorize([theme.error]))
        |> .body
        |> Str.from_utf8_lossy
    logger! = |str| str |> ANSI.color({ fg: theme.secondary }) |> Quiet |> log!(log_level)
    platforms =
        known_platforms_csv
        |> RU.update_local_repos!("${repo_dir}/platform-releases", logger!)
        |> Result.on_err(E.handle_update_local_repos_error({ log_level, theme, colorize }))?
    "✔\n" |> ANSI.color({ fg: theme.okay }) |> Quiet |> log!(log_level)
    Ok(platforms)

do_scripts_update! : [Some RepositoryDict, None], { log_level : LogLevel, theme : Theme } => Result {} [Exit (Num *) Str]
do_scripts_update! = |maybe_pfs, { log_level, theme }|
    "Updating scripts " |> ANSI.color({ fg: theme.primary }) |> Quiet |> log!(log_level)
    platforms =
        when maybe_pfs is
            Some(pfs) -> pfs
            None ->
                get_repositories!({ log_level, theme })
                |> Result.on_err(E.handle_get_repositories_error({ log_level, theme, colorize }))?
                |> .platforms
    cache_dir =
        get_repo_dir!({})
        ? |_| if log_level == Silent then Exit(1, "") else Exit(1, ["Error: HOME enviornmental variable not set."] |> colorize([theme.error]))
        |> Str.concat("/scripts")
    logger! = |str| str |> ANSI.color({ fg: theme.secondary }) |> Quiet |> log!(log_level)
    cache_scripts!(platforms, cache_dir, logger!)
    |> Result.on_err(E.handle_cache_scripts_error({ log_level, theme, log!, colorize }))?
    # ? |_| Exit(1, ["File write error while caching scripts."] |> colorize([theme.error]))
    "✔\n" |> ANSI.color({ fg: theme.okay }) |> Quiet |> log!(log_level)
    Ok({})

do_upgrade_command! = |args, { log_level, theme }|
    file_text =
        File.read_utf8!(args.filename)
        |> Result.on_err!(E.handle_upgrade_file_read_error(args.filename, { log_level, theme, log!, colorize }))?
    ["Upgrading ", args.filename, "...\n"] |> colorize([theme.primary, theme.secondary, theme.primary]) |> Verbose |> log!(log_level)
    { packages, platforms } =
        get_repositories!({ log_level, theme })
        |> Result.on_err(E.handle_get_repositories_error({ log_level, theme, colorize }))?
    repo_name_map = List.join([Dict.keys(packages), Dict.keys(platforms)]) |> RM.build_repo_name_map
    file_parts =
        split_file(file_text)
        |> Result.on_err(E.handle_upgrade_split_file_error(args.filename, { log_level, theme, colorize }))?
    platform_repo =
        when args.platform is
            Ok({ name: pf_name }) ->
                RM.get_full_repo_name(repo_name_map, pf_name, Platform)
                |> Result.on_err!(E.handle_upgrade_platform_repo_error(pf_name, { log_level, theme, log!, colorize }))

            Err(_) -> Err(NoPlatformRepo)
    platform_release =
        when args.platform is
            Ok({ name: pf_name, version: pf_version }) ->
                when platform_repo is
                    Ok(repo) ->
                        release =
                            RM.get_repo_release(platforms, repo, pf_version, Platform)
                            |> Result.on_err!(E.handle_upgrade_platform_release_error(platforms, repo, pf_name, pf_version, { log_level, theme, log!, colorize }))
                        when release is
                            Ok(r) ->
                                ["Platform: ", r.repo, " : ${r.tag}\n"]
                                |> colorize([theme.primary, theme.secondary, theme.primary])
                                |> Verbose
                                |> log!(log_level)
                                release

                            Err(_) -> Err(NoPlatformRelease)

                    Err(_) -> Err(NoPlatformRelease)

            Err(_) -> Err(NoPlatformRelease)

    if !List.is_empty(args.packages) then
        "Packages:\n"
        |> ANSI.color({ fg: theme.primary })
        |> Verbose
        |> log!(log_level)
    else
        {}
    package_releases = resolve_package_releases!(packages, repo_name_map, args.packages, { log_level, theme })
    num_packages = List.len(package_releases)
    num_skipped = List.len(args.packages) - num_packages
    { upgraded, pf_upgraded } =
        List.walk(
            file_parts.dependencies,
            { pf_updated: Bool.false, not_found: package_releases, updated: [] },
            |acc, dep_line|
                if dep_line |> Str.contains("platform") then
                    when RP.parse_platform_line(dep_line) is
                        Ok({ alias, path }) ->
                            when platform_release is
                                Ok(release) ->
                                    dep_str = "${file_parts.indent}${alias}: platform \"${release.url}\","

                                    { acc & pf_updated: Bool.true, updated: List.append(acc.updated, dep_str) }

                                Err(_) ->
                                    dep_str = "${file_parts.indent}${alias}: platform \"${path}\","
                                    { acc & updated: List.append(acc.updated, dep_str) }

                        Err(InvalidPlatformLine) ->
                            dep_str = "${file_parts.indent}${Str.trim_start(dep_line)}"
                            { acc & updated: List.append(acc.updated, dep_str) }
                else
                    when RP.parse_package_line(dep_line) is
                        Ok({ alias, path }) ->
                            when RP.parse_repo_owner_name(path) is
                                Ok({ owner, name }) ->
                                    when List.find_first(acc.not_found, |{ repo }| repo == "${owner}/${name}") is
                                        Ok(release) ->
                                            dep_str = "${file_parts.indent}${alias}: \"${release.url}\","
                                            new_updated = List.append(acc.updated, dep_str)
                                            new_not_found = List.drop_if(acc.not_found, |{ repo: r }| r == release.repo)
                                            { acc & not_found: new_not_found, updated: new_updated }

                                        Err(_) ->
                                            dep_str = "${file_parts.indent}${alias}: \"${path}\","
                                            { acc & updated: List.append(acc.updated, dep_str) }

                                Err(InvalidRepoUrl) ->
                                    dep_str = "${file_parts.indent}${alias}: \"${path}\","
                                    { acc & updated: List.append(acc.updated, dep_str) }

                        Err(InvalidPackageLine) ->
                            dep_str = "${file_parts.indent}${Str.trim_start(dep_line)}"
                            { acc & updated: List.append(acc.updated, dep_str) },
        )
        |> |{ not_found, updated, pf_updated }|
            rest = List.map(not_found, |release| "${file_parts.indent}${release.alias}: \"${release.url}\",")
            { upgraded: List.join([updated, rest]), pf_upgraded: pf_updated }

    new_file = "${file_parts.prefix}{\n${Str.join_with(upgraded, "\n")}\n}${file_parts.rest}"

    File.write_utf8!(new_file, args.filename)
    |> Result.map_err(|_| Exit(1, ["Error writing to ${args.filename}."] |> colorize([theme.error])))?

    print_upgrade_finish_message!(args.filename, args.platform, pf_upgraded, num_packages, num_skipped, { log_level, theme })
    |> Ok

print_upgrade_finish_message! = |filename, platform, pf_upgraded, num_packages, num_skipped, { log_level, theme }|
    pf_requested =
        when platform is
            Ok(_) -> Bool.true
            _ -> Bool.false
    num_packages_str = Num.to_str(num_packages)
    num_skipped_str = Num.to_str(num_skipped)

    package_s = if num_packages == 1 then "package" else "packages"
    skipped_package_s = if num_skipped == 1 then "package" else "packages"

    if num_skipped == 0 and pf_upgraded then
        ["Upgraded ", filename, " with ", "1", " platform and ", num_packages_str, " ${package_s} ", "✔\n"]
        |> colorize([theme.primary, theme.secondary, theme.primary, theme.secondary, theme.primary, theme.secondary, theme.primary, theme.okay])
        |> Quiet
        |> log!(log_level)
    else if num_skipped == 0 and pf_requested and !pf_upgraded then
        ["Upgraded ", filename, " with ", num_packages_str, " ${package_s} and skipped ", "1", " platform ", "✔\n"]
        |> colorize([theme.primary, theme.secondary, theme.primary, theme.secondary, theme.primary, theme.warn, theme.primary, theme.okay])
        |> Quiet
        |> log!(log_level)
    else if num_skipped == 0 and !pf_requested then
        ["Upgraded ", filename, " with ", num_packages_str, " ${package_s} ", "✔\n"]
        |> colorize([theme.primary, theme.secondary, theme.primary, theme.secondary, theme.primary, theme.okay])
        |> Quiet
        |> log!(log_level)
    else if num_skipped > 0 and pf_upgraded then
        ["Upgraded ", filename, " with ", "1", " platform and ", num_packages_str, " ${package_s} and skipped ", num_skipped_str, " ${skipped_package_s} ", "✔\n"]
        |> colorize([theme.primary, theme.secondary, theme.primary, theme.secondary, theme.primary, theme.secondary, theme.primary, theme.warn, theme.primary, theme.okay])
        |> Quiet
        |> log!(log_level)
    else if num_skipped > 0 and pf_requested and !pf_upgraded then
        ["Upgraded ", filename, " with ", num_packages_str, " ${package_s} and skipped ", "1", " platform and ", num_skipped_str, " ${skipped_package_s} ", "✔\n"]
        |> colorize([theme.primary, theme.secondary, theme.primary, theme.secondary, theme.primary, theme.warn, theme.primary, theme.warn, theme.primary, theme.okay])
        |> Quiet
        |> log!(log_level)
    else
        # num_skipped > 0 and !pf_requested
        ["Upgraded ", filename, " with ", num_packages_str, " ${package_s} and skipped ", num_skipped_str, " ${skipped_package_s} ", "✔\n"]
        |> colorize([theme.primary, theme.secondary, theme.primary, theme.secondary, theme.primary, theme.warn, theme.primary, theme.okay])
        |> Quiet
        |> log!(log_level)

split_file : Str -> Result { prefix : Str, indent : Str, dependencies : List Str, rest : Str } [InvalidRocFile]
split_file = |text|
    { before: prefix, after: most } = Str.split_first(text, "{") ? |_| InvalidRocFile
    { before: deps, after: rest } = Str.split_first(most, "}") ? |_| InvalidRocFile
    dependencies =
        deps
        |> Str.split_on("\n")
        |> List.drop_if(|s| s |> Str.trim |> Str.is_empty)
    indent = get_indent(dependencies)
    trimmed = dependencies |> List.map(Str.trim_start)
    Ok({ prefix, indent, dependencies: trimmed, rest })

get_indent : List Str -> Str
get_indent = |lines|
    when lines is
        [_, second_line, ..] -> get_line_indent(second_line)
        [first_line] ->
            first_line
            |> get_line_indent
            |> |ind| if Str.count_utf8_bytes(ind) < 2 then (" " |> Str.repeat(4)) else ind

        [] -> ""

get_line_indent : Str -> Str
get_line_indent = |text|
    whitespace = [' ', '\t']
    List.walk_until(
        Str.to_utf8(text),
        [],
        |indent, byte|
            if List.contains(whitespace, byte) then
                Continue(List.append(indent, byte))
            else
                Break(indent),
    )
    |> Str.from_utf8_lossy

dir_exits! = |dirname|
    when File.is_dir!(dirname) is
        Ok(exits) -> exits
        Err(_) -> Bool.false

do_tui_command! = |{ log_level, theme }|
    { platforms, packages } =
        get_repositories!({ log_level, theme })
        |> Result.on_err(E.handle_get_repositories_error({ log_level, theme, colorize }))?
    repo_dir = get_repo_dir!({}) ? |_| if log_level == Silent then Exit(1, "") else Exit(1, ["Error: HOME enviornmental variable not set."] |> colorize([theme.error]))
    scripts_exists = dir_exits!("${repo_dir}/scripts")
    _ = if !(scripts_exists) then do_scripts_update!(Some(platforms), { log_level, theme }) else Ok({})
    initial_model = Model.init(platforms, packages, {})
    Tty.enable_raw_mode!({})
    final_model = ui_loop!(initial_model, theme)?
    Stdout.write!(ANSI.to_str(Reset))?
    Tty.disable_raw_mode!({})
    config = Df.get_config!({})
    when final_model.state is
        Finished({ choices }) ->
            when choices is
                App(args) -> do_app_command!(args, { log_level: config.verbosity, theme: config.theme })
                Package(args) -> do_package_command!(args, { log_level: config.verbosity, theme: config.theme })
                Upgrade(args) -> do_upgrade_command!(args, { log_level: config.verbosity, theme: config.theme })
                Config(args) -> do_config_command!(args, { log_level: config.verbosity, theme: config.theme })
                Update(args) -> do_update_command!(args, { log_level: config.verbosity, theme: config.theme })
                NothingToDo -> Ok({})

        UserExited -> Ok({})
        _ -> crash "Error: Unexpected final state"

ui_loop! : Model, Theme => Result Model _
ui_loop! = |prev_model, theme|
    terminal_size = get_terminal_size!({})?
    model = Controller.paginate({ prev_model & screen: terminal_size })
    ANSI.draw_screen(model, render(model, theme)) |> Stdout.write!?
    input = Stdin.bytes!({}) |> Result.map_ok(ANSI.parse_raw_stdin)?
    when handle_input(model, input) is
        Step(next_model) -> ui_loop!(next_model, theme)
        Done(next_model) -> Ok(next_model)

get_terminal_size! : {} => Result ANSI.ScreenSize _
get_terminal_size! = |{}|
    # Move the cursor to bottom right corner of terminal
    cmd = [Cursor(Abs({ row: 999, col: 999 })), Cursor(Position(Get))] |> List.map(Control) |> List.map(ANSI.to_str) |> Str.join_with("")
    Stdout.write!(cmd) ? |e| Exit(1, "Error while getting terminal size: ${Inspect.to_str(e)}")
    # Read the cursor position
    Stdin.bytes!({})
    |> Result.map_ok(ANSI.parse_cursor)
    |> Result.map_ok(|{ row, col }| { width: col, height: row })
    |> Result.map_err(|e| Exit(1, "Error while getting terminal size: ${Inspect.to_str(e)}"))

render : Model, Theme -> List ANSI.DrawFn
render = |model, theme|
    when model.state is
        MainMenu(_) -> View.render_main_menu(model, theme)
        SettingsMenu(_) -> View.render_settings_menu(model, theme)
        SettingsSubmenu(_) -> View.render_settings_submenu(model, theme)
        InputAppName(_) -> View.render_input_app_name(model, theme)
        PlatformSelect(_) -> View.render_platform_select(model, theme)
        PackageSelect(_) -> View.render_package_select(model, theme)
        VersionSelect(_) -> View.render_version_select(model, theme)
        UpdateSelect(_) -> View.render_update_select(model, theme)
        Search(_) -> View.render_search(model, theme)
        Confirmation(_) -> View.render_confirmation(model, theme)
        Splash(_) -> View.render_splash(model, theme)
        _ -> []
