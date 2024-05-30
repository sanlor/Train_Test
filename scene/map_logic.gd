extends TileMap
# https://escada-games.itch.io/randungeon/devlog/261991/how-to-use-godots-astar2d-for-path-finding

signal map_updated # called everytime the track map is changed and signals, trains and etc should be notified
signal train_position_updated # called everytime a train moves and signals need to check if its region is being blocked

const TRACK_LAYER := 0
const STATION_LAYER := 1
const SIGNAL_LAYER := 2
const TEMP_LAYER := 3

enum MODE{NONE,ADD_TRACK,ADD_SIGNAL,ADD_STATION,ADD_TRAIN,ADD_GARAGE,DELETE,DELETE_TRACK}
var curr_MODE := MODE.NONE

var map_size := Rect2( 0, 0, 64, 64 )

var start_drag := Vector2.ZERO
@onready var track_placement := AStarGrid2D.new()
#@onready var astar_track_blocks := AStar2D.new() # used to pathfind using signal blocks
## Pathfind
@onready var astar_track_tiles := AStar2D.new() # used to pathfind using the trackpieces

@export var baseline_cost := 1.0
@export var signal_cost := 10.0
@export var station_cost := 10.0
@export var obstacle_cost := 50.0

var track_placement_path := Array()


@onready var trackpieces := TrackPieces.new()

var track_regions := Dictionary() # Region system
var track_signals := Dictionary() # Assignement signals to tracks

var disabled_tiles := Array()
var disabled_regions := Array()

## Item Placement
@export_category("Selection")
@export var selection_color 			:= Color("0cb60abd")
@export var removal_selection_color 	:= Color("ff4242ba")

var hover_node : Node
var hover_node_memory := 0 # Index for the rotation for the hovernode

var last_mouse_map_position 	: Vector2i
var temp_path 					: Array[Vector2i]

var signal_list					:= Dictionary()
var station_list				:= Dictionary()
var object_list					:= Dictionary() # Objects are Trains, Wagons, Rocks

var selected_pos := Vector2i()

@onready var map_overlay = $"../map_overlay"

func _ready():
	_init_astar_track_tiles()
	Global.map_loaded.connect( _init_astar_track_tiles )

func change_mode( mode : MODE):
	curr_MODE = mode
	if hover_node != null:
		hover_node.queue_free()
	hover_node_memory = 0
	clear_layer(TEMP_LAYER)
	

func _init_astar_track_tiles():
	@warning_ignore("narrowing_conversion")
	astar_track_tiles.reserve_space( map_size.end.x * map_size.end.y )
	_update_astar_track_tiles()
	
