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
import ArgParser exposing [parse_or_display_message]
import ArgHandler
import RepoManager {
        write_utf8!: File.write_utf8!,
        cmd_output!: Cmd.output!,
        cmd_new: Cmd.new,
        cmd_args: Cmd.args,
    } as RM exposing [PackageDict, PlatformDict, update_local_repos!, get_packages_from_csv_text, get_platforms_from_csv_text]
import ScriptManager {
        http_send!: Http.send!,
        file_write_utf8!: File.write_utf8!,
        create_all_dirs!: Dir.create_all!,
        list_dir!: Dir.list!,
        path_to_str: Path.display,
    } exposing [cache_scripts!]

main! = |args|
    when parse_or_display_message(args, to_os_raw) is
        Ok(subcommand) ->
            when subcommand is
                Ok(Update(update_args)) ->
                    do_update_command!(update_args)

                Ok(App(app_args)) ->
                    when do_app_command!(app_args) is
                        Err(PlatformRepoLookupErrorHandled) -> Ok({})
                        Err(PlatformReleaseErrorHandled) -> Ok({})
                        Err(GetRepositoriesFailed) -> Ok({})
                        Err(FileExists) -> Ok({})
                        any_other -> any_other

                Ok(Pkg(_pkg_args)) ->
                    "Pkg: not implemented"
                    |> ANSI.color({ fg: error })
                    |> Stdout.line!

                Ok(Upgrade(_upgrade_args)) ->
                    "Upgrade: not implemented"
                    |> ANSI.color({ fg: error })
                    |> Stdout.line!

                Ok(Tui(_tui_args)) ->
                    "Tui: not implemented"
                    |> ANSI.color({ fg: error })
                    |> Stdout.line!

                Err(NoSubcommand) ->
                    "TUI: not yet implemented"
                    |> ANSI.color({ fg: error })
                    |> Stdout.line!

        Err(e) ->
            e |> ANSI.color({ fg: primary }) |> Stdout.line!

# dark_purple = Rgb((107,58,220))
light_purple = Rgb((137, 101, 222))
magenta = Rgb((219, 57, 171))
dark_cyan = Rgb((57, 171, 219))

primary = light_purple
secondary = dark_cyan
# tertiary = dark_purple
error = magenta

colorize : List Str, List _ -> Str
colorize = |parts, colors|
    if List.len(parts) <= List.len(colors) then
        List.map2(parts, colors, |part, color| ANSI.color(part, { fg: color })) |> Str.join_with("")
    else
        rest =
            List.split_at(parts, List.len(colors))
            |> .others
            |> Str.join_with("")
            |> ANSI.color({ fg: Default })
        List.map2(parts, colors, |part, color| ANSI.color(part, { fg: color }))
        |> Str.join_with("")
        |> Str.concat(rest)

log! : Str, [Silent, Verbose] => {}
log! = |str, level|
    when level is
        Verbose ->
            _ = Stdout.write!(str)
            {}

        Silent -> {}

do_update_command! : { do_platforms : Bool, do_packages : Bool, do_scripts : Bool } => Result {} _
do_update_command! = |{ do_platforms, do_packages, do_scripts }|
    pf_res =
        if do_platforms or !(do_platforms or do_packages or do_scripts) then
            do_platform_update!(Verbose)
            |> Result.map_err(|_| PlatformsUpdateFailed)
        else
            Ok(Dict.empty({}))

    pk_res =
        if do_packages or !(do_platforms or do_packages or do_scripts) then
            do_package_update!(Verbose)
            |> Result.map_err(|_| PackagesUpdateFailed)
        else
            Ok(Dict.empty({}))

    sc_res =
        if do_scripts or !(do_platforms or do_packages or do_scripts) then
            maybe_pfs =
                when pf_res is
                    Ok(dict) if !Dict.is_empty(dict) -> Some(dict)
                    _ -> None
            # pfs = pf_res |> Result.with_default(Dict.empty({}))
            do_scripts_update!(maybe_pfs, Verbose)
            |> Result.map_err(|_| ScriptsUpdateFailed)
        else
            Ok({})

    when (pf_res, pk_res, sc_res) is
        (Ok(_), Ok(_), Ok(_)) -> Ok({})
        (Err(e), _, _) -> Err(e)
        (_, Err(e), _) -> Err(e)
        (_, _, Err(e)) -> Err(e)

