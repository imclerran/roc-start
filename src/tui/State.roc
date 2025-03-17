module [State]

import Choices exposing [Choices]

State : [
    MainMenu { choices : Choices },
    SettingsMenu { choices : Choices },
    SettingsSubmenu { choices : Choices, submenu : [Theme, Verbosity] },
    InputAppName { name_buffer : List U8, choices : Choices },
    Search { search_buffer : List U8, choices : Choices, prior_sender : State },
    PlatformSelect { choices : Choices },
    PackageSelect { choices : Choices },
    VersionSelect { choices : Choices, repo : { name : Str, version : Str } },
    UpdateSelect { choices : Choices },
    Confirmation { choices : Choices },
    ChooseFlags { choices : Choices },
    Finished { choices : Choices },
    Splash { choices : Choices },
    UserExited,
]