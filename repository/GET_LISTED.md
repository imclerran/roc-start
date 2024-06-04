# Getting your platform or package listed

In order to get your package or platform listed, you must meet a few basic requirements. Once those requirements are met, make a pull request to the roc-start repository, adding your package to the roc-repo.rvn file.

## Requirements for listing:
1) Your package must be hosted on github, and have a github release which is *not* marked as pre-release.
2) Your release must include among its assets a Blake-3 hashed tar.br zip of your repo.
    - Using the github action [hasnep/bundle-roc-library](https://github.com/hasnep/bundle-roc-library) is recommended.

Note that some packages and platforms are already included in the repository, but do not currently appear in the TUI app, and cannot be imported via the CLI due to not meeting the requirements above.

## Make that pull request!
That's it! Once you have released your package with the required tarball, simply make a PR against this repo, adding your package to the `roc-repo.rvn` file. The format should be as follows:

```roc
{ repo: "your-repo-name", owner: "your-git-username", alias: "sn", platform: <Bool.true/Bool.false> },

# alias: the short name you want to appear in the app header when your package or platform is imported. Should begin with a lowercase letter and include no symbols.

# platform: a roc style Boolean value indicating whether or not your package is a platform.
```

Please ensure that you add your package in alphabetic order, by repo-name first, then by username.