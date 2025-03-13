module { write_bytes!, cmd_output!, cmd_new, cmd_args } -> [
    update_local_repos!,
]

import json.Json
import parse.CSV exposing [csv_string]
import parse.Parse exposing [one_or_more, maybe, string, lhs, rhs, map, zip_3, zip_4, whitespace, finalize]
import semver.Semver

import RepoManager exposing [RepositoryDict, RepositoryReleaseSerialized]

# Run updates
# ------------------------------------------------------------------------------

update_local_repos! : Str, Str, (Str => {}) => Result RepositoryDict [FileWriteError, GhAuthError, GhNotInstalled, ParsingError]
update_local_repos! = |known_repos_csv_text, save_path, logger!|
    parsed_repos = parse_known_repos(known_repos_csv_text) ? |_| ParsingError
    num_repos = List.len(parsed_repos)
    logger!("[")
    logger!(Str.repeat("=", Num.sub_saturated(5, num_repos)))
    release_list =
        List.walk_try!(
            parsed_repos,
            ([], 0, 0),
            |(releases, n, last_fifth), { repo, alias }|
                next_n = n + 1
                current_fifth = (next_n * 5) // num_repos
                next_fifth = if current_fifth > last_fifth then current_fifth else last_fifth
                new_releases_str =
                    get_releases_cmd(repo, alias)
                    |> cmd_output!
                    |> get_gh_cmd_stdout?
                    |> Str.from_utf8_lossy
                if current_fifth > last_fifth then logger!("=") else {}
                when new_releases_str is
                    "" ->
                        Ok((releases, next_n, next_fifth))

                    _ ->
                        when parse_repo_releases(new_releases_str) is
                            Ok(new_releases) ->
                                Ok((List.join([releases, new_releases]), next_n, next_fifth))

                            _ -> Ok((releases, next_n, next_fifth)),
        )?
        |> .0
    logger!("] ")
    save_repo_releases!(release_list, save_path)?
    release_list
    |> build_repo_dict
    |> Ok

save_repo_releases! : List RepositoryReleaseSerialized, Str => Result {} [FileWriteError]
save_repo_releases! = |releases, save_path|
    releases
    |> encode_repo_releases
    |> write_bytes!(save_path)
    |> Result.map_err(|_| FileWriteError)

# GitHub API Commands
# ------------------------------------------------------------------------------

get_releases_cmd = |repo, alias|
    cmd_new("gh")
    |> cmd_args(["api", "repos/${repo}/releases?per_page=100", "--paginate", "--jq", ".[] | . as \$release | .assets[]? | select(.name|(endswith(\".tar.br\") or endswith(\".tar.gz\"))) | select(.name | (contains(\"docs\") or contains(\"Source code\")) | not) | [\"${repo}\", \"${alias}\", \$release.tag_name, .browser_download_url] | @csv"])

get_gh_cmd_stdout = |cmd_output|
    when cmd_output.status is
        Ok(0) -> Ok(cmd_output.stdout)
        Ok(4) -> Err(GhAuthError)
        Ok(_) -> Ok([])
        Err(_) -> 
            if(cmd_output.stderr |> Str.from_utf8_lossy |> Str.contains("gh auth login")) then 
                Err(GhNotInstalled)
            else
                Err(GhNotInstalled)

# Parse known repositories csv
# ------------------------------------------------------------------------------

parse_known_repos = |csv_text|
    parser = parse_known_repos_header |> rhs(one_or_more(parse_known_repos_line)) |> lhs(maybe(whitespace))
    parser(csv_text) |> finalize |> Result.map_err(|_| BadKnownReposCSV)

parse_known_repos_header = |line|
    parser = maybe(string("repo,alias,remote") |> lhs(maybe(string(",")) |> lhs(string("\n"))))
    parser(line) |> Result.map_err(|_| MaybeShouldNotFail)

parse_known_repos_line = |line|
    pattern =
        zip_3(
            csv_string |> lhs(string(",")),
            csv_string |> lhs(string(",")),
            string("github") |> lhs(maybe(string(","))),
        )
        |> lhs(maybe(string("\n")))
    parser = pattern |> map(|(repo, alias, _remote)| Ok({ repo, alias }))
    parser(line) |> Result.map_err(|_| KnownReposLineNotFound)

# encode and decode releases
# ------------------------------------------------------------------------------

encode_repo_releases : List RepositoryReleaseSerialized -> List U8
encode_repo_releases = |releases|
    encoder = Json.utf8_with({ field_name_mapping: SnakeCase })
    Encode.to_bytes(releases, encoder)

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
