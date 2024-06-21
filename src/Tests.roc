module []

import Model
import Controller

## ===============================
## HELPER FUNCTIONS

applyAction = \model, action ->
    when Controller.applyAction { model, action } is
        Step newModel -> newModel
        Done newModel -> newModel

applyActionWithKey = \model, action, keyPress ->
    when Controller.applyAction { model, action, keyPress } is
        Step newModel -> newModel
        Done newModel -> newModel

## ===============================
## HELPER OBJECTS

emptyAppConfig = { fileName: "", platform: "", packages: [], type: App }

## ===============================
## MODEL OBJECTS IN VARIOUS STATES

typeSelectModel = Model.init ["pf1", "pf2"] ["pk1", "pk2", "pk3"]
inputAppNameModel = typeSelectModel |> applyAction SingleSelect
platformSelectModel = inputAppNameModel |> applyAction TextSubmit
packageSelectModel = platformSelectModel |> applyAction SingleSelect
confirmationModel = packageSelectModel |> applyAction MultiConfirm
finishedModel = confirmationModel |> applyAction Finish

## ===============================
## model object tests

expect
    # TEST: init model
    model = typeSelectModel
    (model.state == TypeSelect { config: emptyAppConfig })
    && (model.platformList == ["pf1", "pf2"])
    && (model.packageList == ["pk1", "pk2", "pk3"])
    && (model.menu == ["App", "Package"])
    && (model.fullMenu == ["App", "Package"])
    && (model.cursor == { row: model.menuRow, col: 2 })
    && (model.screen == { height: 0, width: 0 })
    && (model.selected == [])
    && (model.pageFirstItem == 0)
    && (model.menuRow == 2)

expect
    # TEST: transition from TypeSelect to InputAppName
    model = inputAppNameModel
    (model.state == InputAppName { nameBuffer: [], config: emptyAppConfig })
    && (model.platformList == ["pf1", "pf2"])
    && (model.packageList == ["pk1", "pk2", "pk3"])
    && (model.cursor == { row: model.menuRow, col: 2 })
    && (model.screen == { height: 0, width: 0 })
    && (model.selected == [])
    && (model.pageFirstItem == 0)
    && (model.menuRow == 2)

expect
    # TEST: transition from InputAppName to PlatformSelect (empty buffer)
    model = platformSelectModel
    (model.state == PlatformSelect { config: { emptyAppConfig & fileName: "main" } })
    && (model.platformList == ["pf1", "pf2"])
    && (model.packageList == ["pk1", "pk2", "pk3"])
    && (model.menu == ["pf1", "pf2"])
    && (model.fullMenu == ["pf1", "pf2"])
    && (model.cursor == { row: model.menuRow, col: 2 })
    && (model.screen == { height: 0, width: 0 })
    && (model.selected == [])
    && (model.pageFirstItem == 0)
    && (model.menuRow == 2)

expect
    # TEST: transition from PlatformSelect to PackageSelect
    model = packageSelectModel
    (model.state == PackageSelect { config: { emptyAppConfig & fileName: "main", platform: "pf1" } })
    && (model.platformList == ["pf1", "pf2"])
    && (model.packageList == ["pk1", "pk2", "pk3"])
    && (model.menu == ["pk1", "pk2", "pk3"])
    && (model.fullMenu == ["pk1", "pk2", "pk3"])
    && (model.cursor == { row: model.menuRow, col: 2 })
    && (model.screen == { height: 0, width: 0 })
    && (model.selected == [])
    && (model.pageFirstItem == 0)
    && (model.menuRow == 2)

expect
    # TEST: transition from PackageSelect to Confirmation
    model = confirmationModel
    (model.state == Confirmation { config: { emptyAppConfig & fileName: "main", platform: "pf1", packages: [] } })
    && (model.platformList == ["pf1", "pf2"])
    && (model.packageList == ["pk1", "pk2", "pk3"])
    && (model.cursor == { row: model.menuRow, col: 2 })
    && (model.screen == { height: 0, width: 0 })
    && (model.selected == [])
    && (model.pageFirstItem == 0)
    && (model.menuRow == 2)

expect
    # TEST: transition from Confirmation to Finished
    model = finishedModel
    (model.state == Finished { config: { emptyAppConfig & fileName: "main", platform: "pf1", packages: [] } })
    && (model.platformList == ["pf1", "pf2"])
    && (model.packageList == ["pk1", "pk2", "pk3"])
    && (model.cursor == { row: model.menuRow, col: 2 })
    && (model.screen == { height: 0, width: 0 })
    && (model.selected == [])
    && (model.pageFirstItem == 0)
    && (model.menuRow == 2)

## ===============================
## TypeSelect tests

expect
    # TEST: move cursor down from top of menu
    model = typeSelectModel |> applyAction CursorDown
    model.cursor == { row: model.menuRow + 1, col: 2 }

expect
    # TEST: move cursor up from bottom of menu
    model = typeSelectModel |> applyAction CursorDown |> applyAction CursorUp
    model.cursor == { row: model.menuRow, col: 2 }

