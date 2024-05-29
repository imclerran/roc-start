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
import "repos/pkg-repos.rvn" as pkgRepos : List U8
import "repos/pf-repos.rvn" as pfRepos : List U8

main =
    when ArgParser.parseOrDisplayMessage Arg.list! is
        Ok data ->
            run data

        Err message ->
            Stdout.line! message
            Task.err (Exit 1 "")

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

RepositoryLoopState : { repositoryList : List RepositoryData, rvnDataStr : Str }
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
        |> Task.onErr! \_ -> Task.ok { stdout: [], stderr: [] }

responseToReleaseData = \response ->
    jsonResponse = Decode.fromBytes response.stdout (Json.utf8With { fieldNameMapping: SnakeCase })
    when jsonResponse is
        Ok { tagName, assets } ->
            when assets |> List.keepIf isTarBr |> List.first is
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

run = \argData ->
    when argData.subcommand is
        Ok (Update {}) ->
            Stdout.write! "" # avoid compiler bug -- indefinite hang without this line
            updatePackageData!
            updatePlatformData

        Ok (Config { file, delete }) ->
            when file is
                Ok filename ->
                    createFromConfig filename delete
                Err NoValue ->
                    createFromConfig "config.rvn" delete

        Err NoSubcommand ->
            when (argData.appName, argData.platform) is
                (Ok appName, Ok platform) ->
                    {} <- createRocFile appName platform argData.packages |> Task.await
                    Stdout.line "Created $(appName).roc"

                (Ok _appName, Err NoValue) ->
                    Stdout.line "Invalid arguments: no platform specified."

                _ ->
                    Stdout.line "Invalid arguments: No app name specified."

createFromConfig = \filename, doDelete ->
    createConfigIfNone! filename
    configuration = readConfig! filename
    createRocFile! configuration.appName configuration.platform configuration.packages
    Stdout.line! "Created $(configuration.appName).roc"
    if doDelete then
        File.delete (Path.fromStr filename)
    else
        Task.ok {}

createConfigIfNone = \filename ->
    if !(checkForFile! filename) then
        File.writeUtf8! (Path.fromStr filename) configTemplate
        Cmd.exec "nano" [filename]
    else
        Task.ok {}

configTemplate =
    """
    {
        appName: "new-app",
        platform: "basic-cli",
        packages: [], # packages list may be empty
    }
    """

readConfig = \filename ->
    configBytes = File.readBytes! (Path.fromStr filename)
    when Decode.fromBytes configBytes Rvn.pretty is
        Ok config -> Task.ok config
        Err _ -> Task.ok { platform: "", packages: [], appName: "" }

createRocFile = \appName, platform, packageList ->
    repos <- loadRepositories |> Task.await
    File.writeBytes (Path.fromStr "$(appName).roc") (buildRocFile platform packageList repos)

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
