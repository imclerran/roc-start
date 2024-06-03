app [main] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.11.0/SY4WWMhWQ9NvQgvIthcv15AUeA7rAIJHAHgiaSHGhdY.tar.br",
    ansi: "https://github.com/lukewilliamboswell/roc-ansi/releases/download/0.5/1JOFFXrqOrdoINq6C4OJ8k3UK0TJhgITLbcOb-6WMwY.tar.br",
    rvn: "https://github.com/jwoudenberg/rvn/releases/download/0.1.0/2d2PF4kq9UUum9YpQH7k9iFIJ4hffWXQVCi0GJJweiU.tar.br",
    json: "https://github.com/lukewilliamboswell/roc-json/releases/download/0.10.0/KbIfTNbxShRX1A1FgXei1SpO5Jn8sgP6HP6PXbi-xyA.tar.br",
}

import Model exposing [Model]
import Repos exposing [RepositoryEntry]
import View
import cli.Http
import cli.File
import cli.Dir
import cli.Env
import cli.Path
import cli.Stdout
import cli.Stdin
import cli.Tty
import cli.Cmd
import cli.Task exposing [Task]
import ansi.Core
import rvn.Rvn
import json.Json

Configuration : {
    appName : Str,
    platform : Str,
    packages : List Str,
}

## Create the data directory if it doesn't exist, and return the string version of the path.
getAndCreateDataDir =
    home = Env.var! "HOME"
    dataDir = "$(home)/.roc-start"
    if checkForDir! dataDir then
        Task.ok dataDir
    else
        Dir.create! dataDir
        Task.ok dataDir

## Check if a directory exists at the given path.
checkForDir = \path ->
    Path.isDir (Path.fromStr path)
        |> Task.attempt! \res ->
            when res is
                Ok bool -> Task.ok bool
                _ -> Task.ok Bool.false

## Check if a file exists at the given path.
checkForFile = \filename ->
    Path.isFile (Path.fromStr filename)
        |> Task.attempt! \res ->
            when res is
                Ok bool -> Task.ok bool
                _ -> Task.ok Bool.false

getRawRepoData : Task (List U8) _
getRawRepoData =
    request = {
        method: Get,
        headers: [],
        url: "https://raw.githubusercontent.com/imclerran/roc-repo/main/repo.rvn",
        mimeType: "",
        body: [],
        timeout: TimeoutMilliseconds 5000,
    }
    resp = Http.send request |> Task.onErr! \_ -> Task.ok { body: [], headers: [], statusCode: 0, statusText: "", url: "" }
    Task.ok resp.body

decodeRepoData : List U8 -> List { repo : Str, owner : Str, alias : Str, platform: Bool }
decodeRepoData = \data ->
    res = Decode.fromBytes data Rvn.pretty
    when res is
        Ok list -> list
        Err _ -> []

loadLatestRepoData =
    bytes = getRawRepoData!
    repos = decodeRepoData bytes
    repoLists = List.walk repos { packageRepoList: [], platformRepoList: [] } \state, repoItem ->
        if repoItem.platform then
            {state & platformRepoList: List.append state.platformRepoList (repoItem.alias, repoItem.owner, repoItem.repo) }
        else
            {state & packageRepoList: List.append state.packageRepoList (repoItem.alias, repoItem.owner, repoItem.repo) }
    # Bottleneck: updating repo cache also handles fetchting the latest release versions/urls
    # TODO: split the update functionality into its own function, which is run only on first run
    # or when the user requests an update. Caching should be in a separate function.
    # this will also allow using the in-memory data structure for the repo data, instead of reading from disk
    updateRepoCache! repoLists.packageRepoList "pkg-data.rvn"
    updateRepoCache! repoLists.platformRepoList "pf-data.rvn"
    dataDir = getAndCreateDataDir!
    packageBytes = File.readBytes! "$(dataDir)/pkg-data.rvn" # consider using in-memory data structure
    platformBytes = File.readBytes! "$(dataDir)/pf-data.rvn" # if the repo was loaded from remote
    packages = getRepoDict packageBytes
    platforms = getRepoDict platformBytes
    Task.ok { packages, platforms }

