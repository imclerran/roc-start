app [main] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.11.0/SY4WWMhWQ9NvQgvIthcv15AUeA7rAIJHAHgiaSHGhdY.tar.br",
    ansi: "https://github.com/lukewilliamboswell/roc-ansi/releases/download/0.5/1JOFFXrqOrdoINq6C4OJ8k3UK0TJhgITLbcOb-6WMwY.tar.br",
    json: "https://github.com/lukewilliamboswell/roc-json/releases/download/0.10.0/KbIfTNbxShRX1A1FgXei1SpO5Jn8sgP6HP6PXbi-xyA.tar.br",
    rvn: "https://github.com/jwoudenberg/rvn/releases/download/0.1.0/2d2PF4kq9UUum9YpQH7k9iFIJ4hffWXQVCi0GJJweiU.tar.br",
    weaver: "https://github.com/smores56/weaver/releases/download/0.2.0/BBDPvzgGrYp-AhIDw0qmwxT0pWZIQP_7KOrUrZfp_xw.tar.br",
}

import AnsiStrs exposing [greenFg, redFg, resetStyle]
import ArgParser
import Controller
import Model exposing [Model]
import Repo exposing [RepositoryEntry, RemoteRepoEntry, CacheRepoEntry]
import View
import ansi.Core
import cli.Arg
import cli.Cmd
import cli.Dir
import cli.Env
import cli.File
import cli.Http
import cli.Path
import cli.Stdin
import cli.Stdout
import cli.Task exposing [Task]
import cli.Tty
import json.Json
import rvn.Rvn

Configuration : {
    appName : Str,
    platform : Str,
    packages : List Str,
}

## The main entry point for the program.
main : Task {} _
main =
    when ArgParser.parseOrDisplayMessage Arg.list! is
        Ok args ->
            runWith args

        Err message ->
            Stdout.line! message
            Task.err (Exit 1 "")

## Run the program with the parsed commandline args.
runWith : _ -> Task {} _
runWith = \args ->
    when args.subcommand is
        Ok (Tui {}) ->
            runTuiApp args.update

        Err NoSubcommand ->
            when (args.appName, args.platform) is
                (Ok appName, Ok platform) ->
                    runCliApp appName platform args.packages args.update

                _ ->
                    # Must use backpassing here instead of bang to avoid compiler crash.
                    {} <- Stdout.line "App name and platform arguments are required.\n" |> Task.await
                    Stdout.line ArgParser.baseUsage

## Run the CLI application.
## Load the repository data, and create the roc file if it doesn't already exist.
runCliApp : Str, Str, List Str, Bool -> Task {} _
runCliApp = \appName, platform, packages, forceUpdate ->
    repos = loadRepoData! forceUpdate
    getAppStubsIfNeeded! (Dict.keys repos.platforms) forceUpdate
    fileExists = checkForFile! "$(appName).roc"
    if fileExists then
        Stdout.line! "Error: $(appName).roc already exists. $(redFg)✖$(resetStyle)"
    else
        createRocFile! { appName, platform, packages } repos
        Stdout.line! "Created $(appName).roc $(greenFg)✔$(resetStyle)"

## Run the TUI application.
## Load the repository data, run the main tui loop, and create the roc file when the user confirms their selections.
runTuiApp : Bool -> Task {} _
runTuiApp = \forceUpdate ->
    repos = loadRepoData! forceUpdate
    getAppStubsIfNeeded! (Dict.keys repos.platforms) forceUpdate
    Tty.enableRawMode!
    model = Task.loop! (Model.init (Dict.keys repos.platforms) (Dict.keys repos.packages)) runUiLoop
    Stdout.write! (Core.toStr Reset)
    Tty.disableRawMode!
    when model.state is
        UserExited -> Task.ok {}
        Finished { config } ->
            fileExists = checkForFile! "$(config.appName).roc"
            if fileExists then
                Stdout.line "Error: $(config.appName).roc already exists. $(redFg)✖$(resetStyle)"
            else
                createRocFile! config repos
                Stdout.line "Created $(config.appName).roc $(greenFg)✔$(resetStyle)"

        _ -> Stdout.line "Oops! Something went wrong..."

