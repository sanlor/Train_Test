extends TileMap
# https://escada-games.itch.io/randungeon/devlog/261991/how-to-use-godots-astar2d-for-path-finding

const TRACK_LAYER := 0
const STATION_LAYER := 1
const SIGNAL_LAYER := 2
const TEMP_LAYER := 3

var map_size := Rect2( 0, 0, 64, 64 )

var start_drag := Vector2.ZERO
@onready var track_placement := AStarGrid2D.new()
#@onready var astar_track_blocks := AStar2D.new() # used to pathfind using signal blocks
@onready var astar_track_tiles := AStar2D.new() # used to pathfind using the trackpieces
var track_placement_path := Array()

@onready var trackpieces := TrackPieces.new()

var track_regions := Dictionary()
var track_signals := Dictionary()

func _ready():
	_init_track_placement()
	_init_astar_track_tiles()

func _init_track_placement():
	track_placement.set_cell_size( get_tileset().get_tile_size() )
	track_placement.set_region( map_size )
	track_placement.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	track_placement.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	track_placement.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	track_placement.update()
	track_placement.fill_solid_region( map_size, false)

func _init_astar_track_tiles():
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
	var unchecked_tiles 	:= get_used_cells( TRACK_LAYER ) ## all used tiles
	var checked_tiles 		:= [] # tiles already checked by the floodfill algo
	var queue_tiles 		:= [] # queues to be checked by the algorithm
	var regions				:= {} # dictionary with all regions filled by the algo
	var region_index 		:= 0 # index used by the dictionary
	var signals 			:= get_used_cells( SIGNAL_LAYER ) # all signals / semaphores added to the game
	
	while not unchecked_tiles.is_empty(): ## Infinite loop warning
		queue_tiles.append( unchecked_tiles.pop_back() )
		regions[region_index] = Array()
		
		while not queue_tiles.is_empty(): ## Infinite loop warning
			var current = queue_tiles.pop_back()
			checked_tiles.append(current)
			unchecked_tiles.erase(current)
			var directions_to_check := []
			
			# If this cell has a signal, skip it.
			if signals.has( current ):
				continue
			else:
				# get all directions that the track piece is connected ## TODO maybe I can get this info from the tilemap itself?
				directions_to_check = trackpieces.get_resource_from_offset( get_cell_atlas_coords( TRACK_LAYER, current ) ).exit_points # Should return an array of vector with directions to check
				
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
				if signals.has( next_tile ): # if the next tile is a signal, treat as a boundarie
					#print("signal")
					continue
					
				#The tile is valid, connect the point and add the next tile to the queue
				queue_tiles.append( next_tile )
				astar_track_tiles.connect_points( _get_astar_index(current), _get_astar_index(next_tile), true)
		
		if not regions[region_index].is_empty():
			region_index += 1 # after a loop on all avaiable tiles within the boundaries, add on to the index.
	
	# Set the signal regions
	for s : Vector2 in signals:
		# find the region for the track in front of the signal.
		var signal_exit 	: Vector2 = trackpieces.get_resource_from_offset( get_cell_atlas_coords( SIGNAL_LAYER, s ) ).exit_points.front() # Signal only have one exit point.
		var signal_entry 	: Vector2 = trackpieces.get_resource_from_offset( get_cell_atlas_coords( SIGNAL_LAYER, s ) ).entry_points.front() # Signal only have one entry point.
		for region_id in regions:
			if regions[region_id].has( Vector2i(signal_exit + s) ):
				if regions[region_id].has( Vector2i(signal_entry + s) ): # if the entry ant the exit are on the same region, this signal is invalid.
					track_signals[ s ] = INF
					break
				track_signals[ s ] = region_id # add the region for this signal
				astar_track_tiles.connect_points( _get_astar_index(signal_entry + s), _get_astar_index(s), 	false) # connect the astar points in a unidirectional way.
				astar_track_tiles.connect_points( _get_astar_index(s), _get_astar_index(signal_exit + s), 	false) # connect the astar points in a unidirectional way.
				break
		
	track_regions = regions
	print("regions: ", regions.size())
	queue_redraw()
	assert( unchecked_tiles.is_empty() ) # At the end, all used tiles must be checked
	print(self, "astar update took ",Time.get_ticks_msec() - start," msecs. ") 

