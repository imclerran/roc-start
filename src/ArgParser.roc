module [parse_or_display_message, base_usage, extended_usage]

import weaver.Cli
import weaver.Help
import weaver.Opt
import weaver.Param
import weaver.SubCmd
import rtils.StrUtils
import Theme

## Usage messages
# -----------------------------------------------------------------------------

parse_or_display_message = |args, to_os| Cli.parse_or_display_message(cli_parser, args, to_os)

base_usage = Help.usage_help(cli_parser.config, ["roc-start"], cli_parser.text_style)

extended_usage =
    ansi_code =
        when cli_parser.text_style is
            Color -> "\u(001b)[1m\u(001b)[4m"
            Plain -> ""
    usage_help_str = Help.usage_help(cli_parser.config, ["roc-start"], cli_parser.text_style)
    extended_usage_str =
        when
            Help.help_text(cli_parser.config, ["roc-start"], cli_parser.text_style)
            |> Str.split_first("${ansi_code}Commands:")
        is
            Ok({ after }) -> "${ansi_code}Commands:${after}"
            Err(NotFound) -> ""
    Str.join_with([usage_help_str, extended_usage_str], "\n\n")

# Base CLI parser
# -----------------------------------------------------------------------------

cli_parser =
    separator = ", "
    theme_choices = Theme.theme_names |> Str.join_with(separator)
    { Cli.weave <-
        verbosity: Opt.maybe_str({ short: "v", long: "verbosity", help: "Set the verbosity level to one of: verbose, quiet, or silent." }) |> Cli.map(verbosity_to_log_level),
        theme: Opt.maybe_str({ long: "theme", help: "Set the color theme to use one of: ${theme_choices}." })
        |> Cli.map(color_to_theme),
        subcommand: SubCmd.optional([tui_subcommand, update_subcommand, app_subcommand, package_subcommand, upgrade_subcommand, config_subcommand]),
    }
    |> Cli.finish(
        {
            name: "roc-start",
            version: "v0.6.2",
            authors: ["Ian McLerran <imclerran@protonmail.com>"],
            description: "A simple CLI tool for starting or upgrading roc projects. Specify your platform and packages by name, and roc-start will create a new .roc file or update an existing one with the either the versions you specify, or the latest releases. If no arguments are specified, the TUI app will be launched instead.",
            text_style: Color,
        },
    )
    |> Cli.assert_valid

color_to_theme = |color|
    when color is
        Ok(name) -> Theme.from_name(name) |> Result.map_err(|_| NoTheme)
        Err(NoValue) -> Err(NoTheme)

verbosity_to_log_level = |verbosity|
    when verbosity is
        Ok("verbose") -> Ok(Verbose)
        Ok("quiet") -> Ok(Quiet)
        Ok("silent") -> Ok(Silent)
        _ -> Err(NoLogLevel)

# App and package subcommands
# -----------------------------------------------------------------------------

app_subcommand =
    { Cli.weave <-
        force: Opt.flag({ short: "f", long: "force", help: "Force overwrite of existing file." }),
        filename: Opt.maybe_str({ short: "o", long: "out", help: "The name of the output file (Defaults to `main.roc`). Extension is not required." })
        |> Cli.map(default_filename)
        |> Cli.map(with_extension),
        platform: Opt.maybe_str({ short: "p", long: "platform", help: "The platform to use (Defaults to `basic-cli=latest` unless otherwise configured). Set the version with `--platform <platform>:<version>`." })
        |> Cli.map(platform_name_and_version_with_default),
        packages: Param.str_list({ name: "packages", help: "Any packages to use. Set the version of the package with `<package>:<version>`. If version is not set packages will default to the latest version." })
        |> Cli.map(package_names_and_versions),
    }
    |> SubCmd.finish(
        {
            name: "app",
            description: "Create a new roc app with the specified name, platform, and packages.",
            mapper: App,
        },
    )