## The main loop for running the TUI.
## Checks the terminal size, draws the screen, reads input, and handles the input.
runUiLoop : Model -> Task.Task [Step Model, Done Model] _
runUiLoop = \prevModel ->
    terminalSize = getTerminalSize!
    model = Model.paginate { prevModel & screen: terminalSize }
    Core.drawScreen model (render model) |> Stdout.write!

    input = Stdin.bytes |> Task.map! Core.parseRawStdin
    modelWithInput = { model & inputs: List.append model.inputs input }
    when model.state is
        InputAppName _ -> handleInputAppNameInput modelWithInput input
        PlatformSelect _ -> handlePlatformSelectInput modelWithInput input
        PackageSelect _ -> handlePackageSelectInput modelWithInput input
        Search _ -> handleSearchInput modelWithInput input
        Confirmation _ -> handleConfirmationInput modelWithInput input
        _ -> handleBasicInput modelWithInput input

## Get the size of the terminal window.
## Author: Luke Boswell
getTerminalSize : Task.Task Core.ScreenSize _
getTerminalSize =
    # Move the cursor to bottom right corner of terminal
    cmd = [MoveCursor (To { row: 999, col: 999 }), GetCursor] |> List.map Control |> List.map Core.toStr |> Str.joinWith ""
    Stdout.write! cmd
    # Read the cursor position
    Stdin.bytes
        |> Task.map Core.parseCursor
        |> Task.map! \{ row, col } -> { width: col, height: row }

## Generate the list of draw functions which will be used to draw the screen.
render : Model -> List Core.DrawFn
render = \model ->
    when model.state is
        InputAppName _ -> View.renderInputAppName model
        PlatformSelect _ -> View.renderPlatformSelect model
        PackageSelect _ -> View.renderPackageSelect model
        Search _ -> View.renderSearch model
        Confirmation _ -> View.renderConfirmation model
        _ -> []

## Basic input handler which ensures that the program can always be exited.
## This ensures that even if forget to handle input for a state, or end up
## in a state that doesn't have an input handler, the program can still be exited.
handleBasicInput : Model, Core.Input -> Task.Task [Step Model, Done Model] _
handleBasicInput = \model, input ->
    when input is
        CtrlC -> Task.ok (Done (Model.toUserExitedState model))
        _ -> Task.ok (Step model)

## The input handler for the PlatformSelect state.
handlePlatformSelectInput : Model, Core.Input -> Task.Task [Step Model, Done Model] _
handlePlatformSelectInput = \model, input ->
    action =
        when input is
            CtrlC -> Exit
            KeyPress LowerS -> Search
            KeyPress UpperS -> Search
            KeyPress Enter -> SingleSelect
            KeyPress Up -> CursorUp
            KeyPress Down -> CursorDown
            KeyPress Delete -> GoBack
            KeyPress Escape -> ClearFilter
            KeyPress Right -> NextPage
            KeyPress GreaterThanSign -> NextPage
            KeyPress FullStop -> NextPage
            KeyPress Left -> PrevPage
            KeyPress LessThanSign -> PrevPage
            KeyPress Comma -> PrevPage
            _ -> None
    Task.ok (Controller.applyAction { model, action })

## The input handler for the PackageSelect state.
handlePackageSelectInput : Model, Core.Input -> Task.Task [Step Model, Done Model] _
handlePackageSelectInput = \model, input ->
    action =
        when input is
            CtrlC -> Exit
            KeyPress LowerS -> Search
            KeyPress UpperS -> Search
            KeyPress Enter -> MultiConfirm
            KeyPress Space -> MultiSelect
            KeyPress Up -> CursorUp
            KeyPress Down -> CursorDown
            KeyPress Delete -> GoBack
            KeyPress Escape -> ClearFilter
            KeyPress Right -> NextPage
            KeyPress GreaterThanSign -> NextPage
            KeyPress FullStop -> NextPage
            KeyPress Left -> PrevPage
            KeyPress LessThanSign -> PrevPage
            KeyPress Comma -> PrevPage
            _ -> None
    Task.ok (Controller.applyAction { model, action })

