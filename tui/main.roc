app [main] {
    cli: platform "https://github.com/roc-lang/basic-cli/releases/download/0.10.0/vNe6s9hWzoTZtFmNkvEICPErI9ptji_ySjicO6CkucY.tar.br",
    ansi: "https://github.com/lukewilliamboswell/roc-ansi/releases/download/0.5/1JOFFXrqOrdoINq6C4OJ8k3UK0TJhgITLbcOb-6WMwY.tar.br",
}

import Model exposing [Model]
import Const
import UI
import cli.Stdout
import cli.Stdin
import cli.Tty
import cli.Task
import ansi.Core



render : Model -> List Core.DrawFn
render = \model ->
    when model.state is
        PlatformSelect _ -> UI.renderPlatformSelect model
        PackageSelect _ -> UI.renderPackageSelect model
        SearchPage _ -> UI.renderSearchPage model
        Confirmation _ -> UI.renderConfirmation model
        _ -> UI.renderPlatformSelect model

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
        KeyPress Enter -> Task.ok (Step (Model.toConfirmationState model))
        KeyPress Space -> Task.ok (Step (Model.toggleSelected model))
        KeyPress Up -> Task.ok (Step (Model.moveCursor model Up))
        KeyPress Down -> Task.ok (Step (Model.moveCursor model Down))
        KeyPress Delete -> Task.ok (Step (Model.toPlatformSelectState model))
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
        KeyPress Delete -> Task.ok (Step (Model.backspaceSearchBuffer model))
        KeyPress c -> Task.ok (Step (Model.appendToSearchBuffer model c))
        _ -> Task.ok (Step model)

handleConfirmationInput : Model, Core.Input -> Task.Task [Step Model, Done Model] _
handleConfirmationInput = \model, input ->
    when input is
        CtrlC -> Task.ok (Done { model & state: UserExited })
        KeyPress Enter -> Task.ok (Done (Model.toFinishedState model))
        KeyPress Delete -> Task.ok (Step (Model.toPackageSelectState model))
        _ -> Task.ok (Step model)



main =
    Tty.enableRawMode!
    model = Task.loop! (Model.init Const.platformList) runUiLoop
    Stdout.write! (Core.toStr Reset)
    Tty.disableRawMode!
    when model.state is
        UserExited -> Stdout.line! "Exiting..."
        Finished { config } -> Stdout.line! (exitMessage config.platform config.packages)
        _ -> Stdout.line! "Crash!"

mapListToStr : List Str -> Str
mapListToStr = \list ->
    str, elem, idx <- List.walkWithIndex list ""
    Str.joinWith [str, elem] (if idx == 0 then "" else ", ")

exitMessage : Str, List Str -> Str
exitMessage = \platform, packages ->
    magenta = "\u(001b)[35m"
    noColor = "\u(001b)[0m"
    """
    $(magenta)Platform: $(noColor)$(platform)
    $(magenta)Packages: $(noColor)$(mapListToStr packages)
    """