func _update_astar_track_tiles():
	var start := Time.get_ticks_msec()
	astar_track_tiles.clear()
	track_regions.clear()
	track_signals.clear()
	
	for tile : Vector2i in get_used_cells( TRACK_LAYER ):
		# all track pieces have a point from the start. They arent connected right now.
		astar_track_tiles.add_point( _get_astar_index(tile), map_to_local(tile) )
		
	## floodfill
	var unchecked_tiles 	:= get_used_cells( TRACK_LAYER ) # all used tiles
	var checked_tiles 		:= [] # tiles already checked by the floodfill algo
	var queue_tiles 		:= [] # queues to be checked by the algorithm
	var regions				:= {} # dictionary with all regions filled by the algo
	var region_index 		:= 0 # index used by the dictionary
	var signals 			:= get_tree().get_nodes_in_group("Signal") #get_used_cells( SIGNAL_LAYER ) # all signals / semaphores added to the game
	var signals_pos			:= {}
	
	for s : Node2D in signals:
		signals_pos[s] = local_to_map(s.position)
		
	while not unchecked_tiles.is_empty(): ## Infinite loop warning
		queue_tiles.append( unchecked_tiles.pop_back() )
		regions[region_index] = Array()
		
		while not queue_tiles.is_empty(): ## Infinite loop warning
			var current = queue_tiles.pop_back()
			checked_tiles.append(current)
			unchecked_tiles.erase(current)
			var directions_to_check := []
			
			# If this cell has a signal, skip it.
			if signals_pos.values().has( current ):
				continue
			else:
				# get all directions that the track piece is connected ## TODO maybe I can get this info from the tilemap itself?
				var resource = trackpieces.get_resource_from_offset( get_cell_atlas_coords( TRACK_LAYER, current ) )
				if resource == null:
					push_error("Invalid resource at ", current, ", Atlas ", get_cell_atlas_coords( TRACK_LAYER, current ))
					continue
					
				directions_to_check = resource.exit_points # Should return an array of vector with directions to check
				
			regions[region_index].append( current )
			
			for dir : Vector2i in directions_to_check:
				var next_tile = current + dir
				#var tile_resource = trackpieces.get_resource_from_offset( get_cell_atlas_coords( TRACK_LAYER, next_tile ) ) ## TODO do not delete
				
				if not map_size.has_point( next_tile ): # If its OOB, go to the next tile
					print("OOB ",next_tile)
					continue
				if checked_tiles.has( next_tile ): # if tile is already checked, go to the next tile 
					continue
				if not is_track_cell_used( TRACK_LAYER, next_tile ):# if tile is null, go to the next tile
					print("cell not used ",next_tile)
					continue
				if signals_pos.values().has( next_tile ): # if the next tile is a signal, treat as a boundarie
					#print("signal")
					continue
					
				#The tile is valid, connect the point and add the next tile to the queue
				queue_tiles.append( next_tile )
				astar_track_tiles.connect_points( _get_astar_index(current), _get_astar_index(next_tile), true)
		
		if not regions[region_index].is_empty():
			region_index += 1 # after a loop on all avaiable tiles within the boundaries, add on to the index.
	
	## Set the signal regions
	for s : Node2D in signals:
		# find the region for the track in front of the signal.
		var signal_res		: TrackPieces = s.get_curr_resource()
		var signal_exit 	: Vector2i = signal_res.exit_points.front() # Signal only have one exit point.
		var signal_entry 	: Vector2i = signal_res.entry_points.front() # Signal only have one entry point.
		
		for region_id in regions:
			if regions[region_id].has( signal_exit + signals_pos[s] ):
				if regions[region_id].has( signal_entry + signals_pos[s] ): # if the entry ant the exit are on the same region, this signal is invalid.
					track_signals[ signals_pos[s] ] = INF
					#break
				track_signals[ signals_pos[s] ] = region_id # add the region for this signal
				regions[region_id].append( signals_pos[s] ) # add signal pos to the region
				astar_track_tiles.connect_points( _get_astar_index(signal_entry + signals_pos[s] ), _get_astar_index(signals_pos[s] ), 	false) # connect the astar points in a unidirectional way.
				astar_track_tiles.connect_points( _get_astar_index(signals_pos[s] ), _get_astar_index(signal_exit + signals_pos[s] ), 	false) # connect the astar points in a unidirectional way.
				break
		
	track_regions = regions
	print("regions: ", regions.size())
	
	Global.changed_debug_display.emit() ## DEBUG - Check the node map_overlay
	
	_check_track_obstacles()
	assert( unchecked_tiles.is_empty() ) # At the end, all used tiles must be checked
	map_updated.emit()
	if Global.show_run_time:
		print(self, "astar update took ",Time.get_ticks_msec() - start," msecs. ") 

func update_obstacle_list():
	signal_list.clear()
	station_list.clear()
	object_list.clear()
	for node : Node in get_tree().get_nodes_in_group("Station"): # Update the obstacle_pos.
		station_list[local_to_map(node.position)] = node
	for node : Node in get_tree().get_nodes_in_group("Signal"): # Update the obstacle_pos.
		signal_list[local_to_map(node.position)] = node
	for node : Node in get_tree().get_nodes_in_group("obstacles"): # Update the obstacle_pos.
		object_list[local_to_map(node.position)] = node

func _check_track_obstacles(): # Check for trains, wagons and obstacles on the track, flip the signals from red to green.
	var start := Time.get_ticks_usec()
	update_obstacle_list()
		
	disabled_tiles.clear()
	disabled_regions.clear()
	
	var track_tiles 	:= get_used_cells( TRACK_LAYER ) ## all used tiles
	#var obstacles		:= get_tree().get_nodes_in_group("obstacles")
	#var stations		:= get_tree().get_nodes_in_group("Station") 
	
	for tile : Vector2i in track_tiles:
		astar_track_tiles.set_point_weight_scale( _get_astar_index( tile ), baseline_cost) # Baseline weight
	
	for s : Vector2i in track_signals.keys():
		astar_track_tiles.set_point_weight_scale( _get_astar_index( s ), signal_cost) # add a penalty for every signal
		
	for station : Vector2i in station_list.keys():
		if astar_track_tiles.has_point( _get_astar_index( station ) ): # extra check to aboid OOB errors
			astar_track_tiles.set_point_weight_scale( _get_astar_index( station ), station_cost) # add a penalty for every station
		else:
			# OOB
			breakpoint
	
	for pos : Vector2i in object_list.keys():  # check for obstacles
		if astar_track_tiles.has_point( _get_astar_index( pos ) ):
			astar_track_tiles.set_point_weight_scale( _get_astar_index( pos ), obstacle_cost)
			disabled_tiles.append( pos )
		else:
			# OOB
			breakpoint ## Trains cant be outside the track. if it happens, you get this BP
			
	# Now we block a whole region assuming there is more than one region.
	if track_regions.size() > 1:
		for region : int in track_regions:
			for disabled_tile : Vector2i in disabled_tiles:
				if track_regions[region].has(disabled_tile):
					for tile : Vector2i in track_regions[region]:
						astar_track_tiles.set_point_weight_scale( _get_astar_index( tile ), obstacle_cost)
						
					if not disabled_regions.has(region):
						disabled_regions.append(region)
					continue
					
	Global.changed_debug_display.emit() ## DEBUG - Check the node map_overlay
	if Global.show_run_time:
		print(self, " _check_track_obstacles() took ",Time.get_ticks_usec() - start," usecs. ") 

