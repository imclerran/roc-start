app [main!] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.19.0/Hj-J_zxz7V9YurCSTFcFdu6cQJie4guzsPMUi5kBYUk.tar.br",
    semver: "https://github.com/imclerran/roc-semver/releases/download/v0.2.0%2Bimclerran/ePmzscvLvhwfllSFZGgTp77uiTFIwZQPgK_TiM6k_1s.tar.br",
    weaver: "https://github.com/smores56/weaver/releases/download/0.6.0/4GmRnyE7EFjzv6dDpebJoWWwXV285OMt4ntHIc6qvmY.tar.br",
    parse: "https://github.com/imclerran/roc-tinyparse/releases/download/v0.3.3/kKiVNqjpbgYFhE-aFB7FfxNmkXQiIo2f_mGUwUlZ3O0.tar.br",
    ansi: "https://github.com/lukewilliamboswell/roc-ansi/releases/download/0.8.0/RQlGWlkQEfxtkSYKl0nHNQaOFT0-Jh7NNFEX2IPXlec.tar.br",
    rtils: "https://github.com/imclerran/rtils/releases/download/v0.1.3/3_hF__4mdRmm8yMDwhrmlyOwFAppHBtLO__6K-QJSVU.tar.br",
    ansi: "https://github.com/lukewilliamboswell/roc-ansi/releases/download/0.8.0/RQlGWlkQEfxtkSYKl0nHNQaOFT0-Jh7NNFEX2IPXlec.tar.br",
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
    } exposing [PackageDict, PlatformDict, update_packages!, update_platforms!, get_packages_from_csv_text, get_platforms_from_csv_text]
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
                        Err(GetRepositoriesFailed) -> Ok({})
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
            e |> Stdout.line!

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

do_update_command! : { do_pfs : Bool, do_pkgs : Bool, do_stubs : Bool } => Result {} _
do_update_command! = |{ do_pfs, do_pkgs, do_stubs }|
    r1 =
        if do_pfs or !(do_pfs or do_pkgs or do_stubs) then
            do_platform_update!(Verbose) 
            |> Result.map_ok(|_| {})
            |> Result.map_err(|_| PlatformsUpdateFailed)
        else
            Ok({})

    r2 =
        if do_pkgs or !(do_pfs or do_pkgs or do_stubs) then
            do_package_update!(Verbose) 
            |> Result.map_ok(|_| {})
            |> Result.map_err(|_| PackagesUpdateFailed)
        else
            Ok({})

    r3 =
        if do_stubs or !(do_pfs or do_pkgs or do_stubs) then
            do_scripts_update!(Verbose) 
            |> Result.map_ok(|_| {}) 
            |> Result.map_err(|_| ScriptsUpdateFailed)
        else
            Ok({})

    when (r1, r2, r3) is
        (Ok(_), Ok(_), Ok(_)) -> Ok({})

        (Err(e), _, _) -> Err(e)

        (_, Err(e), _) -> Err(e)

        (_, _, Err(e)) -> Err(e)