## The input handler for the Search state.
handleSearchInput : Model, Core.Input -> Task.Task [Step Model, Done Model] _
handleSearchInput = \model, input ->
    (action, keyPress) =
        when input is
            CtrlC -> (Exit, None)
            KeyPress Enter -> (SearchGo, None)
            KeyPress Escape -> (Cancel, None)
            KeyPress Delete -> (TextBackspace, None)
            KeyPress key -> (TextInput, KeyPress key)
            _ -> (None, None)
    Task.ok (Controller.applyAction { model, action, keyPress })

## The input handler for the InputAppName state.
handleInputAppNameInput : Model, Core.Input -> Task.Task [Step Model, Done Model] _
handleInputAppNameInput = \model, input ->
    (action, keyPress) =
        when input is
            CtrlC -> (Exit, None)
            KeyPress Enter -> (TextConfirm, None)
            KeyPress Delete -> (TextBackspace, None)
            KeyPress key -> (TextInput, KeyPress key)
            _ -> (None, None)
    Task.ok (Controller.applyAction { model, action, keyPress })

## The input handler for the Confirmation state.
handleConfirmationInput : Model, Core.Input -> Task.Task [Step Model, Done Model] _
handleConfirmationInput = \model, input ->
    action =
        when input is
            CtrlC -> Exit
            KeyPress Enter -> Finish
            KeyPress Delete -> GoBack
            _ -> None
    Task.ok (Controller.applyAction { model, action })

## Create the data directory if it doesn't exist, and return the string version of the path.
getAndCreateDataDir : Task Str _
getAndCreateDataDir =
    home = Env.var! "HOME"
    dataDir = "$(home)/.roc-start"
    if checkForDir! dataDir then
        Task.ok dataDir
    else
        Dir.create! dataDir
        Task.ok dataDir

## Check if a directory exists at the given path.
## Guarantee Task.ok Bool result.
checkForDir : Str -> Task Bool _
checkForDir = \path ->
    Path.isDir (Path.fromStr path)
        |> Task.attempt! \res ->
            when res is
                Ok bool -> Task.ok bool
                _ -> Task.ok Bool.false

## Check if a file exists at the given path.
## Guarantee Task.ok Bool result.
checkForFile : Str -> Task Bool _
checkForFile = \filename ->
    Path.isFile (Path.fromStr filename)
        |> Task.attempt! \res ->
            when res is
                Ok bool -> Task.ok bool
                _ -> Task.ok Bool.false

## Load the repository data from the local cache. If the cache does not exist,
## or the user requests an update, fetch the latest data from the remote repository.
loadRepoData : Bool -> Task { packages : Dict Str RepositoryEntry, platforms : Dict Str RepositoryEntry } _
loadRepoData = \forceUpdate ->
    dataDir = getAndCreateDataDir!
    packageBytes = File.readBytes "$(dataDir)/pkg-data.rvn" |> Task.onErr! \_ -> Task.ok [] # if this block is placed inside if statement
    platformBytes = File.readBytes "$(dataDir)/pf-data.rvn" |> Task.onErr! \_ -> Task.ok [] # the compiler hangs indefinitely
    packages = getRepoDict packageBytes # it would be better not to do this read here
    platforms = getRepoDict platformBytes # but does not noticably slow UX.
    if forceUpdate then
        loadLatestRepoData
    else if Dict.isEmpty platforms || Dict.isEmpty packages then
        loadLatestRepoData # this will migrate tuples to records from old roc-start installs
    else
        Task.ok { packages, platforms }

## DO NOT DELETE ME!
## This is the perfered version of loadRepoData, but putting the logic to read the files inside the if statement
## causes the compiler to hang indefinitely. If this bug is fixed, the above version should be replaced with this one.
# loadRepoData = \forceUpdate ->
#     if forceUpdate then
#         loadLatestRepoData
#     else
# >         dataDir = getAndCreateDataDir!
#         packageBytes = File.readBytes "$(dataDir)/pkg-data.rvn" |> Task.onErr! \_ -> Task.ok []
#         platformBytes = File.readBytes "$(dataDir)/pf-data.rvn" |> Task.onErr! \_ -> Task.ok []
# >        packages = getRepoDict packageBytes
#         platforms = getRepoDict platformBytes
#         if Dict.isEmpty platforms || Dict.isEmpty packages then
#             loadLatestRepoData # this will migrate tuples to records from old roc-start installs
#         else
#             Task.ok { packages, platforms }

