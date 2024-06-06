module [RepositoryEntry, RemoteRepoEntry, CacheRepoEntry]

RepositoryEntry : { alias : Str, version : Str, url : Str, requires : List Str }
RemoteRepoEntry : { repo : Str, owner : Str, alias : Str, platform : Bool, requires : List Str }
CacheRepoEntry : { repo : Str, owner : Str, alias : Str, version : Str, url : Str, platform : Bool, requires : List Str }