expect
    # TEST: move cursor up from top of menu
    model = typeSelectModel |> applyAction CursorUp
    model.cursor == { row: model.menuRow + 1, col: 2 }

expect
    # TEST: move cursor down from bottom of menu
    model = typeSelectModel |> applyAction CursorDown |> applyAction CursorDown
    model.cursor == { row: model.menuRow, col: 2 }

## ===============================
## InputAppName tests

expect
    # TEST: InuptAppName to PlatformSelect w/ non-empty buffer
    model = 
        inputAppNameModel 
        |> applyActionWithKey TextInput (KeyPress LowerA)
        |> applyAction TextSubmit
    model.state == PlatformSelect { config: { emptyAppConfig & fileName: "a" } }

expect
    # TEST: InputAppName to PlatformSelect w/ non-empty config
    config = { fileName: "main", platform: "test", packages: ["test"], type: App }
    state = InputAppName { nameBuffer: [], config }
    model = 
        { inputAppNameModel & state }
        |> applyAction TextSubmit
    model.state == PlatformSelect { config }

expect
    # TEST: InputAppName to PlatformSelect w/ empty buffer & different fileName in config
    config = { emptyAppConfig & fileName: "hello" }
    state = InputAppName { nameBuffer: [], config }
    model = { inputAppNameModel & state } |> applyAction TextSubmit
    model.state == PlatformSelect { config: { emptyAppConfig & fileName: "main" } }

expect
    # TEST: exit from InputAppName
    model = inputAppNameModel |> applyAction Exit
    model.state == UserExited

expect
    # TEST: paginate InputAppName
    model = inputAppNameModel |> Controller.paginate
    model == inputAppNameModel

expect
    # TEST: valid text input to InputAppName
    model =
        inputAppNameModel
        |> applyActionWithKey TextInput (KeyPress LowerA)
        |> applyActionWithKey TextInput (KeyPress UpperA)
        |> applyActionWithKey TextInput (KeyPress LowerZ)
        |> applyActionWithKey TextInput (KeyPress UpperZ)
        |> applyActionWithKey TextInput (KeyPress Space)
        |> applyActionWithKey TextInput (KeyPress Hyphen)
        |> applyActionWithKey TextInput (KeyPress Underscore)
        |> applyActionWithKey TextInput (KeyPress Number0)
        |> applyActionWithKey TextInput (KeyPress Number9)
    model.state == InputAppName { nameBuffer: ['a', 'A', 'z', 'Z', '_', '-', '_', '0', '9'], config: emptyAppConfig }

expect
    # TEST: invalid text input to InputAppName
    model =
        inputAppNameModel
        |> applyActionWithKey TextInput (KeyPress Up)
        |> applyActionWithKey TextInput (KeyPress Down)
        |> applyActionWithKey TextInput (KeyPress Left)
        |> applyActionWithKey TextInput (KeyPress Right)
        |> applyActionWithKey TextInput (KeyPress Escape)
        |> applyActionWithKey TextInput (KeyPress Enter)
        |> applyActionWithKey TextInput (KeyPress ExclamationMark)
        |> applyActionWithKey TextInput (KeyPress QuotationMark)
        |> applyActionWithKey TextInput (KeyPress NumberSign)
        |> applyActionWithKey TextInput (KeyPress DollarSign)
        |> applyActionWithKey TextInput (KeyPress PercentSign)
        |> applyActionWithKey TextInput (KeyPress Ampersand)
        |> applyActionWithKey TextInput (KeyPress Apostrophe)
        |> applyActionWithKey TextInput (KeyPress RoundOpenBracket)
        |> applyActionWithKey TextInput (KeyPress RoundCloseBracket)
        |> applyActionWithKey TextInput (KeyPress Asterisk)
        |> applyActionWithKey TextInput (KeyPress PlusSign)
        |> applyActionWithKey TextInput (KeyPress Comma)
        |> applyActionWithKey TextInput (KeyPress FullStop)
        |> applyActionWithKey TextInput (KeyPress ForwardSlash)
        |> applyActionWithKey TextInput (KeyPress Colon)
        |> applyActionWithKey TextInput (KeyPress SemiColon)
        |> applyActionWithKey TextInput (KeyPress LessThanSign)
        |> applyActionWithKey TextInput (KeyPress EqualsSign)
        |> applyActionWithKey TextInput (KeyPress GreaterThanSign)
        |> applyActionWithKey TextInput (KeyPress QuestionMark)
        |> applyActionWithKey TextInput (KeyPress AtSign)
        |> applyActionWithKey TextInput (KeyPress SquareOpenBracket)
        |> applyActionWithKey TextInput (KeyPress Backslash)
        |> applyActionWithKey TextInput (KeyPress SquareCloseBracket)
        |> applyActionWithKey TextInput (KeyPress Caret)
        |> applyActionWithKey TextInput (KeyPress GraveAccent)
        |> applyActionWithKey TextInput (KeyPress CurlyOpenBrace)
        |> applyActionWithKey TextInput (KeyPress VerticalBar)
        |> applyActionWithKey TextInput (KeyPress CurlyCloseBrace)
        |> applyActionWithKey TextInput (KeyPress Tilde)
        |> applyActionWithKey TextInput (KeyPress Delete)
    model.state == InputAppName { nameBuffer: [], config: emptyAppConfig }