## Load the latest repository data from the remote repository.
loadLatestRepoData : Task { packages : Dict Str RepositoryEntry, platforms : Dict Str RepositoryEntry } _
loadLatestRepoData =
    doRepoUpdate!
    dataDir = getAndCreateDataDir!
    packageBytes = File.readBytes! "$(dataDir)/pkg-data.rvn" # consider using in-memory data structure
    platformBytes = File.readBytes! "$(dataDir)/pf-data.rvn" # if the repo was loaded from remote
    packages = getRepoDict packageBytes
    platforms = getRepoDict platformBytes
    Task.ok { packages, platforms }

## Update the local repository cache with the latest data from the remote repository.
doRepoUpdate : Task {} _
doRepoUpdate =
    repoLists = getRemoteRepoData!
    Stdout.write! "Updating platform repository..."
    updateRepoCache! repoLists.platformRepos "pf-data.rvn"
    Stdout.line! " $(greenFg)✔$(resetStyle)"
    Stdout.write! "Updating package repository..."
    updateRepoCache! repoLists.packageRepos "pkg-data.rvn"
    Stdout.line " $(greenFg)✔$(resetStyle)"

## Get the remote repository data, decode it, and split it into a list of package and platform repos.
getRemoteRepoData : Task { packageRepos : List RemoteRepoEntry, platformRepos : List RemoteRepoEntry } _
getRemoteRepoData =
    request = getRequest "https://raw.githubusercontent.com/imclerran/roc-start/main/repository/roc-repo.rvn"
    resp = Http.send request |> Task.onErr! \_ -> Task.ok { body: [], headers: [], statusCode: 0, statusText: "", url: "" }
    when Decode.fromBytes resp.body Rvn.pretty is
        Ok repos ->
            repoLists = List.walk repos { packageRepos: [], platformRepos: [] } \state, repoItem ->
                if repoItem.platform then
                    { state & platformRepos: List.append state.platformRepos repoItem }
                else
                    { state & packageRepos: List.append state.packageRepos repoItem }
            Task.ok repoLists

        Err _ -> Task.ok { packageRepos: [], platformRepos: [] }

getRequest = \url -> {
    method: Get,
    headers: [],
    url,
    mimeType: "",
    body: [],
    timeout: TimeoutMilliseconds 5000,
}

## Get the latest release for each package in the repository.
updateRepoCache : List RemoteRepoEntry, Str -> Task {} _
updateRepoCache = \repositoryList, filename ->
    if List.isEmpty repositoryList then
        Task.ok {}
    else
        dataDir = getAndCreateDataDir!
        pkgRvnStr = Task.loop! { repositoryList, rvnDataStr: "[\n" } reposToRvnStrLoop
        File.writeBytes "$(dataDir)/$(filename)" (pkgRvnStr |> Str.toUtf8)

RepositoryLoopState : { repositoryList : List RemoteRepoEntry, rvnDataStr : Str }

## Loop function which processes each git repo in the platform or package list, gets the latest release for each,
## and creates a string in rvn format containing the data for each package or platform. Used with `Task.loop`.
reposToRvnStrLoop : RepositoryLoopState -> Task [Step RepositoryLoopState, Done Str] _
reposToRvnStrLoop = \{ repositoryList, rvnDataStr } ->
    when List.get repositoryList 0 is
        Ok { owner, repo, alias, platform } ->
            updatedList = List.dropFirst repositoryList 1
            response = getLatestRelease! owner repo
            releaseData = responseToReleaseData response
            when releaseData is
                Ok { tagName, browserDownloadUrl } ->
                    updatedStr = Str.concat rvnDataStr (repoDataToRvnEntry { repo, owner, alias, version: tagName, url: browserDownloadUrl, platform })
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
repoDataToRvnEntry : CacheRepoEntry -> Str
repoDataToRvnEntry = \entry ->
    boolStr = if entry.platform then "Bool.true" else "Bool.false"
    """
        { repo: "$(entry.repo)", owner: "$(entry.owner)", alias: "$(entry.alias)", version: "$(entry.version)", url: "$(entry.url)", platform: $(boolStr) },\n
    """

