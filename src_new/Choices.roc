module [
    Choices,
    set_filename,
    get_filename,
    set_force,
    get_force,
    set_packages,
    get_packages,
    set_app_platform,
]

import rtils.StrUtils

Choices : [
    App { filename : Str, force : Bool, packages : List { name : Str, version : Str }, platform : { name : Str, version : Str } }, 
    Package { force : Bool, packages : List { name : Str, version : Str } }, 
    Upgrade { filename : Str, packages : List { name : Str, version : Str }, platform : [Err [NoPLatformSpecified], Ok { name : Str, version : Str }] },
    Config [ConfigColors Str, ConfigPlatform Str, ConfigVerbosity Str], 
    Update { do_packages : Bool, do_platforms : Bool, do_scripts : Bool },
    NothingToDo,
]


set_filename : Choices, Str -> Choices
set_filename = |choices, f|
    filename = f |> default_filename |> with_extension
    when choices is
        App(config) -> App({ config & filename})
        Upgrade(config) -> Upgrade({ config & filename})
        _ -> choices

get_filename : Choices -> Str
get_filename = |choices|
    when choices is
        App(config) -> config.filename
        Upgrade(config) -> config.filename
        _ -> ""

set_force : Choices, Bool -> Choices
set_force = |choices, force|
    when choices is
        App(config) -> App({ config & force })
        Package(config) -> Package({ config & force })
        _ -> choices

get_force : Choices -> Bool
get_force = |choices|
    when choices is
        App(config) -> config.force
        Package(config) -> config.force
        _ -> Bool.false

set_packages : Choices, List Str -> Choices
set_packages = |choices, packages|
    when choices is
        App(config) -> App({ config & packages: package_names_and_versions(packages) })
        Package(config) -> Package({ config & packages: package_names_and_versions(packages) })
        Upgrade(config) -> Upgrade({ config & packages: package_names_and_versions(packages) })
        _ -> choices

get_packages : Choices -> List Str
get_packages = |choices|
    when choices is
        App(config) -> List.map(config.packages, |p| p.name)
        Package(config) -> List.map(config.packages, |p| p.name)
        Upgrade(config) -> List.map(config.packages, |p| p.name)
        _ -> []

set_app_platform : Choices, Str -> Choices
set_app_platform = |choices, platform|
    when choices is
        App(config) -> App({ config & platform: platform_name_and_version_with_default(platform) })
        _ -> choices


# Helper functions

default_filename = |filename| if Str.is_empty(filename) then "main.roc" else filename
with_extension = |filename| if Str.ends_with(filename, ".roc") then filename else "${filename}.roc"

package_names_and_versions = |packages|
    List.map(
        packages,
        |package|
            { before: name, after: version } =
                StrUtils.split_first_if(package, |c| List.contains([':', '='], c))
                |> Result.with_default({ before: package, after: "latest" })
            { name, version },
    )

platform_name_and_version_with_default = |platform|
    { before: name, after: version } =
        StrUtils.split_first_if(platform, |c| List.contains([':', '='], c))
        |> Result.with_default({ before: platform, after: "latest" })
    { name, version }