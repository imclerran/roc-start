# `roc-start` CLI tool 🚀

[![Roc-Lang][roc_badge]][roc_link]

Roc-start is a CLI tool for generating application headers for a new roc application. 

Starting a new roc app which requires multiple packages can be a bit cumbersome, due to the requirement for long urls which cannot be easily memorized. This typically requires opening previous projects which have some of the same dependencies, and copy/pasting from there, or visiting multiple github pages, finding the release page, and copying the url of the required asset.

Roc-start is intended to streamline this process. 

Roc start maintains a repository of package and platform git repos. From this list, it will fetch the latest release URLs for each of these packages and platforms. Then with a simple command, you can generate a new roc application file.

## Two workflows

1) Include the application name, platform, and packages as CLI args:
   - `roc-start my-app basic-cli weaver json`
2) Provide or edit a configuration file:
   - `roc-start config -d`
   - Using `config` allows you to specify a pre-existing config file, or launch an editor to edit a template configuration
  
## Updating platform/package urls

The first time roc-start is run, it will automatically get the latest release urls for the platforms and packages in its repository. These can be updated again at any time by running `roc-start update`.


## roc-start --help
```
A simple CLI tool for starting a new roc project. Specify your platform and packages by name, and roc-start will create a new .roc file with the latest releases.

Usage:
  roc-start [options] <app-name> <platform> <files...>
  roc-start <COMMAND>

Commands:
  config  Use a configuration file to describes the application and dependencies.
  update  Update the platform and package repositories.

Arguments:
  <app-name>  Name your new roc app.
  <platform>  The platform to use.
  <files...>  Any packages to use.

Options:
  -h, --help     Show this help page.
  -V, --version  Show the version.
```


## roc-start config --help
```
Use a configuration file to describes the application and dependencies.

Usage:
  roc-start config [options] <file>

Arguments:
  <file>  The .rvn file to use.

Options:
  -d             Delete config file when finished.
```

[roc_badge]: https://img.shields.io/endpoint?url=https%3A%2F%2Fpastebin.com%2Fraw%2FGcfjHKzb
[roc_link]: https://github.com/roc-lang/roc