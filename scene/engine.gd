extends Node2D
class_name Train

enum STATE{STOPPED,RUNNING,BRAKING,BROKEN,AT_STATION,WAITING_SIGNAL}
var curr_STATE = STATE.STOPPED

enum ORDER{START,STOP,GARAGE}
var curr_ORDER = ORDER.START



@onready var spr = $spr

@onready var map : TileMap = get_parent()
@onready var debug_line = $debug_line

@export var acceleration := 1.0
@export var braking := 1.5
@export var max_speed := 2.0 ## Max speed that can be reached
@export var min_speed := 0.2 ## Creep speed to reach the station
@export var distance_to_break := 5.0 ## Distance to start braking before reaching a station

@export var train_name := "Lunatic Express" ## THIS SHOULD BE AN RESOURCE. THIS IS TEMP!!

# List of stations that the train should follow
@export var station_list : Array[Node]
@warning_ignore("narrowing_conversion")
var curr_station_target : int = NAN :# current target
	set(station):
		curr_station_target = station
		curr_station_target_changed.emit()

signal curr_station_target_changed

var my_path := []
var last_pos := Vector2.ZERO

var speed := 0.0

var is_on_track := false

@onready var await_path_lookup := false

var wagon_connected_back : Node
var wagon_connected_front : Node

func _ready():
	assert( map != null )
	add_to_group("obstacles")
	add_to_group("saving")
	if last_pos == Vector2.ZERO:
		last_pos = position
	if map.is_track_cell_used( map.TRACK_LAYER, map.local_to_map(position) ):
		is_on_track = true
	else:
		print("train not on track")
		Global.alert.emit(Global.MsgTypes.Error,"Train not on track",position)

func _setup_debug_line( path : PackedVector2Array ):
	debug_line.points = path

func _select_next_station():
	curr_station_target += 1
	if curr_station_target > station_list.size() - 1:
		curr_station_target = 0

func add_station( station_node : Node2D ):
	station_list.append(station_node)
	
func remove_station( station_index : int):
	station_list.remove_at( station_index )
	
func change_station_order( station_index_from : int, station_index_to : int): ## TODO
	assert(station_list.size() >= station_index_from)
	assert(station_list.size() >= station_index_to)
	
	var t = station_list[station_index_from]
	station_list[station_index_from] = station_list[station_index_to] 
	station_list[station_index_to] = t
	
func change_active_station( station_index : int ):
	assert(station_list.size() >= station_index)
	curr_station_target = station_index
	
	my_path.clear()
	curr_STATE = STATE.STOPPED

func _train_wait( seconds : float ):
	await_path_lookup = true
	await get_tree().create_timer(seconds).timeout
	#push_warning("cant reach station")
	#Global.alert.emit(Global.MsgTypes.Info,"Cant reach station",position)
	await_path_lookup = false

func _process(delta):
	if await_path_lookup:
		return
		
	if station_list.is_empty():
		_train_wait(0.5)
		curr_station_target = 0
		curr_STATE = STATE.STOPPED
		return
		
	if my_path.is_empty():
			
		if curr_station_target > station_list.size() - 1:
			push_error("Station Overflow")
			_train_wait(0.5)
			curr_STATE = STATE.STOPPED
			return
		
		my_path = map.get_track_path( map.local_to_map(position), map.local_to_map( station_list[curr_station_target].position) )
		_setup_debug_line(my_path)
		
		if my_path.is_empty():
			_select_next_station()
			_train_wait(0.5)
			curr_STATE = STATE.STOPPED
			
	elif not my_path.is_empty():
		$debug_info.text = str(speed)
		
		if my_path.size() > distance_to_break:
			speed = lerpf(speed, max_speed, acceleration * delta)
			curr_STATE = STATE.RUNNING
		else:
			speed = lerpf(speed, min_speed, braking * delta)
			curr_STATE = STATE.BRAKING
			
		var next_tile : Vector2 = my_path.front() # ensures that the signal doesnt turn red when the train enters it and block itself
		if position.distance_squared_to( my_path.front() ) < 128:
			if my_path.size() > 1:
				next_tile = my_path[1]
		
		var ahead_signal = map.get_signal_at_pos( next_tile ) 
		if ahead_signal != null: # stop the engine if there is a signal in front of it.
			if not ahead_signal.can_pass():
				_train_wait(0.5)
				speed = 0.0
				curr_STATE = STATE.WAITING_SIGNAL
				return
				
		if my_path.size() > 1:
			spr.look_at( my_path[1])
			
		position = position.move_toward(my_path.front(), speed)
		
		if is_zero_approx( position.distance_to(my_path.front()) ):
			last_pos = my_path.pop_front()
			map.notify_obstacle_change()
			_setup_debug_line(my_path)
			
		if my_path.is_empty():
			# reached the station. wait for a while
			speed = 0.0
			curr_STATE = STATE.AT_STATION
			_select_next_station()
			_train_wait(1.0)

func save() -> Dictionary:
	return {
		"filename" 				: get_scene_file_path(),
		"pos_x" 				: position.x, # Vector2 is not supported by JSON
		"pos_y" 				: position.y,
		"curr_station_target" 	: curr_station_target,
		"my_path" 				: my_path,
		"last_pos" 				: var_to_str(last_pos),
		"speed" 				: speed,
		"is_on_track" 			: is_on_track,
		"await_path_lookup" 	: await_path_lookup
	}

func load( load_data : Dictionary ):
	position.x 				= load_data["pos_x"]
	position.y 				= load_data["pos_y"]
	curr_station_target 	= load_data["curr_station_target"]
	my_path 				= load_data["my_path"]
	last_pos 				= str_to_var(load_data["last_pos"])
	speed 					= load_data["speed"]
	is_on_track 			= load_data["is_on_track"]
	await_path_lookup 		= load_data["await_path_lookup"]

func _on_clickable_area_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton:
		if Input.is_action_pressed("click"):
			Global.open_context_menu.emit( self, Global.NodeTypes.Trains )
			#print("cli")