do_app_command! : { force : Bool, out_name : [Err [NoValue], Ok Str], packages : List Str, platform : [Err [NoValue], Ok Str] } => Result {} _
do_app_command! = |app_args|
    arg_data = ArgHandler.handle_app(app_args)
    when File.is_file!(arg_data.file_name) is
        Ok(bool) if bool and !app_args.force ->
            "File <${arg_data.file_name}> already exists. Choose a different name or use --force"
            |> ANSI.color({ fg: magenta })
            |> Stdout.line!?
            Err(FileExists)

        _ ->
            ["Creating ", "${arg_data.file_name}", "..."]
            |> colorize([primary, secondary, primary])
            |> Stdout.line!?
            { packages, platforms } =
                get_repositories!(Verbose)
                |> Result.on_err!(handle_get_repositories_error!)
                |> Result.map_err(|_| GetRepositoriesFailed)?
            repo_names = List.join([Dict.keys(packages), Dict.keys(platforms)])
            repo_name_map = RM.build_repo_name_map(repo_names)
            platform_repo =
                RM.get_full_repo_name(repo_name_map, arg_data.platform.name, Platform)
                |> Result.on_err!(handle_platform_repo_error(arg_data.platform.name))?
            platform_release =
                RM.get_repo_release(platforms, platform_repo, arg_data.platform.version, Platform)
                |> Result.on_err!(handle_platform_release_error(platforms, platform_repo, arg_data.platform.name, arg_data.platform.version))?
            ["platform: ", platform_release.repo, " : ${platform_release.tag}"]
            |> colorize([primary, secondary, primary])
            |> Stdout.line!?
            base_cmd_args = [arg_data.file_name, platform_release.alias, platform_release.url]
            cmd_args =
                if !List.is_empty(arg_data.packages) then
                    _ =
                        "packages:"
                        |> ANSI.color({ fg: primary })
                        |> Stdout.line!
                    List.join(
                        [
                            base_cmd_args,
                            build_pacakge_arg_list!(packages, repo_name_map, arg_data),
                        ],
                    )
                else
                    base_cmd_args
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
                    Ok({})

                Err(_) ->
                    pkg_alias_url_list =
                        List.drop_first(cmd_args, 3)
                        |> List.chunks_of(2)
                        |> List.map(
                            |pair|
                                when pair is
                                    [alias, url] -> { alias, url }
                                    _ -> crash "List should alway be pairs.",
                        )
                    build_default_app!(arg_data.file_name, platform_release, pkg_alias_url_list)

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

handle_get_repositories_error! : [FileReadError, FileWriteError, GhAuthError, GhNotInstalled, HomeVarNotSet, NetworkError, ParsingError] => Result * _
handle_get_repositories_error! = |e|
    when e is
        HomeVarNotSet ->
            _ = "HOME environment variable not set" |> ANSI.color({ fg: error }) |> Stdout.line!
            Err(e)

        FileWriteError ->
            _ = "Error writing to file" |> ANSI.color({ fg: error }) |> Stdout.line!
            Err(e)

        FileReadError ->
            _ = "Error reading from file" |> ANSI.color({ fg: error }) |> Stdout.line!
            Err(e)

        GhAuthError ->
            _ = "GitHub CLI tool not authenticated" |> ANSI.color({ fg: error }) |> Stdout.line!
            Err(e)

        GhNotInstalled ->
            _ = "GitHub CLI tool not installed" |> ANSI.color({ fg: error }) |> Stdout.line!
            Err(e)

        NetworkError ->
            _ = "Network error" |> ANSI.color({ fg: error }) |> Stdout.line!
            Err(e)

        ParsingError ->
            _ = "Error parsing data" |> ANSI.color({ fg: error }) |> Stdout.line!
            Err(e)

