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

main : Task {} _
main =
    when ArgParser.parseOrDisplayMessage Arg.list! is
        Ok args ->
            runWith args

        Err message ->
            Stdout.line! message
            Task.err (Exit 1 "")

## run the program with the parsed args
runWith : _ -> Task {} _
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

# ======================================
# ==== REPOSITORY RELATED TYPES ========
# ======================================

## State object for Task.loop function: reposToRvnStrLoop
RepositoryLoopState : { repositoryList : List RepositoryData, rvnDataStr : Str }

## Data structure which maps to the structure of pkg-repos.rvn and pf-repos.rvn
## This is: shortName, user, repo
RepositoryData : (Str, Str, Str)

## The data structure for a single repository entry in the package or platform Dict.
RepositoryEntry : { shortName : Str, version : Str, url : Str }

## The data structure modeling the requirements for generating a new app.
AppConfig : { appName : Str, platform : Str, packages : List Str }

# ======================================
# ==== REPOSITORY RELATED FUNCTIONS ====
# ======================================

## Load the package and platform dictionaries from the files on disk.
## If the data files do not yet exist, update to create them.
loadRepositories : Task { packages : Dict Str RepositoryEntry, platforms : Dict Str RepositoryEntry } _
loadRepositories =
    dataDir = getAndCreateDataDir!
    runUpdateIfNecessary! dataDir
    packageBytes = File.readBytes! "$(dataDir)/pkg-data.rvn"
    platformBytes = File.readBytes! "$(dataDir)/pf-data.rvn"
    packages = getPackageDict packageBytes
    platforms = getPlatformDict platformBytes
    Task.ok { packages, platforms }

## Check if the package and platform data files exist. If not, update to create them.
runUpdateIfNecessary : Str -> Task {} _
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

## Get the latest release for each package in the repository.
updatePackageData : Task {} _
updatePackageData =
    dataDir = getAndCreateDataDir!
    pkgRvnStr = Task.loop! { repositoryList: getPackageRepoList, rvnDataStr: "[\n" } reposToRvnStrLoop
    File.writeBytes! "$(dataDir)/pkg-data.rvn" (pkgRvnStr |> Str.toUtf8)
    Stdout.line "Package data updated."

## Get the latest release for each platform in the repository.
updatePlatformData : Task {} _
updatePlatformData =
    dataDir = getAndCreateDataDir!
    pfRvnStr = Task.loop! { repositoryList: getPlatformRepoList, rvnDataStr: "[\n" } reposToRvnStrLoop
    File.writeBytes! "$(dataDir)/pf-data.rvn" (pfRvnStr |> Str.toUtf8)
    Stdout.line "Platform data updated."

## Convert the raw bytes from pkg-repos.rvn to a list of tuples.
getPackageRepoList : List RepositoryData
getPackageRepoList =
    when Decode.fromBytes pkgRepos Rvn.pretty is
        Ok repos -> repos
        Err _ -> []

## Convert the raw bytes from pf-repos.rvn to a list of tuples.
getPlatformRepoList : List RepositoryData
getPlatformRepoList =
    when Decode.fromBytes pfRepos Rvn.pretty is
        Ok repos -> repos
        Err _ -> []

## Loop function which processes each git repo in the platform or package list, gets the latest release for each,
## and creates a string in rvn format containing the data for each package or platform. Used with `Task.loop`.
reposToRvnStrLoop : RepositoryLoopState -> Task [Step RepositoryLoopState, Done Str] _
reposToRvnStrLoop = \{ repositoryList, rvnDataStr } ->
    when List.get repositoryList 0 is
        Ok (shortName, user, repo) ->
            updatedList = List.dropFirst repositoryList 1
            response = getLatestRelease! user repo
            releaseData = responseToReleaseData response
            when releaseData is
                Ok { tagName, browserDownloadUrl } ->
                    updatedStr = Str.concat rvnDataStr (repoDataToRvnEntry repo shortName tagName browserDownloadUrl)
                    Task.ok (Step { repositoryList: updatedList, rvnDataStr: updatedStr })

                Err _ -> Task.ok (Step { repositoryList: updatedList, rvnDataStr })

        Err OutOfBounds -> Task.ok (Done (Str.concat rvnDataStr "]"))

## Use the github cli to get the latest release for a given repository.
getLatestRelease : Str, Str -> Task { stdout : List U8, stderr : List U8 } _
getLatestRelease = \owner, repo ->
    Cmd.new "gh"
        |> Cmd.arg "api"
        |> Cmd.arg "-H"
        |> Cmd.arg "Accept: application/vnd.github+json"
        |> Cmd.arg "-H"
        |> Cmd.arg "X-GitHub-Api-Version: 2022-11-28"
        |> Cmd.arg "/repos/$(owner)/$(repo)/releases/latest"
        |> Cmd.output
        |> Task.onErr! \_ -> Task.ok { stdout: [], stderr: [] }