expect
    # TEST: backspace with InputAppName
    model =
        inputAppNameModel
        |> applyActionWithKey TextInput (KeyPress LowerA)
        |> applyActionWithKey TextInput (KeyPress LowerB)
        |> applyActionWithKey TextInput (KeyPress LowerC)
        |> applyAction TextBackspace
    model.state == InputAppName { nameBuffer: ['a', 'b'], config: emptyAppConfig }

expect
    # TEST backspace with empty buffer in InputAppName
    model = inputAppNameModel |> applyAction TextBackspace
    model == inputAppNameModel

# expect
#     # TEST: PlatformSelect - moveCursor Up w/ only one item
#     initModel = Model.init ["platform1"] [] |> Model.toInputAppNameState
#     model = Model.toPlatformSelectState initModel
#     newModel = model |> Model.moveCursor Up
#     newModel == model

# expect
#     # TEST: PlatformSelect - moveCursor Down w/ only one item
#     initModel = Model.init ["platform1"] [] |> Model.toInputAppNameState
#     model = Model.toPlatformSelectState initModel
#     newModel = model |> Model.moveCursor Down
#     newModel == model

# expect
#     # TEST: PlatformSelect - moveCursor Up w/ cursor starting at bottom
#     initModel =
#         Model.init ["platform1", "platform2", "platform3"] []
#         |> Model.toInputAppNameState
#         |> Model.toPlatformSelectState
#     model = { initModel &
#         cursor: { row: initModel.menuRow + 2, col: 2 },
#     }
#     newModel = model |> Model.moveCursor Up
#     newModel.cursor.row == model.menuRow + 1

# expect
#     # TEST: PlatformSelect - moveCursor Down w/ cursor starting at top
#     model =
#         Model.init ["platform1", "platform2", "platform3"] []
#         |> Model.toInputAppNameState
#         |> Model.toPlatformSelectState
#     newModel = model |> Model.moveCursor Down
#     newModel.cursor.row == model.menuRow + 1

# expect
#     # TEST: PlatformSelect - moveCursor Up w/ cursor starting at top
#     model =
#         Model.init ["platform1", "platform2", "platform3"] []
#         |> Model.toInputAppNameState
#         |> Model.toPlatformSelectState
#     newModel = model |> Model.moveCursor Up
#     newModel.cursor.row == model.menuRow + 2

# expect
#     # TEST: PlatformSelect - moveCursor Down w/ cursor starting at bottom
#     initModel =
#         Model.init ["platform1", "platform2", "platform3"] []
#         |> Model.toPlatformSelectState
#         |> Model.toPlatformSelectState
#     model = { initModel &
#         cursor: { row: initModel.menuRow + 2, col: 2 },
#     }
#     newModel = model |> Model.moveCursor Down
#     newModel.cursor.row == model.menuRow

# expect
#     # TEST: PlatformSelect to InputAppName
#     initModel =
#         Model.init ["platform1", "platform2", "platform3"] []
#         |> Model.toInputAppNameState
#         |> Model.toPlatformSelectState
#     model = { initModel &
#         state: PlatformSelect { config: { fileName: "a", platform: "b", packages: ["c", "d"], type: App } },
#     }
#     newModel = Model.toInputAppNameState model
#     newModel.state
#     == InputAppName { nameBuffer: ['a'], config: { fileName: "a", platform: "b", packages: ["c", "d"], type: App } }
#     && newModel.cursor.row
#     == newModel.menuRow

# expect
#     # TEST: PlatformSelect to Search
#     initModel =
#         Model.init ["platform1", "platform2", "platform3"] []
#         |> Model.toInputAppNameState
#         |> Model.toPlatformSelectState
#     model = { initModel &
#         state: PlatformSelect { config: { fileName: "a", platform: "b", packages: ["c", "d"], type: App } },
#     }
#     newModel = Model.toSearchState model
#     newModel.state
#     == Search { searchBuffer: [], sender: Platform, config: { fileName: "a", platform: "b", packages: ["c", "d"], type: App } }
#     && newModel.cursor.row
#     == newModel.menuRow

# expect
#     # TEST: PlatformSelect to UserExited
#     model =
#         Model.init [] []
#         |> Model.toInputAppNameState
#         |> Model.toPlatformSelectState
#     newModel = Model.toUserExitedState model
#     newModel.state == UserExited

# expect
#     # TEST: PlatformSelect to PackageSelect
#     initModel =
#         Model.init ["b"] ["c", "d"]
#         |> Model.toInputAppNameState
#         |> Model.toPlatformSelectState
#     model = { initModel &
#         cursor: { row: initModel.menuRow, col: 2 },
#         state: PlatformSelect { config: { fileName: "a", platform: "", packages: ["c"], type: App } },
#     }
#     newModel = Model.toPackageSelectState model
#     newModel.state
#     == PackageSelect { config: { fileName: "a", platform: "b", packages: ["c"], type: App } }
#     && newModel.cursor.row
#     == newModel.menuRow
#     && newModel.selected
#     == ["c"]
