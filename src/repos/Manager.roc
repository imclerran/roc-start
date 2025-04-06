module [
    RepositoryRelease,
    RepositoryDict,
    RepositoryReleaseSerialized,
    RepoNameMap,
    get_repos_from_json_bytes,
    get_repo_release,
    build_repo_name_map,
    get_full_repo_name,
]

import json.Json
import semver.Semver
import semver.Types exposing [Semver]

RepositoryDict : Dict Str (List RepositoryRelease)
RepositoryRelease : { repo : Str, alias : Str, tag : Str, url : Str, semver : Semver }
RepositoryReleaseSerialized : { repo : Str, alias : Str, tag : Str, url : Str }

# Get packages and platforms from csv text
# ------------------------------------------------------------------------------

get_repos_from_json_bytes : List U8 -> Result RepositoryDict [BadRepoReleasesData]
get_repos_from_json_bytes = |bytes|
    decode_repo_releases(bytes)?
    |> build_repo_dict
    |> Ok

# decode releases
# ------------------------------------------------------------------------------

decode_repo_releases : List U8 -> Result (List RepositoryReleaseSerialized) [BadRepoReleasesData]
decode_repo_releases = |bytes|
    decoder = Json.utf8_with({ field_name_mapping: SnakeCase })
    decoded : Decode.DecodeResult (List RepositoryReleaseSerialized)
    decoded = Decode.from_bytes_partial(bytes, decoder)
    decoded.result |> Result.map_err(|_| BadRepoReleasesData)

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

get_repo_release : RepositoryDict, Str, Str, [Package, Platform] -> Result RepositoryRelease [RepoNotFound, VersionNotFound, RepoNotFoundButMaybe Str]
get_repo_release = |dict, repo, version, type|
    when type is
        Package -> get_repo_release_help(dict, repo, version, "roc-")
        Platform -> get_repo_release_help(dict, repo, version, "basic-")

get_repo_release_help : RepositoryDict, Str, Str, Str -> Result RepositoryRelease [RepoNotFound, VersionNotFound, RepoNotFoundButMaybe Str]
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

build_repo_name_map : List Str -> Dict Str (List Str)
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