func notify_obstacle_change(): # during the train movement or adding new trains to the track. Should be called lots of times.
	train_position_updated.emit()
	_check_track_obstacles()

func is_track_cell_used(layer, pos : Vector2i):
	var track_celldata := get_cell_tile_data( layer, pos )
	if track_celldata != null:
		return true
	else:
		return false

func _get_astar_index( pos : Vector2 ) -> int:
	return int( pos.y * map_size.end.x + pos.x  )
	
func get_track_path(src, dst) -> PackedVector2Array:
	_update_astar_track_tiles()
	return astar_track_tiles.get_point_path( _get_astar_index(src), _get_astar_index(dst) )

func clear_everything():
	clear()
	for node in get_children():
		node.queue_free()

func _input(event):
	if event.is_action_pressed("rclick"):
		change_mode(MODE.NONE)

func _process(_delta):
	if Input.is_key_pressed(KEY_V): ## DEBUG
		_update_astar_track_tiles()
		
	match curr_MODE:
		MODE.ADD_TRACK:
			if Input.is_action_just_pressed("click"):
				last_mouse_map_position = local_to_map( get_global_mouse_position() )
			if Input.is_action_pressed("click"):
				clear_layer(TEMP_LAYER)
				temp_path.clear()
				var mouse_map_position := local_to_map( get_global_mouse_position() )
				@warning_ignore("narrowing_conversion")
				var distance : int = (last_mouse_map_position - mouse_map_position ).length()
				var dir := ( last_mouse_map_position - mouse_map_position )
				
				temp_path.append( last_mouse_map_position )
				if abs(dir.x) > abs(dir.y):
					for tile in distance:
						tile += 1
						temp_path.append( Vector2i(last_mouse_map_position.x - (tile * dir.sign().x), last_mouse_map_position.y) )
				else:
					for tile in distance:
						tile += 1
						temp_path.append( Vector2i( last_mouse_map_position.x, last_mouse_map_position.y - (tile * dir.sign().y) ) )
				set_cells_terrain_path( TEMP_LAYER, temp_path, 0,0 )
				
			if Input.is_action_just_released("click"):
				clear_layer(TEMP_LAYER)
				set_cells_terrain_path( TRACK_LAYER, temp_path, 0,0 )
				_update_astar_track_tiles() ## TODO add incremental updates to the astar
			
		MODE.ADD_SIGNAL:
			if hover_node == null:
				hover_node = load("res://scene/signal.tscn").instantiate()
				
				hover_node.direction = hover_node_memory
				add_child(hover_node)
				
			var mouse_tile_center : Vector2 = map_to_local( local_to_map( get_global_mouse_position() ) )
			hover_node.position = mouse_tile_center ## Move the ghost to the center of the tile
			
			if Input.is_action_just_pressed("rotate"):
				hover_node.change() ## Change the node (rotate, etc)
				hover_node_memory = hover_node.get_curr_selection()
				
			if Input.is_action_just_pressed("click"):
				if hover_node.try_to_place_it():
					hover_node = null
					notify_obstacle_change()
					#curr_MODE = MODE.NONE
				else:
					print("Invalid location")
					
					Global.alert.emit(Global.MsgTypes.Alert,"Invalid location",get_global_mouse_position())
					
		MODE.ADD_STATION:
			if hover_node == null:
				hover_node = load("res://scene/station.tscn").instantiate()
				if hover_node_memory != null:
					hover_node.direction = hover_node_memory
				add_child(hover_node)
				
			var mouse_tile_center : Vector2 = map_to_local( local_to_map( get_global_mouse_position() ) )
			hover_node.position = mouse_tile_center ## Move the ghost to the center of the tile
			
			if Input.is_action_just_pressed("rotate"):
				hover_node.change() ## Change the node (rotate, etc)
				hover_node_memory = hover_node.get_curr_selection()
				
			if Input.is_action_just_pressed("click"):
				if hover_node.try_to_place_it():
					hover_node = null
					notify_obstacle_change()
					#curr_MODE = MODE.NONE
				else:
					print("Invalid location")
					Global.alert.emit(Global.MsgTypes.Alert,"Invalid location",get_global_mouse_position())
		MODE.ADD_GARAGE:
			if hover_node == null:
				hover_node = load("res://scene/garage.tscn").instantiate()
				if hover_node_memory != null:
					#hover_node.station_type = hover_node_memory
					pass
				add_child(hover_node)
				
			var mouse_tile_center : Vector2 = map_to_local( local_to_map( get_global_mouse_position() ) )
			hover_node.position = mouse_tile_center ## Move the ghost to the center of the tile
			
			if Input.is_action_just_pressed("rotate"):
				hover_node.change() ## Change the node (rotate, etc)
				hover_node_memory = hover_node.get_curr_selection()
				
			if Input.is_action_just_pressed("click"):
				if hover_node.try_to_place_it():
					hover_node = null
					#curr_MODE = MODE.NONE
				else:
					print("Invalid location")
					Global.alert.emit(Global.MsgTypes.Alert,"Invalid location",get_global_mouse_position())
		MODE.ADD_TRAIN:
			var mouse_tile_center : Vector2 = map_to_local( local_to_map( get_global_mouse_position() ) )
			var color := Color(Color.GREEN,0.4)
			var can_be_placed := true
			if not is_track_cell_used( TRACK_LAYER, local_to_map( get_global_mouse_position() ) ):
				color = Color(Color.RED,0.4)
				can_be_placed = false
	
			map_overlay.highlight_square( Rect2( mouse_tile_center + Vector2(-8,-8), Vector2(16,16) ), color, true )
			
			if Input.is_action_just_pressed("click") and can_be_placed:
				var train : Node2D = preload("res://scene/engine.tscn").instantiate()
				train.position = mouse_tile_center
				add_child(train)
				map_overlay.clear_highlight()
				notify_obstacle_change()
				change_mode(MODE.NONE)
				
		MODE.DELETE:
			var pos := local_to_map( get_global_mouse_position() )
			if _check_node_at_pos( pos ):
				map_overlay.highlight_square(Rect2( map_to_local(pos) - Vector2(8,8), Vector2(16,16) ), removal_selection_color )
			else:
				map_overlay.clear_highlight()
				
			if Input.is_action_just_pressed("click"):
				var node = _get_node_at_pos( pos )
				if node is Node:
					node.queue_free()
					update_obstacle_list()
		MODE.DELETE_TRACK:
			var pos := local_to_map( get_global_mouse_position() )
			
			if get_used_cells(TRACK_LAYER).has(pos):
				map_overlay.highlight_square(Rect2( map_to_local(pos) - Vector2(8,8), Vector2(16,16) ), removal_selection_color )
			else:
				map_overlay.clear_highlight()
			
			if Input.is_action_just_pressed("click"):
				#erase_cell(TRACK_LAYER, pos)
				set_cells_terrain_connect(TRACK_LAYER, [pos], 0, -1)
				_update_astar_track_tiles() ## TODO add incremental updates to the astar
	
func check_if_region_is_blocked( pos : Vector2 ) -> bool:
	return disabled_regions.has( signal_get_my_region( pos ) )
	
func signal_get_my_region( pos : Vector2 ) -> int:
	var map_pos := local_to_map(pos) # Vector2i always
	return track_signals.get(map_pos)
	
func _check_node_at_pos( pos : Vector2i ) -> bool:
	if signal_list.keys().has( pos ):
		return true
	elif station_list.keys().has( pos ):
		return true
	elif object_list.keys().has( pos ):
		return true
	else:
		return false
	
func _get_node_at_pos( pos ) -> Node:
	if signal_list.keys().has( pos ):
		return signal_list[pos]
	elif station_list.keys().has( pos ):
		return station_list[pos]
	elif object_list.keys().has( pos ):
		return object_list[pos]
	else:
		return null
		
func get_signal_at_pos( pos : Vector2 ) -> Node:
	if signal_list.keys().has( local_to_map(pos) ):
		return signal_list[ local_to_map(pos) ]
	else:
		return null
func _draw():
	if selected_pos:
		draw_rect( Rect2(selected_pos * 16, Vector2.ONE * 16), removal_selection_color)
