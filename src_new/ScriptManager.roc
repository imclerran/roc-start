module {
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
PlatformRelease : { repo : Str, alias : Str, requires : Str, tag : Str, url : Str, semver : Semver }

script_url : Str, Str -> Str
script_url = |repo, tag| 
    "https://raw.githubusercontent.com/imclerran/roc-repo/refs/heads/main/scripts/${repo}/${tag}.sh"

cache_scripts! : PlatformDict, Str => Result _ _
cache_scripts! = |platforms, cache_dir|
    create_all_dirs!(cache_dir)?
    List.for_each_try!(
        Dict.to_list(platforms),
        |(repo, releases)|
            List.for_each_try!(
                releases,
                |release|
                    url = script_url(repo, release.tag)
                    dir_no_slash = cache_dir |> Str.drop_suffix("/")
                    dir_path = "${dir_no_slash}/${repo}"
                    filename = "${release.tag}.sh"
                    download_script!(url, dir_path, filename)
            )
    )?
    cache_generic_script!(cache_dir)

cache_generic_script! = |cache_dir|
    filename = "generic.sh"
    url = "https://raw.githubusercontent.com/imclerran/roc-repo/refs/heads/main/scripts/${filename}"
    download_script!(url, cache_dir, filename)
    

download_script! = |url, dir_path, filename|
    req = {
        method: GET,
        headers: [],
        uri : url,
        body: [],
        timeout_ms: NoTimeout,
    }
    resp = http_send!(req)?
    if resp.status != 200 then
        Ok({})
    else
        text = resp.body |> Str.from_utf8_lossy
        create_all_dirs!("${dir_path}")?
        file_path = "${dir_path}/${filename}"
        _ = file_write_utf8!(text, file_path)
        Ok({})

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
    ) |> Result.map_err(|_| NoMatch) |> Result.map_ok(.0)

semver_with_default = |s| Semver.parse(Str.drop_prefix(s, "v")) |> Result.with_default({ major: 0, minor: 0, patch: 0, pre_release: [s], build: [] })

get_available_scripts! : Str, Str => (List Str)
get_available_scripts! = |cache_dir, repo|
    list_dir!("${cache_dir}/${repo}") 
    |> Result.with_default([])
    |> List.map(|path| 
        f = path_to_str(path)
        Str.split_last(f, "/") 
        |> Result.map_ok(|{ after }| after)
        |> Result.with_default(f)
    )
    |> List.keep_if(|f| Str.ends_with(f, ".sh"))