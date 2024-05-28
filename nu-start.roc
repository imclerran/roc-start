app [main] {
    pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.10.0/vNe6s9hWzoTZtFmNkvEICPErI9ptji_ySjicO6CkucY.tar.br",
    weaver: "https://github.com/smores56/weaver/releases/download/0.2.0/BBDPvzgGrYp-AhIDw0qmwxT0pWZIQP_7KOrUrZfp_xw.tar.br",
    rvn: "https://github.com/jwoudenberg/rvn/releases/download/0.1.0/2d2PF4kq9UUum9YpQH7k9iFIJ4hffWXQVCi0GJJweiU.tar.br",
    json: "https://github.com/lukewilliamboswell/roc-json/releases/download/0.10.0/KbIfTNbxShRX1A1FgXei1SpO5Jn8sgP6HP6PXbi-xyA.tar.br",
}

import ArgParser
import pf.Arg
import pf.Cmd
import pf.File
import pf.Path
import pf.Stdout
import pf.Task exposing [Task]
import json.Json
import rvn.Rvn
import weaver.Cli
import weaver.Opt
import weaver.Param
import "repos/pkg-repos.rvn" as pkgRepos : List U8
import "repos/pf-repos.rvn" as pfRepos : List U8

main =
    when Cli.parseOrDisplayMessage cliParser Arg.list! is
        Ok data ->
            startOrUpdate data

        Err message ->
            Stdout.line! message
            Task.err (Exit 1 "")

cliParser =
    Cli.weave {
        update: <- Opt.flag { short: "u", help: "Update the platform and package repositories." },
        appName: <- Param.maybeStr { name: "app-name", help: "Name your new roc app." },
        platform: <- Param.maybeStr { name: "platform", help: "The platform to use." },
        packages: <- Param.strList { name: "files", help: "Any packages to use." },
    }
    |> Cli.finish {
        name: "roc-start",
        version: "v0.0.0",
        authors: ["Ian McLerran <imclerran@protonmail.com>"],
        description: "A simple CLI tool for starting a new roc project. Specify your platform and packages by name, and roc-start will create a new .roc file with the latest releases.",
    }
    |> Cli.assertValid

loadRepositories =
    runUpdateIfNecessary!
    packageBytes = File.readBytes! (Path.fromStr "pkg-data.rvn")
    platformBytes = File.readBytes! (Path.fromStr "pf-data.rvn")
    packages = getPackageRepo packageBytes
    platforms = getPlatformRepo platformBytes
    Task.ok { packages, platforms }

checkForFile = \filename ->
    Path.isFile (Path.fromStr filename)
        |> Task.attempt! \res ->
            when res is
                Ok bool -> Task.ok bool
                _ -> Task.ok Bool.false

runUpdateIfNecessary =
    pkgsExists <- checkForFile "pkg-data.rvn" |> Task.await
    pfsExists <- checkForFile "pf-data.rvn" |> Task.await
    if !pkgsExists || !pfsExists then
        updatePackageData!
        updatePlatformData
    # compiler bug prevents this from working:
    # if !pfsExists && !pkgsExists then
    #     updatePackageData!
    #     updatePlatformData
    # else if !pfsExists then
    #     updatePlatformData
    # else if !pkgsExists then
    #     updatePackageData
    else
        Task.ok {}

updatePackageData =
    pkgRvnStr = Task.loop! { repositoryList: getPackageList, rvnDataStr: "[\n" } reposToRvnStrLoop
    File.writeBytes! (Path.fromStr "pkg-data.rvn") (pkgRvnStr |> Str.toUtf8)
    Stdout.line "Package data updated."

updatePlatformData =
    pfRvnStr = Task.loop! { repositoryList: getPlatformList, rvnDataStr: "[\n" } reposToRvnStrLoop
    File.writeBytes! (Path.fromStr "pf-data.rvn") (pfRvnStr |> Str.toUtf8)
    Stdout.line "Platform data updated."

getPackageList : List (Str, Str, Str)
getPackageList =
    when Decode.fromBytes pkgRepos Rvn.pretty is
        Ok repos -> repos
        Err _ -> []
    
getPlatformList : List (Str, Str, Str)
getPlatformList =
    when Decode.fromBytes pfRepos Rvn.pretty is
        Ok repos -> repos
        Err _ -> []

RepositoryLoopState : { repositoryList : List RepositoryData, rvnDataStr: Str }
RepositoryData : (Str, Str, Str)

