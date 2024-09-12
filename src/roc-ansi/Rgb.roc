module [Rgb, Hex, fromHex]

import Utils

Rgb : (U8, U8, U8)

Hex : U32

fromHex : Hex -> Rgb
fromHex = \hex ->
    u24 = (Utils.clamp 0x000000 0xFFFFFF) hex
    c = \a -> u24 |> Num.shiftRightBy (Num.mul 8 (2 - a)) |> Num.bitwiseAnd 0xFF |> Num.toU8
    (c 0, c 1, c 2)

expect fromHex 0xFF0000 == (255, 0, 0)
expect fromHex 0x00FF00 == (0, 255, 0)
expect fromHex 0x0000FF == (0, 0, 255)
expect fromHex 0xFFFFFFFF == (255, 255, 255)
