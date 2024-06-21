module []

import Model
import Controller

## ==============================
## HELPER FUNCTIONS

applyAction = \model, action ->
    when Controller.applyAction { model: model, action: action } is
        Step newModel -> newModel
        Done newModel -> newModel

## ==============================
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

## =========================
## TEST STATE TRANSITIONS
## =========================

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
    # TEST: transition from InputAppName to PlatformSelect
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

# expect
#     # TEST: Model.init
#     model = Model.init [] []
#     (model.menuRow == 2)
#     && (model.pageFirstItem == 0)
#     && (model.cursor == { row: 2, col: 2 })
#     && (model.state == TypeSelect { config: emptyAppConfig })

# expect
#     # TEST: InputAppName to PlatformSelect w/ empty buffer
#     model = Model.init [] []
#     newModel = model |> Model.toInputAppNameState |> Model.toPlatformSelectState
#     newModel.state
#     == PlatformSelect { config: { emptyAppConfig & fileName: "main" } }
#     && newModel.cursor.row
#     == newModel.menuRow

# expect
#     # TEST: InputAppName to PlatformSelect w/ non-empty buffer
#     initModel = Model.init [] [] |> Model.toInputAppNameState
#     model = { initModel &
#         state: InputAppName { nameBuffer: ['h', 'e', 'l', 'l', 'o'], config: emptyAppConfig },
#     }
#     newModel = Model.toPlatformSelectState model
#     newModel.state
#     == PlatformSelect { config: { emptyAppConfig & fileName: "hello" } }
#     && newModel.cursor.row
#     == newModel.menuRow

# expect
#     # TEST: InputAppName to PlatformSelect w/ non-empty config
#     initModel = Model.init [] [] |> Model.toInputAppNameState
#     model = { initModel &
#         state: InputAppName { nameBuffer: [], config: { fileName: "main", platform: "test", packages: ["test"], type: App } },
#     }
#     newModel = Model.toPlatformSelectState model
#     newModel.state
#     == PlatformSelect { config: { fileName: "main", platform: "test", packages: ["test"], type: App } }
#     && newModel.cursor.row
#     == newModel.menuRow

# expect
#     # TEST: InputAppName to PlatformSelect w/ empty buffer & existing fileName in config
#     initModel = Model.init [] [] |> Model.toInputAppNameState
#     model = { initModel &
#         state: InputAppName { nameBuffer: [], config: { emptyAppConfig & fileName: "hello" } },
#     }
#     newModel = Model.toPlatformSelectState model
#     newModel.state
#     == PlatformSelect { config: { emptyAppConfig & fileName: "main" } }
#     && newModel.cursor.row
#     == newModel.menuRow

# expect
#     # TEST: InputAppName to UserExited
#     model = Model.init [] [] |> Model.toInputAppNameState
#     newModel = Model.toUserExitedState model
#     newModel.state == UserExited

# expect
#     # TEST: paginate InputAppName
#     initModel = Model.init [] [] |> Model.toInputAppNameState
#     model = { initModel & state: InputAppName { nameBuffer: ['a'], config: { fileName: "b", platform: "c", packages: ["d", "e"], type: App } } }
#     newModel = Model.paginate model
#     model == newModel

# expect
#     # TEST: InputAppName - appendToBuffer w/ legal Key
#     model = Model.init [] [] |> Model.toInputAppNameState
#     newModel =
#         model
#         |> Model.appendToBuffer LowerA
#         |> Model.appendToBuffer UpperA
#         |> Model.appendToBuffer LowerZ
#         |> Model.appendToBuffer UpperZ
#         |> Model.appendToBuffer Space
#         |> Model.appendToBuffer Hyphen
#         |> Model.appendToBuffer Underscore
#         |> Model.appendToBuffer Number0
#         |> Model.appendToBuffer Number9
#     newModel.state == InputAppName { nameBuffer: ['a', 'A', 'z', 'Z', '_', '-', '_', '0', '9'], config: emptyAppConfig }

# expect
#     # TEST: InputAppName - appendToBuffer w/ illegal Key
#     model = Model.init [] [] |> Model.toInputAppNameState
#     newModel =
#         model
#         |> Model.appendToBuffer Up
#         |> Model.appendToBuffer Down
#         |> Model.appendToBuffer Left
#         |> Model.appendToBuffer Right
#         |> Model.appendToBuffer Escape
#         |> Model.appendToBuffer Enter
#         |> Model.appendToBuffer ExclamationMark
#         |> Model.appendToBuffer QuotationMark
#         |> Model.appendToBuffer NumberSign
#         |> Model.appendToBuffer DollarSign
#         |> Model.appendToBuffer PercentSign
#         |> Model.appendToBuffer Ampersand
#         |> Model.appendToBuffer Apostrophe
#         |> Model.appendToBuffer RoundOpenBracket
#         |> Model.appendToBuffer RoundCloseBracket
#         |> Model.appendToBuffer Asterisk
#         |> Model.appendToBuffer PlusSign
#         |> Model.appendToBuffer Comma
#         |> Model.appendToBuffer FullStop
#         |> Model.appendToBuffer ForwardSlash
#         |> Model.appendToBuffer Colon
#         |> Model.appendToBuffer SemiColon
#         |> Model.appendToBuffer LessThanSign
#         |> Model.appendToBuffer EqualsSign
#         |> Model.appendToBuffer GreaterThanSign
#         |> Model.appendToBuffer QuestionMark
#         |> Model.appendToBuffer AtSign
#         |> Model.appendToBuffer SquareOpenBracket
#         |> Model.appendToBuffer Backslash
#         |> Model.appendToBuffer SquareCloseBracket
#         |> Model.appendToBuffer Caret
#         |> Model.appendToBuffer GraveAccent
#         |> Model.appendToBuffer CurlyOpenBrace
#         |> Model.appendToBuffer VerticalBar
#         |> Model.appendToBuffer CurlyCloseBrace
#         |> Model.appendToBuffer Tilde
#         |> Model.appendToBuffer Delete
#     newModel == model

# expect
#     # TEST: InputAppName - backspaceBuffer
#     model = Model.init [] [] |> Model.toInputAppNameState
#     newModel =
#         model
#         |> Model.appendToBuffer LowerA
#         |> Model.backspaceBuffer
#     newModel.state == InputAppName { nameBuffer: [], config: emptyAppConfig }

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