do_app_command! : { force : Bool, out_name : [Err [NoValue], Ok Str], packages : List Str, platform : [Err [NoValue], Ok Str] } => Result {} _
do_app_command! = |app_args|
    arg_data = ArgHandler.handle_app(app_args)
    when File.is_file!(arg_data.file_name) is
        Ok(bool) if bool and !app_args.force ->
            "File already exists. Choose a different name or use --force"
            |> ANSI.color({ fg: magenta })
            |> Stdout.line!?
            Err(FileExists)

        _ ->
            ["Creating ", "${arg_data.file_name}", "..."]
            |> colorize([primary, secondary, primary])
            |> Stdout.line!?
            { packages, platforms } =  
                get_repositories!({}) 
                |> Result.on_err!(handle_get_repositories_error!) 
                |> Result.map_err(|_| GetRepositoriesFailed)?
            repo_names = List.join([Dict.keys(packages), Dict.keys(platforms)])
            repo_name_map = RepoManager.build_repo_name_map(repo_names)
            platform_repo = RepoManager.get_full_repo_name(repo_name_map, arg_data.platform.name)?
            platform_release = RepoManager.get_platform_release(platforms, platform_repo, arg_data.platform.version)?
            ["platform: ", platform_release.repo, " : ${platform_release.tag}"]
            |> colorize([primary, secondary, primary])
            |> Stdout.line!?
            base_cmd_args = [arg_data.file_name, platform_release.alias, platform_release.url]
            cmd_args = 
                if !List.is_empty(arg_data.packages) then
                    _ = "packages:"
                        |> ANSI.color({ fg: primary })
                        |> Stdout.line!
                    List.join([
                        base_cmd_args,
                        build_pacakge_arg_list!(packages, repo_name_map, arg_data),
                    ])
                    
                else
                    base_cmd_args
            cache_dir = get_repo_dir!({})? |> Str.concat("/scripts/")
            scripts = ScriptManager.get_available_scripts!(cache_dir, platform_repo)
            script_path = 
                cache_dir
                |> Str.concat(
                    ScriptManager.choose_script(platform_release.tag, scripts)
                    |> Result.map_ok(|s| "${platform_repo}/${s}")
                    |> Result.with_default("generic.sh")
                )
            Cmd.exec!("chmod", ["+x", script_path])?
            _ =
                Cmd.new(script_path)
                |> Cmd.args(cmd_args)
                |> Cmd.output!
            Ok({})

handle_get_repositories_error! : [FileReadError, FileWriteError, GhAuthError, GhNotInstalled, HomeVarNotSet, NetworkError, ParsingError] => Result * _
handle_get_repositories_error! = |e|
    when e is
        HomeVarNotSet -> 
            _ =  "HOME environment variable not set" |> ANSI.color({ fg: error }) |> Stdout.line!
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
                RepoManager.get_full_repo_name(repo_name_map, package.name)
                |> Result.on_err!(handle_package_repo_error(package.name))
            when package_repo_res is
                Ok(package_repo) ->
                    pkg_res = 
                        RepoManager.get_package_release(packages, package_repo, package.version)
                        |> Result.on_err!(handle_package_release_error(packages, package_repo, package.name, package.version))
                    when pkg_res is
                        Ok(pkg) ->
                            ["| ", pkg.repo, " : ${pkg.tag}"]
                            |> colorize([primary, secondary, primary])
                            |> Stdout.line!?
                            List.join([args_list, [pkg.alias, pkg.url]]) |> Ok
                        
                        Err(PackageReleaseErrorHandled) -> Ok(args_list)

                Err(PackageRepoLookupErrorHandled) -> Ok(args_list)
    ) |> Result.with_default([])

handle_package_release_error = |packages, repo, name, version|
    |err|
        when err is
            PackageNotFound ->
                _ = ["| ", name, " : package not found - skipping"]
                    |> colorize([error, secondary, error])
                    |> Stdout.line!
                Err(PackageReleaseErrorHandled)

            PackageNotFoundButMaybe(suggestion) ->
                _ = ["| ", name, " : package not found; did you mean ${suggestion}? - skipping"]
                    |> colorize([error, secondary, error])
                    |> Stdout.line!
                Err(PackageReleaseErrorHandled)

            VersionNotFound ->
                when RepoManager.get_package_release(packages, repo, "latest") is
                    Ok(suggestion) ->
                        _ = ["| ", name, " : version not found; latest is ${suggestion.tag} - skipping"]
                            |> colorize([error, secondary, error])
                            |> Stdout.line!
                        Err(PackageReleaseErrorHandled)

                    Err(_) -> 
                        _ = ["| ", name, " : version ${version} not found - skipping"]
                            |> colorize([error, secondary, error])
                            |> Stdout.line!
                        Err(PackageReleaseErrorHandled)

