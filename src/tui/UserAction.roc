module [UserAction]

import Keys exposing [Key]

UserAction : [
    Cancel,
    ClearFilter,
    CursorDown,
    CursorUp,
    Exit,
    Finish,
    GoBack,
    MultiConfirm,
    MultiSelect,
    VersionSelect,
    NextPage,
    PrevPage,
    Search,
    SearchGo,
    SingleSelect,
    TextInput Key,
    TextBackspace,
    TextSubmit,
    SetFlags,
    Secret,
    None,
]