## Get the latest release for each package in the repository.
updateRepoCache : List (Str, Str, Str), Str -> Task {} _
updateRepoCache = \repositoryList, filename ->
    if List.isEmpty repositoryList then
        Task.ok {}
    else
        dataDir = getAndCreateDataDir!
        pkgRvnStr = Task.loop! { repositoryList, rvnDataStr: "[\n" } reposToRvnStrLoop
        File.writeBytes "$(dataDir)/$(filename)" (pkgRvnStr |> Str.toUtf8)

RepositoryData : (Str, Str, Str)
RepositoryLoopState : { repositoryList : List RepositoryData, rvnDataStr : Str }

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
getRepoDict : List U8 -> Dict Str RepositoryEntry
getRepoDict = \bytes ->
    res =
        Decode.fromBytes bytes Rvn.pretty
        |> Result.map \packageList ->
            packageList
            |> List.walk (Dict.empty {}) \dict, (name, shortName, version, url) ->
                Dict.insert dict name { shortName, version, url }
    when res is
        Ok dict -> dict
        Err _ -> Dict.empty {}

## Generate a roc file from the given appName, platform, and packageList.
createRocFile : Configuration, { packages: Dict Str RepositoryEntry, platforms: Dict Str RepositoryEntry } -> Task {} _
createRocFile = \config, repos ->
    #repos <- loadDictionaries |> Task.await
    File.writeBytes "$(config.appName).roc" (buildRocFile config.platform config.packages repos)

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

render : Model -> List Core.DrawFn
render = \model ->
    when model.state is
        InputAppName _ -> View.renderInputAppName model
        PlatformSelect _ -> View.renderPlatformSelect model
        PackageSelect _ -> View.renderPackageSelect model
        SearchPage _ -> View.renderSearchPage model
        Confirmation _ -> View.renderConfirmation model
        _ -> []

getTerminalSize : Task.Task Core.ScreenSize _
getTerminalSize =
    # Move the cursor to bottom right corner of terminal
    cmd = [MoveCursor (To { row: 999, col: 999 }), GetCursor] |> List.map Control |> List.map Core.toStr |> Str.joinWith ""
    Stdout.write! cmd
    # Read the cursor position
    Stdin.bytes
        |> Task.map Core.parseCursor
        |> Task.map! \{ row, col } -> { width: col, height: row }

runUiLoop : Model -> Task.Task [Step Model, Done Model] _
runUiLoop = \prevModel ->
    terminalSize = getTerminalSize!
    model = Model.paginate { prevModel & screen: terminalSize }
    Core.drawScreen model (render model)
        |> Stdout.write!

    input = Stdin.bytes |> Task.map! Core.parseRawStdin
    modelWithInput = { model & inputs: List.append model.inputs input }
    when model.state is
        InputAppName _ -> handleInputAppNameInput modelWithInput input
        PlatformSelect _ -> handlePlatformSelectInput modelWithInput input
        PackageSelect _ -> handlePackageSelectInput modelWithInput input
        SearchPage { sender } -> handleSearchPageInput modelWithInput input sender
        Confirmation _ -> handleConfirmationInput modelWithInput input
        _ -> handleBasicInput modelWithInput input

handleBasicInput : Model, Core.Input -> Task.Task [Step Model, Done Model] _
handleBasicInput = \model, input ->
    when input is
        CtrlC -> Task.ok (Done { model & state: UserExited })
        _ -> Task.ok (Step model)

handlePlatformSelectInput : Model, Core.Input -> Task.Task [Step Model, Done Model] _
handlePlatformSelectInput = \model, input ->
    when input is
        CtrlC -> Task.ok (Done { model & state: UserExited })
        KeyPress LowerS -> Task.ok (Step (Model.toSearchPageState model))
        KeyPress UpperS -> Task.ok (Step (Model.toSearchPageState model))
        KeyPress Enter -> Task.ok (Step (Model.toPackageSelectState model))
        KeyPress Up -> Task.ok (Step (Model.moveCursor model Up))
        KeyPress Down -> Task.ok (Step (Model.moveCursor model Down))
        KeyPress Delete -> Task.ok (Step (Model.toInputAppNameState model))
        KeyPress Escape -> Task.ok (Step (Model.clearSearchFilter model))
        KeyPress Right -> Task.ok (Step (Model.nextPage model))
        KeyPress GreaterThanSign -> Task.ok (Step (Model.nextPage model))
        KeyPress FullStop -> Task.ok (Step (Model.nextPage model))
        KeyPress Left -> Task.ok (Step (Model.prevPage model))
        KeyPress LessThanSign -> Task.ok (Step (Model.prevPage model))
        KeyPress Comma -> Task.ok (Step (Model.prevPage model))
        _ -> Task.ok (Step model)

