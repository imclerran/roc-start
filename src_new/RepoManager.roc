module {
    write_utf8!, 
    cmd_output!, 
    cmd_new, 
    cmd_args 
} -> [
    PackageDict,
    PlatformDict,
    update_packages!,
    update_platforms!,
    get_packages_from_csv_text,
    get_platforms_from_csv_text,
    get_package_release,
    get_platform_release,
    build_repo_name_map,
    get_full_repo_name,
]

import parse.CSV exposing [csv_string]
import parse.Parse exposing [one_or_more, maybe, string, lhs, rhs, map, zip, zip_3, zip_4, zip_5, whitespace, finalize]
import semver.Semver
import semver.Types exposing [Semver]

PackageDict : Dict Str (List PackageRelease)
PackageRelease : { repo : Str, alias : Str, tag : Str, url : Str, semver : Semver }
PlatformDict : Dict Str (List PlatformRelease)
PlatformRelease : { repo : Str, alias : Str, requires : Str, tag : Str, url : Str, semver : Semver }

# Get packages and platforms from local or remote
# ------------------------------------------------------------------------------



            
        
    


# Get packages and platforms from csv text
# ------------------------------------------------------------------------------

get_packages_from_csv_text : Str -> Result PackageDict _ #[BadKnownPackagesCSV]_
get_packages_from_csv_text = |packages_text|
    packages_text
    |> parse_package_releases
    |> Result.map_err(|_| ParsingError)?
    |> build_package_dict
    |> Ok

get_platforms_from_csv_text : Str -> Result PlatformDict _ #[BadKnownPlatformsCSV]_
get_platforms_from_csv_text = |platforms_text|
    platforms_text
    |> parse_platform_releases
    |> Result.map_err(|_| ParsingError)?
    |> build_platform_dict
    |> Ok

# Run updates
# ------------------------------------------------------------------------------

update_packages! : Str, Str => Result PackageDict [FileWriteError, GhAuthError, GhNotInstalled, ParsingError]
update_packages! = |packages_csv_text, repo_dir|
    parsed_packages = parse_known_packages(packages_csv_text) ? |_| ParsingError
    all_releases = List.walk_try!(
        parsed_packages,
        "",
        |releases, { repo, alias }|
            new_releases = 
                get_package_releases_cmd(repo, alias)
                |> cmd_output!
                |> get_gh_cmd_stdout?
                |> Str.from_utf8_lossy
            when new_releases is
                "" -> 
                    Ok(releases)
                _ ->
                    when parse_package_releases(new_releases) is
                        Ok(_) -> Ok(Str.join_with([releases, new_releases], ""))
                        _ -> Ok(releases),
    )?
    file_path = repo_dir |> Str.drop_suffix("/") |> Str.concat("/package-releases.csv")
    package_releases_header = "repo,alias,tag,url\n"
    all_releases |> Str.with_prefix(package_releases_header) |> write_utf8!(file_path) |> Result.map_err(|_| FileWriteError)?
    parse_package_releases(all_releases) ? |_| ParsingError
    |> build_package_dict
    |> Ok


update_platforms! : Str, Str => Result PlatformDict [FileWriteError, GhAuthError, GhNotInstalled, ParsingError]
update_platforms! = |platforms_csv_text, repo_dir|
    parsed_platforms = parse_known_platforms(platforms_csv_text) ? |_| ParsingError
    all_releases = List.walk_try!(
        parsed_platforms,
        "",
        |releases, { repo, alias, requires }|
            new_releases = 
                get_platform_releases_cmd(repo, alias, requires)
                |> cmd_output!
                |> get_gh_cmd_stdout?
                |> Str.from_utf8_lossy
            when new_releases is
                "" -> 
                    Ok(releases)
                _ ->
                    when parse_platform_releases(new_releases) is
                        Ok(_) -> Ok(Str.join_with([releases, new_releases], ""))
                        _ -> Ok(releases),
    )?
    file_path = repo_dir |> Str.drop_suffix("/") |> Str.concat("/platform-releases.csv")
    platform_releases_header = "repo,alias,requires,tag,url\n"
    all_releases |> Str.with_prefix(platform_releases_header) |> write_utf8!(file_path) |> Result.map_err(|_| FileWriteError)?
    parse_platform_releases(all_releases) ? |_| ParsingError
    |> build_platform_dict
    |> Ok

# GitHub API Commands
# ------------------------------------------------------------------------------

get_package_releases_cmd = |repo, alias|
    cmd_new("gh")
    |> cmd_args(["api", "repos/${repo}/releases?per_page=100", "--paginate", "--jq", ".[] | . as \$release | .assets[]? | select(.name|endswith(\".tar.br\")) | [\"${repo}\", \"${alias}\", \$release.tag_name, .browser_download_url] | @csv"])

