extends Resource
class_name TrainAstar

var map : TileMap
var grid : Vector2i

var map_size := Rect2( 0, 0, 64, 64 ) ## PLACEHOLDER
var astar : AStarGrid2D 

var current_position : Vector2
var last_position : Vector2

var trackpieces : TrackPieces

var debug_points := []
var debug_disabled_points := []

func setup(_map : TileMap, curr_pos : Vector2):
	map = _map
	astar = AStarGrid2D.new()
	trackpieces = TrackPieces.new()
	update_position(curr_pos)
	_init_astar()
	_update_astar_map()

func update_position(curr_pos : Vector2):
	last_position = current_position
	current_position = map.local_to_map(curr_pos)
	print(self," updated engine position")
	## TODO logic for the PF update

func _init_astar():
	grid = map.get_tileset().get_tile_size()
	astar.set_cell_size( grid )
	astar.set_region( map_size )
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	

# https://codeberg.org/ars/simple_godot_flood_fill/src/branch/main/FloodFill.gd
func _update_astar_map():
	var start := Time.get_ticks_msec()
	debug_points.clear()
	debug_disabled_points.clear()
	astar.fill_solid_region( map_size, true) ## Reset
	
	var neighbors = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	var checked := []
	var queue := [current_position]
	var signal_checked := []
	
	neighbors.shuffle()
	
	if map.is_track_cell_used( map.TRACK_LAYER, current_position ):
		add_nav_point(current_position)
		## setup all the rideable tracks
		while not queue.is_empty():
			var current = queue.pop_back()
			checked.append(current)
			
			## Connect to neighbor tiles
			for dir in neighbors:
				var next_tile = current + dir
				
				if not map_size.has_point( next_tile ):
					continue
				
				if not map.is_track_cell_used( map.TRACK_LAYER, next_tile ):
					continue
					
				if checked.has( next_tile ):
					continue
				
				var is_disabled := false
				# check for signals. if the DIR is the same as the entry point, allow access. if not, disable it.
				var track_signal = trackpieces.get_resource_from_offset( map.get_cell_atlas_coords( map.SIGNAL_LAYER, next_tile ) )
				if track_signal != null:
					if track_signal.entry_points.has( dir ) and not signal_checked.has(next_tile):
						signal_checked.append( next_tile )
						is_disabled = true
						print("signal")
				
				queue.append( next_tile )
				add_nav_point( next_tile, is_disabled )
				
				if is_disabled:
					debug_disabled_points.append( next_tile )
				else:
					debug_points.append( next_tile )
				
		## make the current trains on track as solid
		for train_pos in map.get_trains_positions():
			add_nav_point( train_pos, true )
			debug_disabled_points.append( train_pos )
		
	else:
		push_warning("Train is in invalid location ", current_position)
		return
	#print(debug_points)
	print(self, "astar update took ",Time.get_ticks_msec() - start," msecs. ") 
	map.display_debug_path_points(debug_points, debug_disabled_points)

func add_nav_point(pos, is_solid = false):
	#if astar.is_in_boundsv( _local_to_map(pos) ):
		#astar.set_point_solid( _local_to_map(pos), true)
	if astar.is_in_boundsv( pos ):
		astar.set_point_solid( pos, is_solid )
	else:
		print("star OOB")
	
func get_track_path(src, dst):
	_update_astar_map()
	return astar.get_point_path( _local_to_map(src), _local_to_map(dst) )

func _local_to_map( pos : Vector2 ) -> Vector2:
	return Vector2( pos / grid.x )
