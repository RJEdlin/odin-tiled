package tiled_raylib

import fmt "core:fmt"
import os "core:os"
import strings "core:strings"
import rl "vendor:raylib"

import tiled ".."

Error :: enum {
	None = 0,
	Generic_Error,
	Nothing_To_Load,
	Path_Read_Error,
}

Map_Bag :: struct {
	path: string,
	t_map: ^tiled.Map,
	atlases: []rl.Texture2D,
	layer_draw_buffers: []rl.RenderTexture2D,
	gid_lookups: []Gid_Lookup,
}

Gid_Lookup :: struct {
	i_atlas: int,
	rect: rl.Rectangle,
}


// Grabs everything for the map, the data of which is at the provided path
// `alloc` is used for creating the buffers within the bag.
load_map_bag_for :: proc(path: string, alloc := context.allocator) -> (Map_Bag, Error) {
	//zzz
	bag := Map_Bag {path = path}

	tm, ok := tiled.parse_tilemap_and_tilesets(path, alloc)
	if !ok {
		return bag, .Generic_Error
	}
	bag.t_map = &tm

	a, err := load_atlases_for(path, tm, alloc)
	if err != nil {
		if err != .Nothing_To_Load {
			return bag, err
		}
	}
	bag.atlases = a

	bag.layer_draw_buffers = make([]rl.RenderTexture2D, len(tm.layers), alloc)
	for layer, i in tm.layers {
		#partial switch layer.type {
		case .ImageLayer:
			//zzz
			panic("Don't use ImageLayers yet")
		case .ObjectLayer:
		case .TileLayer:
			h := layer.height * tm.tile_height
			w := layer.width * tm.tile_width
			bag.layer_draw_buffers[i] = rl.LoadRenderTexture(h, w)
		case:
			panic("Invalid case")
		}
	}

	sum: int
	for ts in tm.tilesets {
		sum += int(ts.tile_count)
	}
	bag.gid_lookups = make([]Gid_Lookup, sum + 1, alloc)
	for tileset, i in tm.tilesets {
		cutoff := tileset.first_gid + tileset.tile_count
		for gid, n in tileset.first_gid..<cutoff {
			bag.gid_lookups[gid] = Gid_Lookup {
				i_atlas = i,
				rect = rl.Rectangle {
					x = f32((i32(n) % tileset.columns) * tileset.tile_width),
					y = f32((i32(n) / tileset.columns) * tileset.tile_height),
					width = f32(tileset.tile_width),
					height = f32(tileset.tile_height),
				},
			}
		}
	}

	cook_layer_draw_buffers(bag)

	return bag, .None
}

cook_layer_draw_buffers :: proc(bag: Map_Bag) {
	for layer, i in bag.t_map^.layers {
		if layer.type == .TileLayer {
			rl.BeginTextureMode(bag.layer_draw_buffers[i])
			draw_layer(bag, i)
			rl.EndTextureMode()
		}
	}
}

unload_map_bag :: proc(bag: ^Map_Bag) {
	panic("WTF YOU DIDN'T IMPLEMENT UNLOADING THE BAG")
}

/** Remember to unload the atlases created using `unload_atlases` when they are no longer needed
 *
 */
load_atlases_for :: proc(path_map: string, t_map: tiled.Map, alloc := context.allocator) -> ([]rl.Texture2D, Error) {
	if len(t_map.tilesets) == 0 {
		return nil, .Nothing_To_Load
	}
	arr := make([]rl.Texture2D, len(t_map.tilesets), alloc)
	dir, _ := os.split_path(path_map)

	for ts, i in t_map.tilesets {
		fmt.println(ts, i)
		path, err1 := os.join_path({dir, ts.image}, context.temp_allocator)
		if err1 != nil {
			return arr, .Path_Read_Error
		}

		c_path, err2 := strings.clone_to_cstring(path, context.temp_allocator)
		if err2 != nil {
			return arr, .Generic_Error
		}

		arr[i] = rl.LoadTexture(c_path)
	}
	fmt.println("Succeeded")
	return arr, .None
}

unload_atlases :: proc(atlases: []rl.Texture2D) {
	for t in atlases {
		rl.UnloadTexture(t)
	}
}

// Must be called between Begin and End calls
draw_layer :: proc(bag: Map_Bag, i_layer: int, origin := rl.Vector2 {}, rot: f32 = 0, tint := rl.WHITE) {
	layer := bag.t_map^.layers[i_layer]
	tile_width := bag.t_map^.tile_width
	tile_height := bag.t_map^.tile_height
	for i in 0..<layer.height {
		for j in 0..<layer.width {
			gid := layer.data[j * layer.width + i]
			if gid == 0 {
				continue
			}

			i_atlas := bag.gid_lookups[gid].i_atlas
			src_rect := bag.gid_lookups[gid].rect
			atlas := bag.atlases[i_atlas]

			dst_rect := rl.Rectangle{
				x = f32(i * tile_width),
				y = f32(j * tile_height),
				width = f32(tile_width),
				height = f32(tile_height),
			}

			rl.DrawTexturePro(atlas, src_rect, dst_rect, origin, rot, tint)
		}
	}
}
