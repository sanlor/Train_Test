extends Constructions

@onready var garage_name = $garage_name
@onready var spr = $spr
@onready var collision_shape_2d = $clickable_area/CollisionShape2D
@onready var map : TileMap = get_parent()

var is_placed := false

var garage_types := [
	load("res://gamedata/garage_down.tres"),
	load("res://gamedata/garage_left.tres"),
	load("res://gamedata/garage_up.tres"),
	load("res://gamedata/garage_right.tres"),
	]

@export_enum("DOWN","LEFT","UP","RIGHT") var direction : int = 0 :
	set(dir):
		direction = dir
		direction = wrapi(direction, 0, 4)

var placement_squares : Array[Rect2]
var is_location_invalid := false
@export var invalid_color := Color("ff000062")

func _ready():
	add_to_group("saving")
	if is_placed: ## placed on the editor
		var result = try_to_place_it()
		assert(result)
	
func setup( _dir : int ):
	direction = _dir
	spr.rotation += PI / 2
	collision_shape_2d.rotation = spr.rotation
	
func change():
	setup( direction + 1 )
	
func get_curr_selection() -> int:
	return direction
	
func get_curr_resource() -> TrackPieces:
	return garage_types[direction]

# Check if the signal can be placed on the railroad
func try_to_place_it() -> bool:
	if placement_squares.is_empty():
		queue_redraw()
		is_placed = true
		add_to_group("Garage")
		map.set_cells_terrain_path( map.TRACK_LAYER, [ map.local_to_map( position + ( garage_types[direction].entry_points.front() * 16 ) ) ], 0, 0 ) ## TODO
		return true
	else:
		return false

## Leftover
func save() -> Dictionary:
	return {}

func load( _load_data : Dictionary ):
	pass

func _process(_delta):
	if not is_placed:
		## check if the signal can be placed
		placement_squares.clear()
		
		var used_tiles 	: Array[Vector2] = garage_types[direction].occupied_tiles
		print(used_tiles)
		for tile : Vector2 in used_tiles:
			
			# Check if a track already exist in this position. It should not.
			if map.is_track_cell_used( map.TRACK_LAYER, map.local_to_map(position + ( tile * 16 ) ) ):
				placement_squares.append( Rect2(-Vector2(8,8) + ( tile * 16 ), Vector2(16,16) ) )
		
		# if the placement squares is empty, the location is valid.
		is_location_invalid = not placement_squares.is_empty()
		#print(placement_squares)
		queue_redraw()

func _draw():
	if not is_placed:
		if not placement_squares.is_empty():
			for square : Rect2 in placement_squares:
				draw_rect(square, invalid_color, true)

func _on_clickable_area_mouse_entered():
	if is_placed :
		garage_name.visible = true

func _on_clickable_area_mouse_exited():
	garage_name.visible = false
