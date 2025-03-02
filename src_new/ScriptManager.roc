module
    {
        http_send!,
        file_write_utf8!,
        create_all_dirs!,
        list_dir!,
        path_to_str,
    } -> [
        cache_scripts!,
        choose_script,
        get_available_scripts!,
    ]

import semver.Types exposing [Semver]
import semver.Semver

PlatformDict : Dict Str (List PlatformRelease)
PlatformRelease : { repo : Str, alias : Str, tag : Str, url : Str, semver : Semver }

# Downloading and caching
# -----------------------------------------------------------------------------

script_url : Str, Str -> Str
script_url = |repo, tag|
    "https://raw.githubusercontent.com/imclerran/roc-repo/refs/heads/main/scripts/${repo}/${tag}.sh"

cache_scripts! : PlatformDict, Str, (Str => {}) => Result _ _
cache_scripts! = |platforms, cache_dir, logger!|
    create_all_dirs!(cache_dir)?
    release_list =
        Dict.to_list(platforms)
        |> List.map(|(_, rs)| rs)
        |> List.join
    num_releases = List.len(release_list)
    logger!(" [")
    logger!(Str.repeat("=", Num.sub_saturated(5, num_releases)))
    _ = List.walk_try!(
        release_list,
        (0, 0),
        |(n, last_fifth), release|
            next_n = n + 1
            current_fifth = Num.div_trunc(next_n * 5, num_releases)
            next_fifth = if current_fifth > last_fifth then current_fifth else last_fifth
            url = script_url(release.repo, release.tag)
            dir_no_slash = cache_dir |> Str.drop_suffix("/")
            dir_path = "${dir_no_slash}/${release.repo}"
            filename = "${release.tag}.sh"
            download_script!(url, dir_path, filename)?
            if current_fifth > last_fifth then logger!("=") else {}
            Ok((next_n, next_fifth)),
    )
    # _ = List.walk_try!(
    #     Dict.to_list(platforms),
    #     (0, 0),
    #     |(n, n2), (repo, releases)|
    #         List.for_each_try!(
    #             releases,
    #             |release|
    #                 url = script_url(repo, release.tag)
    #                 dir_no_slash = cache_dir |> Str.drop_suffix("/")
    #                 dir_path = "${dir_no_slash}/${repo}"
    #                 filename = "${release.tag}.sh"
    #                 download_script!(url, dir_path, filename, logger!)
    #                 Ok((0, 0)),
    #         ),
    # )
    logger!("] ") |> Ok

download_script! : Str, Str, Str => Result {} [FileWriteError, NetworkError]
download_script! = |url, dir_path, filename|
    req = {
        method: GET,
        headers: [],
        uri: url,
        body: [],
        timeout_ms: NoTimeout,
    }
    resp = http_send!(req) ? |_| NetworkError
    if resp.status != 200 then
        Ok({})
    else
        text = resp.body |> Str.from_utf8_lossy
        create_all_dirs!("${dir_path}") ? |_| FileWriteError
        file_path = "${dir_path}/${filename}"
        file_write_utf8!(text, file_path) |> Result.map_err(|_| FileWriteError)

# Script selection
# -----------------------------------------------------------------------------

choose_script : Str, List Str -> Result Str [NoMatch]
choose_script = |tag, scripts|
    tag_sv = semver_with_default(tag)
    script_svs =
        scripts
        |> List.map(|script| (script, semver_with_default(Str.drop_suffix(script, ".sh"))))
        |> List.sort_with(|(_, sv1), (_, sv2)| Semver.compare(sv2, sv1))
    List.find_first(
        script_svs,
        |(_tag, sv)|
            when Semver.compare(tag_sv, sv) is
                GT | EQ -> Bool.true
                _ -> Bool.false,
    )
    |> Result.map_err(|_| NoMatch)
    |> Result.map_ok(.0)

semver_with_default = |s| Semver.parse(Str.drop_prefix(s, "v")) |> Result.with_default({ major: 0, minor: 0, patch: 0, pre_release: [s], build: [] })

get_available_scripts! : Str, Str => List Str
get_available_scripts! = |cache_dir, repo|
    list_dir!("${cache_dir}/${repo}")
    |> Result.with_default([])
    |> List.map(
        |path|
            f = path_to_str(path)
            Str.split_last(f, "/")
            |> Result.map_ok(|{ after }| after)
            |> Result.with_default(f),
    )
    |> List.keep_if(|f| Str.ends_with(f, ".sh"))