## Convert the raw bytes from pkg-data.rvn to a Dictionary of RepositoryEntry with the repo name as the key.
getRepoDict : List U8 -> Dict Str RepositoryEntry
getRepoDict = \bytes ->
    res =
        Decode.fromBytes bytes Rvn.pretty
        |> Result.map \packageList ->
            packageList
            |> List.walk (Dict.empty {}) \dict, cacheEntry ->
                Dict.insert dict cacheEntry.repo { alias: cacheEntry.alias, version: cacheEntry.version, url: cacheEntry.url }
    when res is
        Ok dict -> dict
        Err _ -> Dict.empty {}

## Update the app-stubs for the given platforms if they don't already exist, or if the user requests an update.
getAppStubsIfNeeded : List Str, Bool -> Task {} _
getAppStubsIfNeeded = \platforms, forceUpdate ->
    dataDir = getAndCreateDataDir!
    dirExists = checkForDir! "$(dataDir)/app-stubs"
    if !dirExists || forceUpdate then
        getAppStubs! platforms
    else
        Task.ok {}

## Update the app-stubs for the given platforms.
getAppStubs : List Str -> Task {} _
getAppStubs = \platforms ->
    dataDir = getAndCreateDataDir!
    appStubsDir = getAndCreateDir! "$(dataDir)/app-stubs"
    Stdout.write! "Downloading app-stubs..."
    Task.loop! { platforms, dir: appStubsDir } getAppStubsLoop
    Stdout.line " $(greenFg)✔$(resetStyle)"

AppStubsLoopState : { platforms : List Str, dir : Str }

## Loop function which processes each platform in the platform list, gets the app-stub for each.
getAppStubsLoop : AppStubsLoopState -> Task [Step AppStubsLoopState, Done {}] _
getAppStubsLoop = \{ platforms, dir } ->
    when List.get platforms 0 is
        Ok platform ->
            updatedList = List.dropFirst platforms 1
            request = getRequest "https://raw.githubusercontent.com/imclerran/roc-start/main/repository/app-stubs/$(platform).roc"
            response = Http.send request |> Task.onErr! \_ -> Task.ok { body: [], headers: [], statusCode: 0, statusText: "", url: "" }
            if response.statusCode == 200 && !(List.isEmpty response.body) then
                File.writeBytes! "$(dir)/$(platform)" response.body
                Task.ok (Step { platforms: updatedList, dir })
            else
                Task.ok (Step { platforms: updatedList, dir })

        Err OutOfBounds -> Task.ok (Done {})

## Create a directory at the given path if it doesn't already exist.
getAndCreateDir : Str -> Task Str _
getAndCreateDir = \dirPath ->
    if checkForDir! dirPath then
        Task.ok dirPath
    else
        Dir.create! dirPath
        Task.ok dirPath

## Generate a roc file from the given appName, platform, and packageList.
createRocFile : Configuration, { packages : Dict Str RepositoryEntry, platforms : Dict Str RepositoryEntry } -> Task {} _
createRocFile = \config, repos ->
    appStub = getAppStub! config.platform
    File.writeBytes "$(config.appName).roc" (buildRocFile config.platform config.packages repos appStub)

## Build the raw byte representation of a roc file from the given platform, packageList, and repositories.
buildRocFile : Str, List Str, { packages : Dict Str RepositoryEntry, platforms : Dict Str RepositoryEntry }, List U8 -> List U8
buildRocFile = \platform, packageList, repos, appStub ->
    pfStr =
        when Dict.get repos.platforms platform is
            Ok pf -> "    $(pf.alias): platform \"$(pf.url)\",\n"
            Err KeyNotFound -> crash "Invalid platform: $(platform)"
    pkgsStr =
        List.walk packageList "" \str, package ->
            when Dict.get repos.packages package is
                Ok pkg -> Str.concat str "    $(pkg.alias): \"$(pkg.url)\",\n"
                Err KeyNotFound -> ""

    "app [main] {\n$(pfStr)$(pkgsStr)}\n" |> Str.toUtf8 |> List.concat appStub

## Get the application stub for the platform, if it exists
getAppStub : Str -> Task (List U8) _
getAppStub = \platform ->
    dataDir = getAndCreateDataDir!
    File.readBytes "$(dataDir)/app-stubs/$(platform)"
        |> Task.onErr \_ -> Task.ok []
        |> Task.map! \bytes -> if List.isEmpty bytes then bytes else List.prepend bytes '\n'

