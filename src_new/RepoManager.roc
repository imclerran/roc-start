module { write_utf8!, cmd_output!, cmd_new, cmd_args } -> [
    PackageDict,
    PlatformDict,
    update_local_repos!,
    get_packages_from_csv_text,
    get_platforms_from_csv_text,
    get_repo_release,
    build_repo_name_map,
    get_full_repo_name,
]

import parse.CSV exposing [csv_string]
import parse.Parse exposing [one_or_more, maybe, string, lhs, rhs, map, zip, zip_4, whitespace, finalize]
import semver.Semver
import semver.Types exposing [Semver]

RepositoryDict : Dict Str (List RepositoryRelease)
RepositoryRelease : { repo : Str, alias : Str, tag : Str, url : Str, semver : Semver }
RepositoryReleaseSerialized : { repo : Str, alias : Str, tag : Str, url : Str }

PackageDict : Dict Str (List PackageRelease)
PackageRelease : { repo : Str, alias : Str, tag : Str, url : Str, semver : Semver }
PlatformDict : Dict Str (List PlatformRelease)
PlatformRelease : { repo : Str, alias : Str, tag : Str, url : Str, semver : Semver }

# Get packages and platforms from local or remote
# ------------------------------------------------------------------------------

# Get packages and platforms from csv text
# ------------------------------------------------------------------------------

get_packages_from_csv_text : Str -> Result PackageDict [ParsingError]
get_packages_from_csv_text = |packages_text|
    packages_text
    |> parse_repo_releases
    |> Result.map_err(|_| ParsingError)?
    |> build_repo_dict
    |> Ok

get_platforms_from_csv_text : Str -> Result PlatformDict [ParsingError]
get_platforms_from_csv_text = |platforms_text|
    platforms_text
    |> parse_repo_releases
    |> Result.map_err(|_| ParsingError)?
    |> build_repo_dict
    |> Ok

# Run updates
# ------------------------------------------------------------------------------

update_local_repos! : Str, Str => Result RepositoryDict [FileWriteError, GhAuthError, GhNotInstalled, ParsingError]
update_local_repos! = |known_repos_csv_text, save_path|
    parsed_repos = parse_known_repos(known_repos_csv_text) ? |_| ParsingError
    { releases_str: all_releases, releases: release_list } = List.walk_try!(
        parsed_repos,
        { releases_str: "", releases: [] },
        |{ releases_str, releases }, { repo, alias }|
            new_releases_str =
                get_releases_cmd(repo, alias)
                |> cmd_output!
                |> get_gh_cmd_stdout?
                |> Str.from_utf8_lossy
            when new_releases_str is
                "" ->
                    Ok({ releases_str, releases }) 
                _ ->
                    when parse_repo_releases(new_releases_str) is
                        Ok(new_releases) ->
                            Ok(
                                {
                                    releases_str: Str.join_with([releases_str, new_releases_str], ""),
                                    releases: List.join([releases, new_releases]),
                                }
                            )
                        _ -> Ok({ releases_str, releases }),
    )?
    release_header = "repo,alias,tag,url\n"
    all_releases
    |> Str.with_prefix(release_header)
    |> write_utf8!(save_path)
    |> Result.map_err(|_| FileWriteError)?
    release_list
    |> build_repo_dict
    |> Ok

# GitHub API Commands
# ------------------------------------------------------------------------------

get_releases_cmd = |repo, alias|
    cmd_new("gh")
    |> cmd_args(["api", "repos/${repo}/releases?per_page=100", "--paginate", "--jq", ".[] | . as \$release | .assets[]? | select(.name|(endswith(\".tar.br\") or endswith(\".tar.gz\"))) | [\"${repo}\", \"${alias}\", \$release.tag_name, .browser_download_url] | @csv"])

get_gh_cmd_stdout = |cmd_output|
    when cmd_output.status is
        Ok(0) -> Ok(cmd_output.stdout)
        Ok(4) -> Err(GhAuthError)
        Ok(_) -> Ok([])
        Err(_) -> Err(GhNotInstalled)

# Parse known repositories csv
# ------------------------------------------------------------------------------

parse_known_repos = |csv_text|
    parser = parse_known_repos_header |> rhs(one_or_more(parse_known_repos_line)) |> lhs(maybe(whitespace))
    parser(csv_text) |> finalize |> Result.map_err(|_| BadKnownReposCSV)

