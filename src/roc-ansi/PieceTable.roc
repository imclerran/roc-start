module [
    PieceTable,
    Entry,
    toList,
    length,
    insert,
    delete,
]

## Represents a [Piece table](https://en.wikipedia.org/wiki/Piece_table) which
## is typically used to represent a text document while it is edited in a text
## editor
PieceTable a : {
    original : List a,
    added : List a,
    table : List Entry,
}

# Index into a buffer
Span : { start : U64, len : U64 }

## Represents an index into the original or add buffer
Entry : [Add Span, Original Span]

## Insert `values` into the table at a given `index`.
##
## If index is larger than current buffer, appends to end of file.
insert : PieceTable a, { values : List a, index : U64 } -> PieceTable a
insert = \{ original, added, table }, { values, index } ->

    # Append values to Added buffer
    len = List.len values
    newAdded = List.concat added values

    # New span
    span = Add { start: (List.len newAdded) - len, len }

    # Update entries in piece table, copy accross and split as required
    {
        original,
        added: newAdded,
        table: insertHelp table { index: Num.min index (length table), span } (List.withCapacity (3 + List.len table)),
    }

insertHelp : List Entry, { index : U64, span : Entry }, List Entry -> List Entry
insertHelp = \in, { index, span }, out ->
    when in is
        [] -> out
        [Add current, .. as rest] if index > current.len ->
            insertHelp rest { index: index - current.len, span } (List.append out (Add current))

        [Original current, .. as rest] if index > current.len ->
            insertHelp rest { index: index - current.len, span } (List.append out (Original current))

        [Add current, .. as rest] ->
            lenBefore = index
            lenAfter = current.len - lenBefore

            if lenBefore > 0 && lenAfter > 0 then
                # three spans
                newSpans = [
                    Add { start: current.start, len: lenBefore },
                    span,
                    Add { start: current.start + lenBefore, len: lenAfter },
                ]

                out
                |> List.concat newSpans
                |> List.concat rest
            else if lenBefore > 0 then
                # two spans
                newSpans = [
                    Add { start: current.start, len: lenBefore },
                    span,
                ]

                out
                |> List.concat newSpans
                |> List.concat rest
            else
                # after, two spans
                newSpans = [
                    span,
                    Add { start: current.start + lenBefore, len: lenAfter },
                ]

                out
                |> List.concat newSpans
                |> List.concat rest

        [Original current, .. as rest] ->
            lenBefore = index
            lenAfter = current.len - lenBefore

            if lenBefore > 0 && lenAfter > 0 then
                # three spans
                newSpans = [
                    Original { start: current.start, len: lenBefore },
                    span,
                    Original { start: current.start + lenBefore, len: lenAfter },
                ]

                out
                |> List.concat newSpans
                |> List.concat rest
            else if lenBefore > 0 then
                # two spans
                newSpans = [
                    Original { start: current.start, len: lenBefore },
                    span,
                ]

                out
                |> List.concat newSpans
                |> List.concat rest
            else
                # after, two spans
                newSpans = [
                    span,
                    Original { start: current.start + lenBefore, len: lenAfter },
                ]

                out
                |> List.concat newSpans
                |> List.concat rest

## Calculate the total length when buffer indexes will be converted to a list
length : List Entry -> U64
length = \entries ->

    toLen : Entry -> U64
    toLen = \e ->
        when e is
            Add { len } -> len
            Original { len } -> len

    entries
    |> List.map toLen
    |> List.sum

## Delete the value at `index`
##
## If index is out of range this has no effect.
delete : PieceTable a, { index : U64 } -> PieceTable a
delete = \{ original, added, table }, { index } -> {
    original,
    added,
    table: deleteHelp table index (List.withCapacity (1 + List.len table)),
}

deleteHelp : List Entry, U64, List Entry -> List Entry
deleteHelp = \in, index, out ->
    when in is
        [] -> out
        [Add span, .. as rest] if index >= span.len -> deleteHelp rest (index - span.len) (List.append out (Add span))
        [Original span, .. as rest] if index >= span.len -> deleteHelp rest (index - span.len) (List.append out (Original span))
        [Add span, .. as rest] ->
            isStartOfSpan = index == 0
            isEndOfSpan = index == span.len - 1

            if isStartOfSpan then
                out
                |> List.concat [Add { start: span.start + 1, len: span.len - 1 }]
                |> List.concat rest
            else if isEndOfSpan then
                out
                |> List.concat [Add { start: span.start, len: span.len - 1 }]
                |> List.concat rest
            else
                newSpans = [
                    Add { start: span.start, len: index },
                    Add { start: span.start + index + 1, len: span.len - index - 1 },
                ]

                out
                |> List.concat newSpans
                |> List.concat rest

        [Original span, .. as rest] ->
            isStartOfSpan = index == 0
            isEndOfSpan = index == span.len - 1

            if isStartOfSpan then
                out
                |> List.concat [Original { start: span.start + 1, len: span.len - 1 }]
                |> List.concat rest
            else if isEndOfSpan then
                out
                |> List.concat [Original { start: span.start, len: span.len - 1 }]
                |> List.concat rest
            else
                newSpans = [
                    Original { start: span.start, len: index },
                    Original { start: span.start + index + 1, len: span.len - index - 1 },
                ]

                out
                |> List.concat newSpans
                |> List.concat rest

