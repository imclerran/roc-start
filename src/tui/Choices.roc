module [
    Choices,
    set_filename,
    get_filename,
    set_force,
    get_force,
    set_packages,
    get_packages,
    set_platform,
    get_platform,
    set_updates,
    get_updates,
    set_config_theme,
    get_config_theme,
    set_config_verbosity,
    get_config_verbosity,
    set_config_platform,
    get_config_platform,
    to_app,
    to_package,
    to_upgrade,
    to_update,
    to_config,
]

import rtils.StrUtils

Choices : [
    App { filename : Str, force : Bool, packages : List { name : Str, version : Str }, platform : { name : Str, version : Str } },
    Package { force : Bool, packages : List { name : Str, version : Str } },
    Upgrade { filename : Str, packages : List { name : Str, version : Str }, platform : [Err [NoPLatformSpecified], Ok { name : Str, version : Str }] },
    Config { theme : Result Str [NoValue], platform : Result Str [NoValue], verbosity : Result Str [NoValue] },
    Update { do_packages : Bool, do_platforms : Bool, do_scripts : Bool, do_themes: Bool },
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

to_update : Choices -> Choices
to_update = |choices|
    when choices is
        Update(config) ->
            Update(config)

        _ ->
            Update({ do_packages: Bool.false, do_platforms: Bool.false, do_scripts: Bool.false, do_themes: Bool.false })

to_config : Choices -> Choices
to_config = |choices|
    when choices is
        Config(config) ->
            Config(config)

        _ ->
            Config({ theme: Err(NoValue), platform: Err(NoValue), verbosity: Err(NoValue) })

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

set_platform : Choices, Str -> Choices
set_platform = |choices, platform|
    when choices is
        Upgrade(config) ->
            if Str.is_empty(platform) then
                Upgrade({ config & platform: Err(NoPLatformSpecified) })
            else
                Upgrade({ config & platform: Ok(platform_name_and_version_with_default(platform)) })

        App(config) ->
            App({ config & platform: platform_name_and_version_with_default(platform) })

        _ -> choices

get_platform : Choices -> { name : Str, version : Str }
get_platform = |choices|
    when choices is
        App(config) -> config.platform
        Upgrade(config) ->
            when config.platform is
                Ok(platform) -> platform
                Err(_) -> { name: "", version: "" }

        _ -> { name: "", version: "" }

set_updates : Choices, List Str -> Choices
set_updates = |choices, updates|
    when choices is
        Update(_) ->
            Update(
                {
                    do_platforms: List.contains(updates, "Platforms"),
                    do_packages: List.contains(updates, "Packages"),
                    do_scripts: List.contains(updates, "Scripts"),
                    do_themes: List.contains(updates, "Themes"),
                },
            )

        _ -> choices

get_updates : Choices -> List Str
get_updates = |choices|
    when choices is
        Update({ do_platforms, do_packages, do_scripts, do_themes }) ->
            []
            |> |ul| if do_platforms then List.append(ul, "Platforms") else ul
            |> |ul| if do_packages then List.append(ul, "Packages") else ul
            |> |ul| if do_scripts then List.append(ul, "Scripts") else ul
            |> |ul| if do_themes then List.append(ul, "Themes") else ul

        _ -> []

set_config_theme : Choices, Str -> Choices
set_config_theme = |choices, theme|
    when choices is
        Config(config) -> Config({ config & theme: Ok(theme) })
        _ -> choices

get_config_theme : Choices -> Result Str [NoValue]
get_config_theme = |choices|
    when choices is
        Config(config) -> config.theme
        _ -> Err(NoValue)

set_config_verbosity : Choices, Str -> Choices
set_config_verbosity = |choices, verbosity|
    when choices is
        Config(config) -> Config({ config & verbosity: Ok(verbosity) })
        _ -> choices

get_config_verbosity : Choices -> Result Str [NoValue]
get_config_verbosity = |choices|
    when choices is
        Config(config) -> config.verbosity
        _ -> Err(NoValue)

set_config_platform : Choices, Str -> Choices
set_config_platform = |choices, platform|
    when choices is
        Config(config) ->
            if Str.is_empty(platform) then
                Config({ config & platform: Err(NoValue) })
            else
                Config({ config & platform: Ok(platform) })

        _ -> choices

get_config_platform : Choices -> Result Str [NoValue]
get_config_platform = |choices|
    when choices is
        Config(config) -> config.platform
        _ -> Err(NoValue)

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