reposToRvnStrLoop : RepositoryLoopState -> Task [Step RepositoryLoopState, Done Str] _
reposToRvnStrLoop = \{ repositoryList, rvnDataStr } ->
    when List.get repositoryList 0 is
        Ok (shortName, user, repo) ->
            updatedList = List.dropFirst repositoryList 1
            response = getLatestRelease! "$(user)/$(repo)"
            releaseData = responseToReleaseData response
            when releaseData is
                Ok { tagName, browserDownloadUrl } ->
                    updatedStr = Str.concat rvnDataStr (repoDataToRvnEntry repo shortName tagName browserDownloadUrl)
                    Task.ok (Step { repositoryList: updatedList, rvnDataStr: updatedStr })
                Err _ -> Task.ok (Step { repositoryList: updatedList, rvnDataStr })
        Err OutOfBounds -> Task.ok (Done (Str.concat rvnDataStr "]"))

getLatestRelease = \ownerSlashRepo ->
    Cmd.new "gh"
    |> Cmd.arg "api"
    |> Cmd.arg "-H"
    |> Cmd.arg "Accept: application/vnd.github+json"
    |> Cmd.arg "-H"
    |> Cmd.arg "X-GitHub-Api-Version: 2022-11-28"
    |> Cmd.arg "/repos/$(ownerSlashRepo)/releases/latest"
    |> Cmd.output
    |> Task.onErr! \_ -> Task.ok { stdout: [], stderr: []}

responseToReleaseData = \response ->
    jsonResponse = Decode.fromBytes response.stdout (Json.utf8With { fieldNameMapping: SnakeCase })
    when jsonResponse is
        Ok { tagName, assets } ->
            when assets |> List.keepIf isTarBr |>List.first  is
                Ok { browserDownloadUrl } -> Ok { tagName, browserDownloadUrl }
                Err ListWasEmpty -> Err NoAssetsFound

        Err _ -> Err ParsingError

isTarBr = \{ browserDownloadUrl } -> Str.endsWith browserDownloadUrl ".tar.br"

repoDataToRvnEntry = \repo, shortName, tagName, browserDownloadUrl ->
    """
        ("$(repo)", "$(shortName)", "$(tagName)", "$(browserDownloadUrl)"),\n
    """

RepositoryEntry : { shortName : Str, version : Str, url : Str }

getPackageRepo : List U8 -> Dict Str RepositoryEntry
getPackageRepo = \packageBytes ->
    res =
        Decode.fromBytes packageBytes Rvn.pretty
        |> Result.map \packageList ->
            packageList
            |> List.walk (Dict.empty {}) \dict, (name, shortName, version, url) ->
                Dict.insert dict name { shortName, version, url }
    when res is
        Ok dict -> dict
        Err _ -> Dict.empty {}

getPlatformRepo : List U8 -> Dict Str RepositoryEntry
getPlatformRepo = \platformBytes ->
    res =
        Decode.fromBytes platformBytes Rvn.pretty
        |> Result.map \packageList ->
            packageList
            |> List.walk (Dict.empty {}) \dict, (name, shortName, version, url) ->
                Dict.insert dict name { shortName, version, url }
    when res is
        Ok dict -> dict
        Err _ -> Dict.empty {}

startOrUpdate = \argData ->
    if argData.update then
        updatePackageData!
        updatePlatformData!
    else
        when (argData.appName, argData.platform) is
            (Ok appName, Ok platform) ->
                repos = loadRepositories!
                File.writeBytes! (Path.fromStr "$(appName).roc") (buildRocFile platform argData.packages repos)
                Stdout.line! "Created $(appName).roc"

            (Ok _appName, Err NoValue) -> Stdout.line! "Invalid arguments: no platform specified."
            _ -> Stdout.line! "Invalid arguments: No app name specified."

buildRocFile = \platform, packageList, repos ->
    pfStr =
        when Dict.get repos.platforms platform is
            Ok pf -> "    $(pf.shortName): platform \"$(pf.url)\",\n"
            Err KeyNotFound -> crash "Invalid platform: $(platform)"
    pkgsStr =
        List.walk packageList "" \str, package ->
            when Dict.get repos.packages package is
                Ok pkg -> Str.concat str "    $(pkg.shortName): \"$(pkg.url)\",\n"
                Err KeyNotFound -> ""
    "app [main] {\n$(pfStr)$(pkgsStr)}\n" |> Str.toUtf8