get_platform_releases_cmd = |repo, alias, requires|
    cmd_new("gh")
    |> cmd_args(["api", "repos/${repo}/releases?per_page=100", "--paginate", "--jq", ".[] | . as \$release | .assets[]? | select(.name|endswith(\".tar.br\")) | [\"${repo}\", \"${alias}\", \"${requires}\", \$release.tag_name, .browser_download_url] | @csv"])

get_gh_cmd_stdout = |cmd_output|
    when cmd_output.status is
        Ok(0) -> Ok(cmd_output.stdout)
        Ok(4) -> Err(GhAuthError)
        Ok(_) -> Ok([])
        Err(_) -> Err(GhNotInstalled)

# Parse known packages
# ------------------------------------------------------------------------------

parse_known_packages = |csv_text|
    parser = parse_package_header_line |> rhs(one_or_more(parse_package_line)) |> lhs(maybe(whitespace))
    parser(csv_text) |> finalize |> Result.map_err(|_| BadKnownPackagesCSV)

parse_package_header_line = |line|
    parser = maybe(string("repo,alias") |> lhs(maybe(string(",")) |> lhs(string("\n"))))
    parser(line) |> Result.map_err(|_| MaybeShouldNotFail)

parse_package_line = |line|
    pattern =
        zip(
            csv_string |> lhs(string(",")),
            csv_string |> lhs(maybe(string(","))),
        )
        |> lhs(maybe(string("\n")))
    parser = pattern |> map(|(repo, alias)| Ok({ repo, alias }))
    parser(line) |> Result.map_err(|_| KnownPackagesLineNotFound)

# Parse known platforms
# ------------------------------------------------------------------------------

parse_known_platforms = |csv_text|
    parser = parse_platform_header_line |> rhs(one_or_more(parse_platform_line)) |> lhs(maybe(whitespace))
    parser(csv_text) |> finalize |> Result.map_err(|_| BadKnownPlatformsCSV)

parse_platform_header_line = |line|
    parser = maybe(string("repo,alias,requires") |> lhs(maybe(string(",")) |> lhs(string("\n"))))
    parser(line) |> Result.map_err(|_| MaybeShouldNotFail)

parse_platform_line = |line|
    pattern =
        zip_3(
            csv_string |> lhs(string(",")),
            csv_string |> lhs(string(",")),
            csv_string |> lhs(maybe(string(","))),
        )
        |> lhs(maybe(string("\n")))
    parser = pattern |> map(|(repo, alias, requires)| Ok({ repo, alias, requires }))
    parser(line) |> Result.map_err(|_| KnownPlatformsLineNotFound)

# Parse package releases
# ------------------------------------------------------------------------------

parse_package_releases : Str -> Result (List { repo : Str, alias : Str, tag : Str, url : Str }) [BadPackageReleasesCSV]
parse_package_releases = |csv_text|
    parser = parse_release_header_line |> rhs(one_or_more(parse_package_releases_line)) |> lhs(maybe(whitespace))
    parser(csv_text) |> finalize |> Result.map_err(|_| BadPackageReleasesCSV)

parse_release_header_line = |line|
    parser = maybe(string("repo,alias,tag,url") |> lhs(maybe(string(",")) |> lhs(string("\n"))))
    parser(line) |> Result.map_err(|_| MaybeShouldNotFail)

parse_package_releases_line = |line|
    pattern =
        zip_4(
            csv_string |> lhs(string(",")),
            csv_string |> lhs(string(",")),
            csv_string |> lhs(string(",")),
            csv_string |> lhs(maybe(string(","))),
        )
        |> lhs(maybe(string("\n")))
    parser = pattern |> map(|(repo, alias, tag, url)| Ok({ repo, alias, tag, url }))
    parser(line) |> Result.map_err(|_| PackageReleaseLineNotFound)

# Parse platform releases
# ------------------------------------------------------------------------------

parse_platform_releases = |csv_text|
    parser = parse_platform_releases_header_line |> rhs(one_or_more(parse_platform_releases_line)) |> lhs(maybe(whitespace))
    parser(csv_text) |> finalize |> Result.map_err(|_| BadPlatformReleasesCSV)

parse_platform_releases_header_line = |line|
    parser = maybe(string("repo,alias,requires,tag,url") |> lhs(maybe(string(",")) |> lhs(string("\n"))))
    parser(line) |> Result.map_err(|_| MaybeShouldNotFail)

parse_platform_releases_line = |line|
    pattern =
        zip_5(
            csv_string |> lhs(string(",")),
            csv_string |> lhs(string(",")),
            csv_string |> lhs(string(",")),
            csv_string |> lhs(string(",")),
            csv_string |> lhs(maybe(string(","))),
        )
        |> lhs(maybe(string("\n")))
    parser = pattern |> map(|(repo, alias, requires, tag, url)| Ok({ repo, alias, requires, tag, url }))
    parser(line) |> Result.map_err(|_| PlatformReleaseLineNotFound)

# Build dictionaries from csv data
# -----------------------------------------------------------------------------

