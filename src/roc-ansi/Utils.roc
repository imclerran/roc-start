module [
    linearInterpolation,
    manhattanDistance,
    clamp,
]

linearInterpolation = \a, b -> \value ->
        t = value |> Num.sub a.0 |> Num.div a.1 |> Num.sub a.0
        b.1 |> Num.sub b.0 |> Num.mul t |> Num.add b.0

clamp = \a, b -> \value ->
        value |> Num.min b |> Num.max a

manhattanDistance = \point1, point2 ->
    List.map2 point1 point2 Num.sub
    |> List.map Num.abs
    |> List.walk 0 Num.add

expect manhattanDistance [1, 2, 3] [4, 6, 8] == 12