## Parse the response from the github cli to get the tagName and browserDownloadUrl for the tar.br file for a given release.
responseToReleaseData : { stdout : List U8 }* -> Result { tagName : Str, browserDownloadUrl : Str } [NoAssetsFound, ParsingError]
responseToReleaseData = \response ->
    isTarBr = \{ browserDownloadUrl } -> Str.endsWith browserDownloadUrl ".tar.br"
    jsonResponse = Decode.fromBytes response.stdout (Json.utf8With { fieldNameMapping: SnakeCase })
    when jsonResponse is
        Ok { tagName, assets } ->
            when assets |> List.keepIf isTarBr |> List.first is
                Ok { browserDownloadUrl } -> Ok { tagName, browserDownloadUrl }
                Err ListWasEmpty -> Err NoAssetsFound

        Err _ -> Err ParsingError

## Convert the data for a single repository entry to a string in rvn format.
repoDataToRvnEntry : Str, Str, Str, Str -> Str
repoDataToRvnEntry = \repo, shortName, tagName, browserDownloadUrl ->
    """
        ("$(repo)", "$(shortName)", "$(tagName)", "$(browserDownloadUrl)"),\n
    """

## Convert the raw bytes from pkg-data.rvn to a Dictionary of RepositoryEntry with the repo name as the key.
getPackageDict : List U8 -> Dict Str RepositoryEntry
getPackageDict = \packageBytes ->
    res =
        Decode.fromBytes packageBytes Rvn.pretty
        |> Result.map \packageList ->
            packageList
            |> List.walk (Dict.empty {}) \dict, (name, shortName, version, url) ->
                Dict.insert dict name { shortName, version, url }
    when res is
        Ok dict -> dict
        Err _ -> Dict.empty {}

## Convert the raw bytes from pf-data.rvn to a Dictionary of RepositoryEntry with the repo name as the key.
getPlatformDict : List U8 -> Dict Str RepositoryEntry
getPlatformDict = \platformBytes ->
    res =
        Decode.fromBytes platformBytes Rvn.pretty
        |> Result.map \packageList ->
            packageList
            |> List.walk (Dict.empty {}) \dict, (name, shortName, version, url) ->
                Dict.insert dict name { shortName, version, url }
    when res is
        Ok dict -> dict
        Err _ -> Dict.empty {}

# ======================================
# ==== FILESYSTEM RELATED FUNCTIONS ====
# ======================================

## Check if a file exists at the given path.
checkForFile = \filename ->
    Path.isFile (Path.fromStr filename)
        |> Task.attempt! \res ->
            when res is
                Ok bool -> Task.ok bool
                _ -> Task.ok Bool.false

## Check if a directory exists at the given path.
checkForDir = \path ->
    Path.isDir (Path.fromStr path)
        |> Task.attempt! \res ->
            when res is
                Ok bool -> Task.ok bool
                _ -> Task.ok Bool.false

## Create the data directory if it doesn't exist, and return the string version of the path.
getAndCreateDataDir =
    home = Env.var! "HOME"
    dataDir = "$(home)/.roc-start"
    if checkForDir! dataDir then
        Task.ok dataDir
    else
        Dir.create! dataDir
        Task.ok dataDir

# ==================================
# ==== CONFIG RELATED FUNCTIONS ====
# ==================================

## Generate a new roc file from a specified config file. If the config doesn't exist, open a new file in nano.
createFromConfig = \filename, doDelete ->
    createConfigIfNone! filename
    configuration = readConfig! filename
    createRocFile! configuration.appName configuration.platform configuration.packages
    Stdout.line! "Created $(configuration.appName).roc"
    if doDelete then
        File.delete filename
    else
        Task.ok {}

## Create a template config file if the specified file doesn't exist, and open it in nano.
createConfigIfNone : Str -> Task {} [CmdError _, FileWriteErr _ _]
createConfigIfNone = \filename ->
    if !(checkForFile! filename) then
        File.writeUtf8! filename configTemplate
        Cmd.exec "nano" [filename]
    else
        Task.ok {}

## The template config file for generating a new app. Defaults to basic-cli platform, and no packages.
configTemplate =
    """
    {
        appName: "new-app",
        platform: "basic-cli",
        packages: [], # packages list may be empty
    }
    """

## Read the config file at the given path, and return the AppConfig
readConfig : Str -> Task AppConfig [FileReadErr _ _]
readConfig = \filename ->
    configBytes = File.readBytes! filename
    when Decode.fromBytes configBytes Rvn.pretty is
        Ok config -> Task.ok config
        Err _ -> Task.ok { appName: "", platform: "", packages: [] }

# ===================================
# ==== CODE GENERATION FUNCTIONS ====
# ===================================

## Generate a roc file from the given appName, platform, and packageList.
createRocFile : Str, Str, List Str -> Task {} _
createRocFile = \appName, platform, packageList ->
    repos <- loadRepositories |> Task.await
    File.writeBytes "$(appName).roc" (buildRocFile platform packageList repos)

## Build the raw byte representation of a roc file from the given platform, packageList, and repositories.
buildRocFile : Str, List Str, { packages : Dict Str RepositoryEntry, platforms : Dict Str RepositoryEntry } -> List U8
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