parse_known_repos_header = |line|
    parser = maybe(string("repo,alias") |> lhs(maybe(string(",")) |> lhs(string("\n"))))
    parser(line) |> Result.map_err(|_| MaybeShouldNotFail)

parse_known_repos_line = |line|
    pattern =
        zip(
            csv_string |> lhs(string(",")),
            csv_string |> lhs(maybe(string(","))),
        )
        |> lhs(maybe(string("\n")))
    parser = pattern |> map(|(repo, alias)| Ok({ repo, alias }))
    parser(line) |> Result.map_err(|_| KnownReposLineNotFound)


# Parse package releases
# ------------------------------------------------------------------------------

parse_repo_releases : Str -> Result (List { repo : Str, alias : Str, tag : Str, url : Str }) [BadRepoReleasesCSV]
parse_repo_releases = |csv_text|
    parser = parse_repo_release_header |> rhs(one_or_more(parse_repo_releases_line)) |> lhs(maybe(whitespace))
    parser(csv_text) |> finalize |> Result.map_err(|_| BadRepoReleasesCSV)

parse_repo_release_header = |line|
    parser = maybe(string("repo,alias,tag,url") |> lhs(maybe(string(",")) |> lhs(string("\n"))))
    parser(line) |> Result.map_err(|_| MaybeShouldNotFail)

parse_repo_releases_line = |line|
    pattern =
        zip_4(
            csv_string |> lhs(string(",")),
            csv_string |> lhs(string(",")),
            csv_string |> lhs(string(",")),
            csv_string |> lhs(maybe(string(","))),
        )
        |> lhs(maybe(string("\n")))
    parser = pattern |> map(|(repo, alias, tag, url)| Ok({ repo, alias, tag, url }))
    parser(line) |> Result.map_err(|_| RepoReleaseLineNotFound)

# Build dictionaries from csv data
# -----------------------------------------------------------------------------

build_repo_dict : List RepositoryReleaseSerialized -> RepositoryDict
build_repo_dict = |repo_list|
    List.walk(
        repo_list,
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

semver_with_default = |s| Semver.parse(Str.drop_prefix(s, "v")) |> Result.with_default({ major: 0, minor: 0, patch: 0, pre_release: [s], build: [] })

# Release Lookup
# -----------------------------------------------------------------------------

get_repo_release : RepositoryDict, Str, Str, [Package, Platform] -> Result RepositoryRelease [RepoNotFound, VersionNotFound, RepoNotFoundButMaybe(Str)]
get_repo_release = |dict, repo, version, type|
    when type is
        Package -> get_repo_release_help(dict, repo, version, "roc-")
        Platform -> get_repo_release_help(dict, repo, version, "basic-")

get_repo_release_help : RepositoryDict, Str, Str, Str -> Result RepositoryRelease [RepoNotFound, VersionNotFound, RepoNotFoundButMaybe(Str)]
get_repo_release_help = |dict, repo, version, try_prefix|
    when Dict.get(dict, repo) is
        Ok(releases) ->
            if version == "latest" or version == "" then
                sorted = List.sort_with(releases, |{ semver: a }, { semver: b }| Semver.compare(a, b))
                release = List.last(sorted) ? |_| RepoNotFound
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
                    if !Str.starts_with(name, try_prefix) and Dict.contains(dict, "${owner}/${try_prefix}${name}") then
                        Err(RepoNotFoundButMaybe("${owner}/${try_prefix}${name}"))
                    else
                        Err(RepoNotFound)

                Err(NotFound) -> Err(RepoNotFound)


# Repository onwer/name lookup
# -----------------------------------------------------------------------------

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

get_full_repo_name : RepoNameMap, Str, [Package, Platform] -> Result Str [RepoNotFound, AmbiguousName, RepoNotFoundButMaybe Str]
get_full_repo_name = |dict, name, type|
    when type is
        Package -> get_full_repo_name_help(dict, name, "roc-")
        Platform -> get_full_repo_name_help(dict, name, "basic-")

get_full_repo_name_help = |dict, name, try_prefix|
    if Str.contains(name, "/") then
        Ok(name)
    else
        when Dict.get(dict, name) is
            Ok([owner]) -> Ok("${owner}/${name}")
            Ok(_) -> Err(AmbiguousName)
            Err(KeyNotFound) ->
                if !Str.starts_with(name, try_prefix) then
                    if Dict.contains(dict, "${try_prefix}${name}") then
                        Err(RepoNotFoundButMaybe("${try_prefix}${name}"))
                    else
                        Err(RepoNotFound)
                else
                    Err(RepoNotFound)