handlePackageSelectInput : Model, Core.Input -> Task.Task [Step Model, Done Model] _
handlePackageSelectInput = \model, input ->
    when input is
        CtrlC -> Task.ok (Done { model & state: UserExited })
        KeyPress LowerS -> Task.ok (Step (Model.toSearchPageState model))
        KeyPress UpperS -> Task.ok (Step (Model.toSearchPageState model))
        KeyPress Enter -> Task.ok (Step (Model.toConfirmationState model))
        KeyPress Space -> Task.ok (Step (Model.toggleSelected model))
        KeyPress Up -> Task.ok (Step (Model.moveCursor model Up))
        KeyPress Down -> Task.ok (Step (Model.moveCursor model Down))
        KeyPress Delete -> Task.ok (Step (Model.toPlatformSelectState model))
        KeyPress Escape -> Task.ok (Step (Model.clearSearchFilter model))
        KeyPress Right -> Task.ok (Step (Model.nextPage model))
        KeyPress GreaterThanSign -> Task.ok (Step (Model.nextPage model))
        KeyPress FullStop -> Task.ok (Step (Model.nextPage model))
        KeyPress Left -> Task.ok (Step (Model.prevPage model))
        KeyPress LessThanSign -> Task.ok (Step (Model.prevPage model))
        KeyPress Comma -> Task.ok (Step (Model.prevPage model))
        _ -> Task.ok (Step model)

handleSearchPageInput : Model, Core.Input, [Platform, Package] -> Task.Task [Step Model, Done Model] _
handleSearchPageInput = \model, input, sender ->
    when input is
        CtrlC -> Task.ok (Done { model & state: UserExited })
        KeyPress Enter ->
            when sender is
                Platform -> Task.ok (Step (Model.toPlatformSelectState model))
                Package -> Task.ok (Step (Model.toPackageSelectState model))
        KeyPress Escape -> Task.ok (Step (model |> Model.clearSearchBuffer |> Model.toPlatformSelectState))
        KeyPress Delete -> Task.ok (Step (Model.backspaceBuffer model))
        KeyPress c -> Task.ok (Step (Model.appendToBuffer model c))
        _ -> Task.ok (Step model)

handleInputAppNameInput : Model, Core.Input -> Task.Task [Step Model, Done Model] _
handleInputAppNameInput = \model, input ->
    when input is
        CtrlC -> Task.ok (Done { model & state: UserExited })
        KeyPress Enter -> Task.ok (Step (Model.toPlatformSelectState model))
        KeyPress Delete -> Task.ok (Step (Model.backspaceBuffer model))
        KeyPress c -> Task.ok (Step (Model.appendToBuffer model c))
        _ -> Task.ok (Step model)

handleConfirmationInput : Model, Core.Input -> Task.Task [Step Model, Done Model] _
handleConfirmationInput = \model, input ->
    when input is
        CtrlC -> Task.ok (Done { model & state: UserExited })
        KeyPress Enter -> Task.ok (Done (Model.toFinishedState model))
        KeyPress Delete -> Task.ok (Step (Model.toPackageSelectState model))
        _ -> Task.ok (Step model)

main =
    #repos = loadDictionaries!
    repos = loadLatestRepoData!
    Tty.enableRawMode!
    model = Task.loop! (Model.init repos.platforms repos.packages) runUiLoop
    Stdout.write! (Core.toStr Reset)
    Tty.disableRawMode!
    when model.state is
        UserExited -> Task.ok {}
        Finished { config } ->
            # repoData = getRawRepoData!
            # repo = decodeRepoData repoData
            fileExists = checkForFile! "$(config.appName).roc"
            if fileExists then
                Stdout.line! "Error: $(config.appName).roc already exists."
            else
                createRocFile! config repos
                Stdout.line! "Created $(config.appName).roc"
        _ -> Stdout.line! "Something went wrong..."
