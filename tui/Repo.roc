module [RepositoryEntry, RemoteRepoEntry]

RepositoryEntry : { alias : Str, version : Str, url : Str }
RemoteRepoEntry : { repo: Str, owner: Str, alias: Str, platform: Bool }
CacheRepoEntry : { repo: Str, alias: Str, version: Str, url: Str } # repo, alias, version, url
