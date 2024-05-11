extends Resource
class_name TrackPieces

const WIDTH := 16
const ATLAS := "res://gamedata/tilemap_atlas.tres"

var list := [
	load("res://gamedata/straight_h.tres"),
	load("res://gamedata/straight_v.tres"),
	
	load("res://gamedata/curve_UL.tres"),
	load("res://gamedata/curve_UR.tres"),
	load("res://gamedata/curve_DL.tres"),
	load("res://gamedata/curve_DR.tres"),
	
	load("res://gamedata/crossroad.tres"),
	
	load("res://gamedata/signal_right.tres"),
	load("res://gamedata/signal_left.tres"),
	load("res://gamedata/signal_down.tres"),
	load("res://gamedata/signal_up.tres"),
	
	load("res://gamedata/deadend_down.tres"),
	load("res://gamedata/deadend_left.tres"),
	load("res://gamedata/deadend_right.tres"),
	load("res://gamedata/deadend_up.tres"),
	
	load("res://gamedata/t_junction_down.tres"),
	load("res://gamedata/t_junction_left.tres"),
	load("res://gamedata/t_junction_right.tres"),
	load("res://gamedata/t_junction_up.tres"),
	]

@export var ID : String
@export var sprite_offset : Vector2 ## Main sprite on the tileset
@export var active_sprite_offset : Vector2 ## Active sprite on the tileset (Ex.: a lit semaphore)

@export var entry_points 	: Array[Vector2] ## where the point a train can enter the tile. used for the flood fill algorithm
@export var exit_points 	: Array[Vector2] ## where the point a train can exit the tile. used for the flood fill algorithm

func get_image() -> AtlasTexture:
	var atlas : AtlasTexture = load(ATLAS).duplicate()
	atlas.region.position = sprite_offset * WIDTH
	return atlas
	
func get_resource_from_offset( offset : Vector2 ):
	for res : TrackPieces in list:
		if res.sprite_offset == offset:
			return res
			
	return null
	

	