build_package_dict : List { repo : Str, alias : Str, tag : Str, url : Str } -> PackageDict
build_package_dict = |package_list|
    List.walk(
        package_list,
        Dict.empty {},
        |dict, { repo, alias, tag, url }|
            when Dict.get(dict, repo) is
                Ok(releases) ->
                    Dict.insert(
                        dict,
                        repo,
                        List.append(releases, { repo, alias, tag, url, semver: semver_with_default(tag) })
                        |> List.sort_with(|{ semver: a }, { semver: b }| Semver.compare(b, a)),
                    )

                Err(KeyNotFound) ->
                    Dict.insert(dict, repo, [{ repo, alias, tag, url, semver: semver_with_default(tag) }]),
    )

build_platform_dict : List { repo : Str, alias : Str, requires : Str, tag : Str, url : Str } -> PlatformDict
build_platform_dict = |platform_list|
    List.walk(
        platform_list,
        Dict.empty {},
        |dict, { repo, alias, requires, tag, url }|
            when Dict.get(dict, repo) is
                Ok(releases) ->
                    Dict.insert(
                        dict,
                        repo,
                        List.append(releases, { repo, alias, requires, tag, url, semver: semver_with_default(tag) })
                    )

                Err(KeyNotFound) ->
                    Dict.insert(dict, repo, [{ repo, alias, requires, tag, url, semver: semver_with_default(tag) }]),
    )

semver_with_default = |s| Semver.parse(Str.drop_prefix(s, "v")) |> Result.with_default({ major: 0, minor: 0, patch: 0, pre_release: [s], build: [] })

# Dict Lookup
# ------------------------------------------------------------------------------

get_package_release : PackageDict, Str, Str -> Result PackageRelease [PackageNotFound, VersionNotFound, PackageNotFoundButMaybe(Str)]
get_package_release = |dict, repo, version|
    when Dict.get(dict, repo) is
        Ok(releases) ->
            if version == "latest" or version == "" then
                sorted = List.sort_with(releases, |{ semver: a }, { semver: b }| Semver.compare(a, b))
                release = List.last(sorted) ? |_| PackageNotFound
                Ok(release)
            else
                when Semver.parse(Str.drop_prefix(version, "v")) is
                    Ok(sv) ->
                        release = List.find_first(releases, |{ semver }| Semver.compare(semver, sv) == EQ) ? |_| VersionNotFound
                        Ok(release)

                    Err(_) ->
                        sorted = List.sort_with(releases, |{ semver: a }, { semver: b }| Semver.compare(a, b))
                        release = List.find_last(sorted, |{ tag }| tag == version) ? |_| VersionNotFound
                        Ok(release)

        Err(KeyNotFound) -> 
            when Str.split_first(repo, "/") is
                Ok({ before: owner, after: name }) ->
                    if !Str.starts_with(name, "roc-") and Dict.contains(dict, "${owner}/roc-${name}") then
                        Err(PackageNotFoundButMaybe("${owner}/roc-${name}"))
                    else
                        Err(PackageNotFound)
                
                Err(NotFound) -> Err(PackageNotFound)

get_platform_release : PlatformDict, Str, Str -> Result PlatformRelease [PlatformNotFound, VersionNotFound]
get_platform_release = |dict, repo, version|
    when Dict.get(dict, repo) is
        Ok(releases) ->
            if version == "latest" or version == "" then
                release = List.first(releases) ? |_| PlatformNotFound
                Ok(release)
            else
                when Semver.parse(Str.drop_prefix(version, "v")) is
                    Ok(sv) ->
                        release = List.find_first(releases, |{ semver }| Semver.compare(semver, sv) == EQ) ? |_| VersionNotFound
                        Ok(release)

                    Err(_) ->
                        release = List.find_first(releases, |{ tag }| tag == version) ? |_| VersionNotFound
                        Ok(release)

        Err(KeyNotFound) -> Err(PlatformNotFound)

RepoNameMap : Dict Str (List Str)

build_repo_name_map : List Str -> RepoNameMap
build_repo_name_map = |repos|
    List.walk(
        repos,
        Dict.empty {},
        |dict, repo|
            { before: owner, after: name } = Str.split_first(repo, "/") |> Result.with_default { before: repo, after: repo }
            when Dict.get(dict, name) is
                Ok(names) -> Dict.insert(dict, name, List.append(names, owner))
                Err(KeyNotFound) -> Dict.insert(dict, name, [owner]),
    )

get_full_repo_name : RepoNameMap, Str -> Result Str [NotFound, AmbiguousName, NotFoundButMaybe(Str)]
get_full_repo_name = |dict, name|
    if Str.contains(name, "/") then
        Ok(name)
    else
        when Dict.get(dict, name) is
            Ok([owner]) -> Ok("${owner}/${name}")
            Ok(_) -> Err(AmbiguousName)
            Err(KeyNotFound) -> 
                if !Str.starts_with(name, "roc-") then
                    if Dict.contains(dict, "roc-${name}") then
                        Err(NotFoundButMaybe("roc-${name}"))
                    else
                        Err(NotFound)
                else
                    Err(NotFound)