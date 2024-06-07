# Getting your platform or package listed
In order to get your package or platform listed, you must meet a few basic requirements. Once those requirements are met, make a pull request to the roc-start repository, adding your package to the roc-repo.rvn file.

## Requirements for listing:
1) Your package must be hosted on github, and have a github release which is *not* marked as pre-release.
2) Your release must include among its assets a Blake-3 hashed tar.br zip of your repo.
    - Using the github action [hasnep/bundle-roc-library](https://github.com/hasnep/bundle-roc-library) is recommended.

> __Note__
> Some packages and platforms are already included in the repository, but do not currently appear in the TUI app, and cannot be imported via the CLI due to not meeting the requirements above.

## For platform authors
Platform authors may optionally add an app-stub to improve the experience for users creating apps with their platform. This allows `roc-start` to generate a basic implementation of the interface provided to the platform, as well as the application header. Thus the output of `roc-start` can be a fully functional hello-world app, or similar.

To create an app stub, your PR should also include the file: `repository/app-stubs/<your-platform>.roc`. The name of the file should be the name of your platform repository on GitHub. The file should include only the bare minimum roc code to run an application with your platform, and only the code following the application header. 

For example, here is `app-stubs/basic-webserver.roc`:
```roc
import pf.Task exposing [Task]
import pf.Http exposing [Request, Response]

main : Request -> Task Response []
main = \req ->
    Task.ok { status: 200, headers: [], body: Str.toUtf8 "<b>Hello, world!</b>\n" }
```

## Make that pull request!
That's it! Once you have released your package with the required tarball, simply make a PR against this repo, adding your package to the `roc-repo.rvn` file. The format should be as follows:

```roc
{ repo: "your-repo-name", owner: "your-git-username", alias: "sn", platform: <Bool.true/Bool.false>, requires: [] },

# alias: the short name you want to appear in the app header when your package or platform is imported. Should begin with a lowercase letter and include no symbols.

# platform: a roc style Boolean value indicating whether or not your package is a platform.

# requires: *For platforms only* - A `List Str` containing the parameters required by your platform, ie: "main". Should be an empty list for packages.
```

Please ensure that you add your package in alphabetic order, by repo-name first, then by username.