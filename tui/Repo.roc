module [RepositoryEntry, RemoteRepoEntry, CacheRepoEntry]

RepositoryEntry : { alias : Str, version : Str, url : Str }
RemoteRepoEntry : { repo: Str, owner: Str, alias: Str, platform: Bool }
CacheRepoEntry : { repo: Str, owner: Str, alias: Str, version: Str, url: Str, platform: Bool }
