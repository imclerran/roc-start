module [
    Choices,
    set_filename,
    get_filename,
    set_force,
    get_force,
    set_packages,
    get_packages,
    set_app_platform,
    get_app_platform,
    to_app,
    to_package,
    to_upgrade
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

to_app : Choices -> Choices
to_app = |choices|
    when choices is
        App(config) ->
            App(config)

        Package({ force, packages }) ->
            App({ filename: "main.roc", force, packages, platform: { name: "", version: "" } })

        Upgrade({ filename, packages, platform: maybe_pf }) ->
            platform =
                when maybe_pf is
                    Ok(pf) -> pf
                    Err(_) -> { name: "", version: "" }
            App({ filename, force: Bool.false, packages, platform })

        _ ->
            App({ filename: "main.roc", force: Bool.false, packages: [], platform: { name: "", version: "" } })

to_package : Choices -> Choices
to_package = |choices|
    when choices is
        App({ force, packages }) ->
            Package({ force, packages })

        Package(config) ->
            Package(config)

        Upgrade({ packages }) ->
            Package({ force: Bool.false, packages })

        _ ->
            Package({ force: Bool.false, packages: [] })

to_upgrade : Choices -> Choices
to_upgrade = |choices|
    when choices is
        App({ filename, packages, platform }) ->
            Upgrade({ filename, packages, platform: Ok(platform) })

        Package({ packages }) ->
            Upgrade({ filename: "main.roc", packages, platform: Err(NoPLatformSpecified) })

        Upgrade(config) ->
            Upgrade(config)

        _ ->
            Upgrade({ filename: "main.roc", packages: [], platform: Err(NoPLatformSpecified) })

set_filename : Choices, Str -> Choices
set_filename = |choices, f|
    filename = f |> default_filename |> with_extension
    when choices is
        App(config) -> App({ config & filename })
        Upgrade(config) -> Upgrade({ config & filename })
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

get_packages : Choices -> List { name : Str, version : Str }
get_packages = |choices|
    when choices is
        App(config) -> config.packages
        Package(config) -> config.packages
        Upgrade(config) -> config.packages
        _ -> []

set_app_platform : Choices, Str -> Choices
set_app_platform = |choices, platform|
    when choices is
        App(config) -> App({ config & platform: platform_name_and_version_with_default(platform) })
        _ -> choices

get_app_platform : Choices -> { name : Str, version : Str }
get_app_platform = |choices|
    when choices is
        App(config) -> config.platform
        _ -> { name: "", version: "" }

# Helper functions

default_filename = |filename| if Str.is_empty(filename) then "main.roc" else filename
with_extension = |filename| if Str.ends_with(filename, ".roc") then filename else "${filename}.roc"

package_names_and_versions = |packages|
    List.map(
        packages,
        |package|
            { before: name, after: version } =
                StrUtils.split_first_if(package, |c| List.contains([':', '='], c))
                |> Result.with_default({ before: package, after: "" })
            { name, version },
    )

platform_name_and_version_with_default = |platform|
    { before: name, after: version } =
        StrUtils.split_first_if(platform, |c| List.contains([':', '='], c))
        |> Result.with_default({ before: platform, after: "" })
    { name, version }