default_filename = |filename_res| Result.with_default(filename_res, "main.roc")
with_extension = |filename| if Str.ends_with(filename, ".roc") then filename else "${filename}.roc"

platform_name_and_version_with_default = |platform_res|
    when platform_res is
        Ok(platform) ->
            { before: name, after: version } =
                StrUtils.split_first_if(platform, |c| List.contains([':', '='], c))
                |> Result.with_default({ before: platform, after: "latest" })
            { name, version }

        Err(_) -> { name: "", version: "" }

maybe_platform_name_and_version = |platform_res|
    when platform_res is
        Ok(platform) ->
            { before: name, after: version } =
                StrUtils.split_first_if(platform, |c| List.contains([':', '='], c))
                |> Result.with_default({ before: platform, after: "latest" })
            Ok({ name, version })

        Err(_) -> Err(NoPLatformSpecified)

package_names_and_versions = |packages|
    List.map(
        packages,
        |package|
            { before: name, after: version } =
                StrUtils.split_first_if(package, |c| List.contains([':', '='], c))
                |> Result.with_default({ before: package, after: "latest" })
            { name, version },
    )

upgrade_subcommand =
    { Cli.weave <-
        filename: Opt.maybe_str({ short: "i", long: "in", help: "The name of the input file who's platforms and/or packages should be upgraded." })
        |> Cli.map(default_filename)
        |> Cli.map(with_extension),
        platform: Opt.maybe_str({ short: "p", long: "platform", help: "Specify the platform and version to upgrade to. If ommitted, the platform will not be upgraded. If the specified platform is different than the platform in the upgraded file, the platform will be replaced with the specified one." })
        |> Cli.map(maybe_platform_name_and_version),
        packages: Param.str_list({ name: "packages", help: "List of packages upgrade. If ommitted, all will be upgraded. Version may be specified, or left out to upgrade to the latest version." })
        |> Cli.map(package_names_and_versions),
    }
    |> SubCmd.finish(
        {
            name: "upgrade",
            description: "Upgrade the platform and/or packages in an app or package",
            mapper: Upgrade,
        },
    )

package_subcommand =
    { Cli.weave <-
        force: Opt.flag({ short: "f", long: "force", help: "Force overwrite of existing file." }),
        packages: Param.str_list({ name: "packages", help: "Any packages to use. Set the version of the package with `<package>:<version>`. If version is not set packages will default to the latest version." })
        |> Cli.map(package_names_and_versions),
    }
    |> SubCmd.finish(
        {
            name: "package",
            description: "Create a new roc package main file with all specified packages dependencies.",
            mapper: Package,
        },
    )

# Other subcommands
# -----------------------------------------------------------------------------

tui_subcommand =
    Opt.flag({ short: "s", long: "secret" })
    |> SubCmd.finish(
        {
            name: "tui",
            description: "Use the TUI app to browse and search for platforms and packages.",
            mapper: Tui,
        },
    )

update_subcommand =
    { Cli.weave <-
        do_packages: Opt.flag({ short: "k", long: "packages", help: "Update the package repositories." }),
        do_platforms: Opt.flag({ short: "f", long: "platforms", help: "Update the platform repositories." }),
        do_scripts: Opt.flag({ short: "s", long: "scripts", help: "Update the platform scripts." }),
    }
    |> SubCmd.finish(
        {
            name: "update",
            description: "Update the platform and package repositories and scripts. Update all, or specify which to update.",
            mapper: Update,
        },
    )

config_subcommand =
    { Cli.weave <-
        theme: Opt.maybe_str({ long: "set-default-theme", help: "Set the default color theme to use in the CLI." }),
        verbosity: Opt.maybe_str({ long: "set-verbosity", help: "Set the default verbosity level to use in the CLI." }),
        platform: Opt.maybe_str({ long: "set-default-platform", help: "Set the default platform to use when initializing a new app." }),
    }
    |> SubCmd.finish(
        {
            name: "config",
            description: "Configure the default settings for the roc-start CLI tool.",
            mapper: Config,
        },
    )
