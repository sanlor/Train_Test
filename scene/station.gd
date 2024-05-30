extends Constructions
class_name  Stations

# https://github.com/RichardEllicott/Godot4Snippets/blob/main/snippets/generate_random_username.gd
var names_array = [
	"Asher", "Luna", "Levi", "Stella", "Caleb", "Aurora", "Felix", "Willow",
	"Jasper", "Ruby", "Silas", "Ivy", "Milo", "Hazel", "Ezra", "Penelope",
	"Atticus", "Scarlett", "Sebastian", "Eleanor", "Emma", "Liam", "Olivia",
	"Noah", "Ava", "Sophia", "Isabella", "Mia", "Jackson", "Aiden", "Lucas",
	"Caden", "Harper", "Ethan", "Amelia", "Charlotte", "Benjamin", "Elijah",
	"William", "James", "Ethan", "Olivia", "Liam", "Sophia", "Benjamin", "Ava",
	"Samuel", "Isabella", "Daniel", "Mia", "Alexander", "Charlotte", "Noah", "Emma",
	"Gabriel", "Harper", "Matthew", "Amelia", "Jameson", "Lily", "Zephyr", "Lunaire",
	"Caspian", "Seraphina", "Magnus", "Aurora", "Orion", "Lyric", "Phoenix", "Juniper",
	"Atlas", "Calliope", "Maverick", "Celeste", "Orion", "Aria", "Remy", "Ophelia",
	"Finnegan", "Indira"]

@export var is_placed := false

@onready var map : TileMap = get_parent()

@export var invalid_color := Color("ff000062")
var is_location_invalid := false
var placement_squares : Array[Rect2]

var station_name : String = names_array.pick_random() + " Station" ## THIS SHOULD BE AN RESOURCE. THIS IS TEMP!!

var station_types := [
	preload("res://gamedata/station_h.tres"),
	preload("res://gamedata/station_v.tres"),
]

@export_enum("HORIZONTAL","VERTICAL") var direction : int = 0 :
	set(dir):
		direction = dir
		direction = wrapi(direction, 0, 2)
		pass
	
func _ready():
	add_to_group("saving")
	setup( direction )
	if is_placed: ## placed on the editor
		try_to_place_it()
	
func setup( _station_dir : int ):
	direction = _station_dir
	texture = station_types[direction].atlas_texture.duplicate()
	texture.region.position = station_types[direction].sprite_offset * 16
	
func save() -> Dictionary:
	return {
		"filename" 				: get_scene_file_path(),
		"pos_x" 				: position.x, # Vector2 is not supported by JSON
		"pos_y" 				: position.y,
		"is_placed" 			: is_placed,
		"station_name"			: station_name,
		"direction" 			: direction,
	}

func load( load_data : Dictionary ):
	position.x 				= load_data["pos_x"]
	position.y 				= load_data["pos_y"]
	is_placed 				= load_data["is_placed"]
	direction 				= load_data["direction"]
	station_name			= load_data["station_name"]
	
	
func change():
	setup( direction + 1 )
	
func _process(_delta):
	if not is_placed:
		## check if the signal can be placed
		placement_squares.clear()
		
		var all_signals := get_tree().get_nodes_in_group("Signal")
		var all_stations := get_tree().get_nodes_in_group("Station")
		
		var front_pos 	: Vector2i = station_types[direction].entry_points.front()
		var back_pos 	: Vector2i = station_types[direction].entry_points.back()
		
		# Check if a signal already exist in this position
		for sig in all_signals:
			if sig.position == position and self != sig:
				placement_squares.append( Rect2(-Vector2(8,8), Vector2(16,16) ) )
				
		# Check if a station already exist in this position
		for sta in all_stations:
			if sta.position == position and self != sta:
				placement_squares.append( Rect2(-Vector2(8,8), Vector2(16,16) ) )
		
		# Check if a track already exist in this position. It should for a valid position.
		if not map.is_track_cell_used( map.TRACK_LAYER, map.local_to_map(position) ):
			placement_squares.append( Rect2(-Vector2(8,8), Vector2(16,16) ) )
			pass
		if not map.is_track_cell_used( map.TRACK_LAYER, map.local_to_map(position) + front_pos ):
			placement_squares.append( Rect2(-Vector2(8,8) + ( Vector2(front_pos) * 16 ), Vector2(16,16) ) )
			pass
		if not map.is_track_cell_used( map.TRACK_LAYER, map.local_to_map(position) + back_pos ):
			placement_squares.append( Rect2(-Vector2(8,8) + ( Vector2(back_pos) * 16 ), Vector2(16,16) ) )
			pass
		
		# if the placement squares is empty, the location is valid.
		is_location_invalid = not placement_squares.is_empty()
			
		queue_redraw()

# Check if the signal can be placed on the railroad
func try_to_place_it() -> bool:
	if placement_squares.is_empty():
		queue_redraw()
		is_placed = true
		add_to_group("Station")
		return true
	else:
		return false
		
func _draw():
	if not is_placed:
		if not placement_squares.is_empty():
			for square : Rect2 in placement_squares:
				draw_rect(square, invalid_color, true)
