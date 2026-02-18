package main

import tiled "../tiled"
import rl "vendor:raylib"
import fmt "core:fmt"

main :: proc() {
    rl.InitWindow(320, 480, "Tiled Example")

    tiled_map, ok := tiled.parse_tilemap("tileMap.json")
	if !ok {
		fmt.eprintln("parse_tilemap: failed")
	}

    tileset_texture := rl.LoadTexture("tiles.png")

    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        draw_map(tiled_map, tileset_texture)
        rl.EndDrawing()
    }
}

draw_map :: proc(t_map: tiled.Map, texture: rl.Texture2D) {
    tile_width: i32 = 16
    tile_height: i32 = 16

    for layer in t_map.layers {
        for y in 0..<layer.height {
            for x in 0..<layer.width {
                gid := layer.data[y * layer.width + x]
                if gid == 0 {
                    continue
                }
                tile_x := i32(gid - 1) % (texture.width / tile_width)
                tile_y := i32(gid - 1) / (texture.width / tile_height)

                src_rect := rl.Rectangle{
                    x = f32(tile_x * tile_width),
                    y = f32(tile_y * tile_height),
                    width = f32(tile_width),
                    height = f32(tile_height),
                }

                dst_rect := rl.Rectangle{
                    x = f32(x * tile_width),
                    y = f32(y * tile_height),
                    width = f32(tile_width),
                    height = f32(tile_height),
                }

                rl.DrawTexturePro(texture, src_rect, dst_rect, rl.Vector2{0, 0}, 0, rl.WHITE)
            }
        }
    }
}
