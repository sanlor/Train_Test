extends Constructions

@export var is_placed := false

@onready var map : TileMap = get_parent()

@onready var debug_label = $debug_label
var force_draw := false

@export var invalid_color := Color("ff000062")
var is_location_invalid := false
var placement_squares : Array[Rect2]

var is_selected := false
var is_blocked := false

var my_region := 0

var signal_types := [
	preload("res://gamedata/signal_down.tres"),
	preload("res://gamedata/signal_left.tres"),
	preload("res://gamedata/signal_up.tres"),
	preload("res://gamedata/signal_right.tres"),
	]
	
@export_enum("DOWN","LEFT","UP","RIGHT") var direction : int = 0 :
	set(dir):
		direction = dir
		direction = wrapi(direction, 0, 4)
		pass

func _ready():
	add_to_group("saving")
	setup( direction )
	map.map_updated.connect( _update_my_data )
	map.train_position_updated.connect( _update_my_data )
	assert(map != null)
	
	if is_placed: ## placed on the editor
		var result = try_to_place_it()
		assert(result)
	
func setup( _signal_dir : int ):
	direction = _signal_dir
	texture = signal_types[direction].atlas_texture.duplicate() # make the atlas texture unique
	texture.region.position = signal_types[direction].sprite_offset * 16
	
func _update_my_data():
	is_blocked = map.check_if_region_is_blocked( global_position )
	if is_blocked:
		texture.region.position = signal_types[direction].sprite_offset * 16
	else:
		texture.region.position = signal_types[direction].active_sprite_offset * 16
		
	my_region = map.signal_get_my_region( position )
	
func change():
	setup( direction + 1 )
	
func get_curr_selection() -> int:
	return direction
	
func get_curr_resource() -> TrackPieces:
	return signal_types[direction]
	
func save() -> Dictionary:
	return {
		"filename" 				: get_scene_file_path(),
		"pos_x" 				: position.x, # Vector2 is not supported by JSON
		"pos_y" 				: position.y,
		"is_placed" 			: is_placed,
		"my_region"				: my_region,
		"direction" 			: direction,
		"is_blocked"			: is_blocked
	}

func load( load_data : Dictionary ):
	position.x 				= load_data["pos_x"]
	position.y 				= load_data["pos_y"]
	is_placed 				= load_data["is_placed"]
	direction 				= load_data["direction"]
	my_region				= load_data["my_region"]
	is_blocked				= load_data["is_blocked"]
	
func _process(_delta):
	if not is_placed:
		## check if the signal can be placed
		placement_squares.clear()
		var all_signals := get_tree().get_nodes_in_group("Signal")
		var all_stations := get_tree().get_nodes_in_group("Station")
		
		var entry_pos : Vector2i = signal_types[direction].entry_points.front()
		var exit_pos : Vector2i = signal_types[direction].exit_points.front()
		
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
		if not map.is_track_cell_used( map.TRACK_LAYER, map.local_to_map(position) + entry_pos ):
			placement_squares.append( Rect2(-Vector2(8,8) + ( Vector2(entry_pos) * 16 ), Vector2(16,16) ) )
			pass
		if not map.is_track_cell_used( map.TRACK_LAYER, map.local_to_map(position) + exit_pos ):
			placement_squares.append( Rect2(-Vector2(8,8) + ( Vector2(exit_pos) * 16 ), Vector2(16,16) ) )
			pass
		
		# if the placement squares is empty, the location is valid.
		is_location_invalid = not placement_squares.is_empty()
			
		queue_redraw()

# Check if the signal can be placed on the railroad
func try_to_place_it() -> bool:
	if placement_squares.is_empty():
		queue_redraw()
		is_placed = true
		add_to_group("Signal")
		return true
	else:
		return false

func can_pass() -> bool: # called by the engines to check if we can pass by it
	return not is_blocked

func _draw():
	if not is_placed:
		if not placement_squares.is_empty():
			for square : Rect2 in placement_squares:
				draw_rect(square, invalid_color, true)
		
func _on_area_2d_mouse_entered():
	if is_placed :
		debug_label.visible = true
		debug_label.text = str(signal_types[direction].ID) + "\n" + str(my_region)


func _on_area_2d_mouse_exited():
	debug_label.visible = false
	is_selected = false
	queue_redraw()