func is_track_cell_used(layer, pos):
	#var track_celldata := get_cell_tile_data( TRACK_LAYER, local_to_map(pos) )
	var track_celldata := get_cell_tile_data( layer, pos )
	if track_celldata != null:
		return true
	else:
		return false

func _get_astar_index( pos : Vector2 ) -> int:
	return int( pos.y * map_size.end.x + pos.x  )

func get_trains_positions() -> Array:
	var trains := Array()
	for obj in get_children():
		trains.append( local_to_map( obj.position ) )
	return trains
	
func get_cell_resource(layer, pos):
	var track_celldata := get_cell_tile_data( layer, pos )
	if track_celldata != null:
		var trackpieces := TrackPieces.new()
		return trackpieces.get_resource_from_offset( get_cell_atlas_coords( layer, pos ) )
		
func get_track_path(src, dst) -> PackedVector2Array:
	if src == dst: ## DEBUG - its a bug with the temp engine code
		return PackedVector2Array()
		
	_update_astar_track_tiles()
	return astar_track_tiles.get_point_path( _get_astar_index(src), _get_astar_index(dst) )
	
func _process(delta):
	if Input.is_action_just_pressed("click"):
		start_drag = get_global_mouse_position()
		
	if Input.is_action_pressed("click") and start_drag:
		_make_temporary_track( get_global_mouse_position())
		
	if Input.is_action_just_released("click") and start_drag:
		clear_layer( 1 )
		set_cells_terrain_path(0, track_placement_path, 0, 0)
		start_drag = Vector2.ZERO
		track_placement_path.clear()
		
	if Input.is_action_pressed("rclick"):
		clear_layer( 1 )
		start_drag = Vector2.ZERO
		track_placement_path.clear()
		
func _make_temporary_track( destination : Vector2 ):
	if start_drag == Vector2.ZERO:
		push_warning("No start_path")
		return
		
	if not track_placement.is_in_boundsv( local_to_map(start_drag) ):
		push_warning("start OOB ", local_to_map(start_drag) )
		return
		
	if not track_placement.is_in_boundsv( local_to_map(destination) ):
		push_warning("end OOB ", local_to_map(destination) )
		return
	
	var path := track_placement.get_id_path(local_to_map(start_drag), local_to_map(destination))
	if path.is_empty():
		push_warning("No valid path")
		return
	clear_layer( 1 )
	set_cells_terrain_path(1, path, 0, 0)
	track_placement_path = path
	
func _draw():
	for region in track_regions.keys():
		var color := Color(randf(), randf(), randf())
		# draw debug over selected track pieces
		for pos in track_regions[region]:
			draw_circle( map_to_local(pos), 4, color )
		# draw debug over signal pieces
		for s in track_signals:
			if track_signals[s] == INF: # INF means invalid
				draw_circle( map_to_local(s), 4, Color.BLACK )
				continue
			if region == track_signals[s]:
				draw_circle( map_to_local(s), 4, color.darkened(0.40) )
			
	#draw grid
	for x in map_size.end.x:
		var start_point 	:= Vector2( x * get_tileset().get_tile_size().x , map_size.position.y )
		var end_point 		:= Vector2( x * get_tileset().get_tile_size().x , map_size.end.y * get_tileset().get_tile_size().y )
		draw_line( start_point, end_point, Color( Color.GRAY, 0.25 ), 1.0 )
		draw_string( ThemeDB.fallback_font, start_point + Vector2(0,8), str( x ), HORIZONTAL_ALIGNMENT_CENTER, 16, 8)

	for y in map_size.end.y:
		var start_point 	:= Vector2( map_size.position.x , y * get_tileset().get_tile_size().y )
		var end_point 		:= Vector2( map_size.end.x * get_tileset().get_tile_size().x, y * get_tileset().get_tile_size().y )
		draw_line( start_point, end_point, Color( Color.GRAY, 0.25 ), 1.0 )
		draw_string( ThemeDB.fallback_font, start_point + Vector2(0,8), str( y ), HORIZONTAL_ALIGNMENT_CENTER, 16, 8)