build_pacakge_arg_list! = |packages, repo_name_map, processed_args|
    List.walk_try!(
        processed_args.packages,
        [],
        |args_list, package|
            package_repo_res =
                RM.get_full_repo_name(repo_name_map, package.name, Package)
                |> Result.on_err!(handle_package_repo_error(package.name))
            when package_repo_res is
                Ok(package_repo) ->
                    pkg_res =
                        RM.get_repo_release(packages, package_repo, package.version, Package)
                        |> Result.on_err!(handle_package_release_error(packages, package_repo, package.name, package.version))
                    when pkg_res is
                        Ok(pkg) ->
                            ["| ", pkg.repo, " : ${pkg.tag}"]
                            |> colorize([primary, secondary, primary])
                            |> Stdout.line!?
                            List.join([args_list, [pkg.alias, pkg.url]]) |> Ok

                        Err(PackageReleaseErrorHandled) -> Ok(args_list)

                Err(PackageRepoLookupErrorHandled) -> Ok(args_list),
    )
    |> Result.with_default([])

handle_platform_repo_error = |name|
    |err|
        when err is
            RepoNotFound ->
                _ =
                    ["platform: ", name, " : repo not found - valid platform is required"]
                    |> colorize([primary, secondary, error])
                    |> Stdout.line!
                Err(PlatformRepoLookupErrorHandled)

            RepoNotFoundButMaybe(suggestion) ->
                _ =
                    ["platform: ", name, " : repo not found; did you mean ${suggestion}? - valid platform is required"]
                    |> colorize([primary, secondary, error])
                    |> Stdout.line!
                Err(PlatformRepoLookupErrorHandled)

            AmbiguousName ->
                _ =
                    ["platform: ", name, " : ambiguous; use <owner>/${name} - valid platform is required"]
                    |> colorize([primary, secondary, error])
                    |> Stdout.line!
                Err(PlatformRepoLookupErrorHandled)

handle_package_repo_error = |name|
    |err|
        when err is
            RepoNotFound ->
                _ =
                    ["| ", name, " : package repo not found - skipping"]
                    |> colorize([error, secondary, error])
                    |> Stdout.line!
                Err(PackageRepoLookupErrorHandled)

            RepoNotFoundButMaybe(suggestion) ->
                _ =
                    ["| ", name, " : package repo not found; did you mean ${suggestion}? - skipping"]
                    |> colorize([error, secondary, error])
                    |> Stdout.line!
                Err(PackageRepoLookupErrorHandled)

            AmbiguousName ->
                _ =
                    ["| ", name, " : ambiguous; use <owner>/${name} - skipping"]
                    |> colorize([error, secondary, error])
                    |> Stdout.line!
                Err(PackageRepoLookupErrorHandled)

handle_package_release_error = |packages, repo, name, version|
    |err|
        when err is
            RepoNotFound ->
                _ =
                    ["| ", name, " : package not found - skipping"]
                    |> colorize([error, secondary, error])
                    |> Stdout.line!
                Err(PackageReleaseErrorHandled)

            RepoNotFoundButMaybe(suggestion) ->
                _ =
                    ["| ", name, " : package not found; did you mean ${suggestion}? - skipping"]
                    |> colorize([error, secondary, error])
                    |> Stdout.line!
                Err(PackageReleaseErrorHandled)

            VersionNotFound ->
                when RM.get_repo_release(packages, repo, "latest", Package) is
                    Ok(suggestion) ->
                        _ =
                            ["| ", name, " : version not found; latest is ${suggestion.tag} - skipping"]
                            |> colorize([error, secondary, error])
                            |> Stdout.line!
                        Err(PackageReleaseErrorHandled)

                    Err(_) ->
                        _ =
                            ["| ", name, " : version ${version} not found - skipping"]
                            |> colorize([error, secondary, error])
                            |> Stdout.line!
                        Err(PackageReleaseErrorHandled)

handle_platform_release_error = |platforms, repo, name, version|
    |err|
        when err is
            RepoNotFound ->
                _ =
                    ["platform: ", name, " : not found - valid platform is required"]
                    |> colorize([primary, secondary, error])
                    |> Stdout.line!
                Err(PlatformReleaseErrorHandled)

            RepoNotFoundButMaybe(suggestion) ->
                _ =
                    ["platform: ", name, " : not found; did you mean ${suggestion}? - valid platform is required"]
                    |> colorize([primary, secondary, error])
                    |> Stdout.line!
                Err(PlatformReleaseErrorHandled)

            VersionNotFound ->
                when RM.get_repo_release(platforms, repo, "latest", Platform) is
                    Ok(suggestion) ->
                        _ =
                            ["platform: ", name, " : version not found; latest is ${suggestion.tag} - valid platform is required"]
                            |> colorize([primary, secondary, error])
                            |> Stdout.line!
                        Err(PlatformReleaseErrorHandled)

                    Err(_) ->
                        _ =
                            ["platform: ", name, " : version ${version} not found - valid platform is required"]
                            |> colorize([primary, secondary, error])
                            |> Stdout.line!
                        Err(PlatformReleaseErrorHandled)

