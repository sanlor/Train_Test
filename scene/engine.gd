extends Node2D

@onready var spr = $spr

@onready var map : TileMap = get_parent()

var speed := 2.5
var is_on_track := false
var my_path := []
var await_path_lookup := false

func _ready():
	assert( map != null )
	
	if map.is_track_cell_used( map.TRACK_LAYER, map.local_to_map(position) ):
		is_on_track = true
	else:
		print("train not on track")



func _process(delta):
	if await_path_lookup:
		return
		
	if my_path.is_empty():
		var nearest_station = [$"../debug", $"../debug2"].pick_random()
		
		
		my_path = map.get_track_path( map.local_to_map(position), map.local_to_map(nearest_station.position) )
		if my_path.is_empty():
			await_path_lookup = true
			await get_tree().create_timer(0.5).timeout
			push_warning("cant reach station")
			await_path_lookup = false
			
	elif not my_path.is_empty():
		position = position.move_toward(my_path.front(), speed)
		if my_path.size() > 1:
			spr.look_at( my_path[1])
			
		if is_zero_approx( position.distance_to(my_path.front()) ):
			my_path.pop_front()