## Fuse the original and added buffers into a single list
toList : PieceTable a -> List a
toList = \piece -> toListHelp piece []

toListHelp : PieceTable a, List a -> List a
toListHelp = \{ original, added, table }, acc ->
    when table is
        [] -> acc
        [Add span] -> List.concat acc (List.sublist added span)
        [Original span] -> List.concat acc (List.sublist original span)
        [Add span, .. as rest] -> toListHelp { original, added, table: rest } (List.concat acc (List.sublist added span))
        [Original span, .. as rest] -> toListHelp { original, added, table: rest } (List.concat acc (List.sublist original span))

testOriginal : List U8
testOriginal = Str.toUtf8 "ipsum sit amet"

testAdded : List U8
testAdded = Str.toUtf8 "Lorem deletedtext dolor"

testTable : PieceTable U8
testTable = {
    original: testOriginal,
    added: testAdded,
    table: [
        Add { start: 0, len: 6 },
        Original { start: 0, len: 5 },
        Add { start: 17, len: 6 },
        Original { start: 5, len: 9 },
    ],
}

# should fuse buffers to get content
expect toList testTable == Str.toUtf8 "Lorem ipsum dolor sit amet"

# insert in the middle of a Add span
expect
    actual = testTable |> insert { values: ['f', 'o', 'o'], index: 5 } |> toList |> Str.fromUtf8
    actual == Ok "Loremfoo ipsum dolor sit amet"

# insert at the start of a Add span
expect
    actual = testTable |> insert { values: ['f', 'o', 'o'], index: 0 } |> toList |> Str.fromUtf8
    actual == Ok "fooLorem ipsum dolor sit amet"

# insert at the start of a Original span
expect
    actual = testTable |> insert { values: ['f', 'o', 'o'], index: 6 } |> toList |> Str.fromUtf8
    actual == Ok "Lorem fooipsum dolor sit amet"

# insert in the middle of a Original span
expect
    actual = testTable |> insert { values: ['f', 'o', 'o'], index: 8 } |> toList |> Str.fromUtf8
    actual == Ok "Lorem ipfoosum dolor sit amet"

# insert at start of text
expect
    actual = testTable |> insert { values: ['f', 'o', 'o'], index: 0 } |> toList |> Str.fromUtf8
    actual == Ok "fooLorem ipsum dolor sit amet"

# insert at end of text
expect
    actual = testTable |> insert { values: ['f', 'o', 'o'], index: length testTable.table } |> toList |> Str.fromUtf8
    actual == Ok "Lorem ipsum dolor sit ametfoo"

# insert nothing does nothing
expect
    actual = testTable |> insert { values: [], index: 0 } |> toList |> Str.fromUtf8
    actual == Ok "Lorem ipsum dolor sit amet"

# insert at a range larger than current buffer
expect
    actual = testTable |> insert { values: ['X'], index: 999 } |> toList |> Str.fromUtf8
    actual == Ok "Lorem ipsum dolor sit ametX"

# delete at start of text
expect
    actual = testTable |> delete { index: 0 } |> toList |> Str.fromUtf8
    actual == Ok "orem ipsum dolor sit amet"

# delete at end of text, note the index starts from zero
expect
    actual = testTable |> delete { index: (length testTable.table) - 1 } |> toList |> Str.fromUtf8
    actual == Ok "Lorem ipsum dolor sit ame"

# delete at the end of an Add span
expect
    actual = testTable |> delete { index: 5 } |> toList |> Str.fromUtf8
    actual == Ok "Loremipsum dolor sit amet"

# delete at the start of a Add span
expect
    actual = testTable |> delete { index: 11 } |> toList |> Str.fromUtf8
    actual == Ok "Lorem ipsumdolor sit amet"

# delete in the middle of an Add span
expect
    actual = testTable |> delete { index: 13 } |> toList |> Str.fromUtf8
    actual == Ok "Lorem ipsum dlor sit amet"

# delete at the start of a Original span
expect
    actual = testTable |> delete { index: 6 } |> toList |> Str.fromUtf8
    actual == Ok "Lorem psum dolor sit amet"

# delete at the end of a Original span
expect
    actual = testTable |> delete { index: 10 } |> toList |> Str.fromUtf8
    actual == Ok "Lorem ipsu dolor sit amet"

# delete in the middle of a Original span
expect
    actual = testTable |> delete { index: 8 } |> toList |> Str.fromUtf8
    actual == Ok "Lorem ipum dolor sit amet"

# delete out of range, does nothing
expect
    actual = testTable |> delete { index: 9999 } |> toList |> Str.fromUtf8
    actual == Ok "Lorem ipsum dolor sit amet"