handle_package_repo_error = |name|
    |err|
        when err is
            NotFound ->
                _ = ["| ", name, " : package repo not found - skipping"]
                    |> colorize([error, secondary, error])
                    |> Stdout.line!
                Err(PackageRepoLookupErrorHandled)

            NotFoundButMaybe(suggestion) ->
                _ = ["| ", name, " : package repo not found; did you mean ${suggestion}? - skipping"]
                    |> colorize([error, secondary, error])
                    |> Stdout.line!
                Err(PackageRepoLookupErrorHandled)

            AmbiguousName ->
                _ = ["| ", name, " : ambiguous; use <owner>/${name} - skipping"]
                    |> colorize([error, secondary, error])
                    |> Stdout.line!
                Err(PackageRepoLookupErrorHandled)
        

known_packages_url = "https://raw.githubusercontent.com/imclerran/roc-repo/refs/heads/main/known-packages.csv"
known_platforms_url = "https://raw.githubusercontent.com/imclerran/roc-repo/refs/heads/main/known-platforms.csv"

get_repo_dir! = |{}| Env.var!("HOME")? |> Str.concat("/.roc-start") |> Ok

get_repositories! : {} => Result { packages : PackageDict, platforms : PlatformDict } [FileReadError, FileWriteError, GhAuthError, GhNotInstalled, HomeVarNotSet, NetworkError, ParsingError]
get_repositories! = |{}|
    repo_dir = get_repo_dir!({}) ? |_| HomeVarNotSet
    Dir.create_all!(repo_dir) ? |_| FileWriteError
    packages_path = repo_dir |> Str.drop_suffix("/") |> Str.concat("/package-releases.csv")
    platforms_path = repo_dir |> Str.drop_suffix("/") |> Str.concat("/platform-releases.csv")
    packages =
        when File.is_file!(packages_path) is
            Ok(bool) if bool ->
                File.read_utf8!(packages_path) ? |_| FileReadError
                |> get_packages_from_csv_text?

            _ ->
                # log!("Downloading packages from remote...", Verbose)
                known_packages_text = 
                    Http.send!({ Http.default_request & uri: known_packages_url }) ? |_| NetworkError
                    |> .body 
                    |> Str.from_utf8_lossy
                known_packages_text |> update_packages!(repo_dir)?
    platforms =
        when File.is_file!(platforms_path) is
            Ok(bool) if bool ->
                File.read_utf8!(platforms_path) ? |_| FileReadError
                |> get_platforms_from_csv_text?

            _ ->
                # log!("Downloading platforms from remote...", Verbose)
                known_platforms_text = 
                    Http.send!({ Http.default_request & uri: known_platforms_url }) ? |_| NetworkError  
                    |> .body 
                    |> Str.from_utf8_lossy
                known_platforms_text |> update_platforms!(repo_dir)?
    Ok({ packages, platforms })

do_package_update! : [Silent, Verbose] => Result PackageDict []_
do_package_update! = |log_level|
    repo_dir = get_repo_dir!({})?
    log!("Updating known packages...", log_level)
    known_packages_csv =
        Http.send!({ Http.default_request & uri: known_packages_url })?
        |> .body
        |> Str.from_utf8_lossy
    packages = known_packages_csv |> update_packages!(repo_dir)?
    log!("Done.\n", log_level)
    Ok(packages)

do_platform_update! : [Silent, Verbose] => Result PlatformDict []_
do_platform_update! = |log_level|
    repo_dir = get_repo_dir!({})?
    log!("Updating known platforms...", log_level)
    known_platforms_csv =
        Http.send!({ Http.default_request & uri: known_platforms_url })?
        |> .body
        |> Str.from_utf8_lossy
    platforms = known_platforms_csv |> update_platforms!(repo_dir)?
    log!("Done.\n", log_level)
    Ok(platforms)

do_scripts_update! : [Silent, Verbose] => Result {} []_
do_scripts_update! = |log_level|
    log!("Downloading scripts...", log_level)
    platforms = get_repositories!({})? |> .platforms
    cache_dir = get_repo_dir!({})? |> Str.concat("/scripts")
    cache_scripts!(platforms, cache_dir)?
    log!("Done.\n", log_level)
    Ok({})
