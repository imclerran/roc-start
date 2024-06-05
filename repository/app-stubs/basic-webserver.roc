main : Request -> Task Response []
main = \req ->
    Task.ok { status: 200, headers: [], body: Str.toUtf8 "<b>Hello, world!</b>\n" }