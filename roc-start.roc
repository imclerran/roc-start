app [main] {
    pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.11.0/SY4WWMhWQ9NvQgvIthcv15AUeA7rAIJHAHgiaSHGhdY.tar.br",
    weaver: "https://github.com/smores56/weaver/releases/download/0.2.0/BBDPvzgGrYp-AhIDw0qmwxT0pWZIQP_7KOrUrZfp_xw.tar.br",
    rvn: "https://github.com/jwoudenberg/rvn/releases/download/0.1.0/2d2PF4kq9UUum9YpQH7k9iFIJ4hffWXQVCi0GJJweiU.tar.br",
    json: "https://github.com/lukewilliamboswell/roc-json/releases/download/0.10.0/KbIfTNbxShRX1A1FgXei1SpO5Jn8sgP6HP6PXbi-xyA.tar.br",
}

import ArgParser
import pf.Arg
import pf.Cmd
import pf.Dir
import pf.Env
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
        Ok args ->
            runWith args

        Err message ->
            Stdout.line! message
            Task.err (Exit 1 "")

runWith = \args ->
    when args.subcommand is
        Ok (Update {}) ->
            Stdout.write! ""
            # ^ avoid compiler bug -- indefinite hang without this line
            updatePackageData!
            updatePlatformData

        Ok (Config { file, delete }) ->
            when file is
                Ok filename ->
                    createFromConfig filename delete

                Err NoValue ->
                    createFromConfig "config.rvn" delete

        Err NoSubcommand ->
            when (args.appName, args.platform) is
                (Ok appName, Ok platform) ->
                    {} <- createRocFile appName platform args.packages |> Task.await
                    Stdout.line "Created $(appName).roc"

                _ ->
                    {} <- Stdout.line "App name and platform arguments are required.\n" |> Task.await
                    Stdout.line ArgParser.baseUsage

loadRepositories =
    dataDir = getAndCreateDataDir!
    runUpdateIfNecessary! dataDir
    packageBytes = File.readBytes! "$(dataDir)/pkg-data.rvn"
    platformBytes = File.readBytes! "$(dataDir)/pf-data.rvn"
    packages = getPackageRepo packageBytes
    platforms = getPlatformRepo platformBytes
    Task.ok { packages, platforms }

checkForFile = \filename ->
    Path.isFile (Path.fromStr filename)
        |> Task.attempt! \res ->
            when res is
                Ok bool -> Task.ok bool
                _ -> Task.ok Bool.false

checkForDir = \path ->
    Path.isDir (Path.fromStr path)
        |> Task.attempt! \res ->
            when res is
                Ok bool -> Task.ok bool
                _ -> Task.ok Bool.false

getAndCreateDataDir =
    home = Env.var! "HOME"
    dataDir = "$(home)/.roc-start"
    if checkForDir! dataDir then
        Task.ok dataDir
    else
        Dir.create! dataDir
        Task.ok dataDir

runUpdateIfNecessary = \dataDir ->
    # dataDir = getAndCreateDataDir! # compiler bug prevents this from working
    pkgsExists <- checkForFile "$(dataDir)/pkg-data.rvn" |> Task.await
    pfsExists <- checkForFile "$(dataDir)/pf-data.rvn" |> Task.await
    if !pkgsExists || !pfsExists then
        Stdout.line! "Updating package data..."
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
    dataDir = getAndCreateDataDir!
    pkgRvnStr = Task.loop! { repositoryList: getPackageRepoList, rvnDataStr: "[\n" } reposToRvnStrLoop
    File.writeBytes! "$(dataDir)/pkg-data.rvn" (pkgRvnStr |> Str.toUtf8)
    Stdout.line "Package data updated."

updatePlatformData =
    dataDir = getAndCreateDataDir!
    pfRvnStr = Task.loop! { repositoryList: getPlatformRepoList, rvnDataStr: "[\n" } reposToRvnStrLoop
    File.writeBytes! "$(dataDir)/pf-data.rvn" (pfRvnStr |> Str.toUtf8)
    Stdout.line "Platform data updated."

getPackageRepoList : List (Str, Str, Str)
getPackageRepoList =
    when Decode.fromBytes pkgRepos Rvn.pretty is
        Ok repos -> repos
        Err _ -> []

getPlatformRepoList : List (Str, Str, Str)
getPlatformRepoList =
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

# ==================================
# ==== CONFIG RELATED FUNCTIONS ====
# ==================================

createFromConfig = \filename, doDelete ->
    createConfigIfNone! filename
    configuration = readConfig! filename
    createRocFile! configuration.appName configuration.platform configuration.packages
    Stdout.line! "Created $(configuration.appName).roc"
    if doDelete then
        File.delete filename
    else
        Task.ok {}

createConfigIfNone = \filename ->
    if !(checkForFile! filename) then
        File.writeUtf8! filename configTemplate
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
    configBytes = File.readBytes! filename
    when Decode.fromBytes configBytes Rvn.pretty is
        Ok config -> Task.ok config
        Err _ -> Task.ok { platform: "", packages: [], appName: "" }

# ===================================
# ==== CODE GENERATION FUNCTIONS ====
# ===================================

createRocFile = \appName, platform, packageList ->
    repos <- loadRepositories |> Task.await
    File.writeBytes "$(appName).roc" (buildRocFile platform packageList repos)

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