known_packages_url = "https://raw.githubusercontent.com/imclerran/roc-repo/refs/heads/main/known-packages.csv"
known_platforms_url = "https://raw.githubusercontent.com/imclerran/roc-repo/refs/heads/main/known-platforms.csv"

get_repo_dir! = |{}| Env.var!("HOME")? |> Str.concat("/.roc-start") |> Ok

get_repositories! : [Silent, Verbose] => Result { packages : PackageDict, platforms : PlatformDict } [FileReadError, FileWriteError, GhAuthError, GhNotInstalled, HomeVarNotSet, NetworkError, ParsingError]
get_repositories! = |log_level|
    repo_dir = get_repo_dir!({}) ? |_| HomeVarNotSet
    Dir.create_all!(repo_dir) ? |_| FileWriteError
    packages_path = repo_dir |> Str.drop_suffix("/") |> Str.concat("/package-releases.csv")
    platforms_path = repo_dir |> Str.drop_suffix("/") |> Str.concat("/platform-releases.csv")
    packages =
        when File.is_file!(packages_path) is
            Ok(bool) if bool ->
                File.read_utf8!(packages_path)
                ? |_| FileReadError
                |> get_packages_from_csv_text?

            _ ->
                log!("Downloading packages from remote...", log_level)
                known_packages_text =
                    Http.send!({ Http.default_request & uri: known_packages_url })
                    ? |_| NetworkError
                    |> .body
                    |> Str.from_utf8_lossy
                known_packages_text |> update_local_repos!("${repo_dir}/package-releases.csv")?
    platforms =
        when File.is_file!(platforms_path) is
            Ok(bool) if bool ->
                File.read_utf8!(platforms_path)
                ? |_| FileReadError
                |> get_platforms_from_csv_text?

            _ ->
                log!("Downloading platforms from remote...", log_level)
                known_platforms_text =
                    Http.send!({ Http.default_request & uri: known_platforms_url })
                    ? |_| NetworkError
                    |> .body
                    |> Str.from_utf8_lossy
                known_platforms_text |> update_local_repos!("${repo_dir}/platform-releases.csv")?
    Ok({ packages, platforms })

do_package_update! : [Silent, Verbose] => Result PackageDict []_
do_package_update! = |log_level|
    repo_dir = get_repo_dir!({})?
    log!("Updating packages...", log_level)
    known_packages_csv =
        Http.send!({ Http.default_request & uri: known_packages_url })?
        |> .body
        |> Str.from_utf8_lossy
    packages = known_packages_csv |> update_local_repos!("${repo_dir}/package-releases.csv")?
    log!("Done.\n", log_level)
    Ok(packages)

do_platform_update! : [Silent, Verbose] => Result PlatformDict []_
do_platform_update! = |log_level|
    repo_dir = get_repo_dir!({})?
    log!("Updating platforms...", log_level)
    known_platforms_csv =
        Http.send!({ Http.default_request & uri: known_platforms_url })?
        |> .body
        |> Str.from_utf8_lossy
    platforms = known_platforms_csv |> update_local_repos!("${repo_dir}/platform-releases.csv")?
    log!("Done.\n", log_level)
    Ok(platforms)

do_scripts_update! : [Some PlatformDict, None], [Silent, Verbose] => Result {} []_
do_scripts_update! = |maybe_pfs, log_level|
    log!("Updating scripts...", log_level)
    platforms =
        when maybe_pfs is
            Some(pfs) -> pfs
            None -> get_repositories!(log_level)? |> .platforms
    cache_dir = get_repo_dir!({})? |> Str.concat("/scripts")
    cache_scripts!(platforms, cache_dir)?
    log!("Done.\n", log_level)
    Ok({})
