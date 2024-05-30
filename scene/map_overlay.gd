extends Node2D

@export var map : TileMap

var selection_squares : Rect2#Array[Vector2i]
var selection_color : Color
var draw_selection := false

func _ready():
	Global.changed_debug_display.connect( func(): queue_redraw() )

func highlight_square(rect : Rect2, color : Color, ena_draw := true):
	draw_selection = ena_draw
	selection_squares = rect
	selection_color = color
	queue_redraw()

func clear_highlight():
	draw_selection = false
	queue_redraw()

#func _physics_process(_delta):
	#queue_redraw()

func _draw():
	if draw_selection:
		draw_rect(selection_squares, selection_color)
		
	## DEBUG
	if Global.show_grid:
		for x in map.map_size.end.x:
			var start_point 	:= Vector2( x * map.get_tileset().get_tile_size().x , map.map_size.position.y )
			var end_point 		:= Vector2( x * map.get_tileset().get_tile_size().x , map.map_size.end.y * map.get_tileset().get_tile_size().y )
			draw_line( start_point, end_point, Color( Color.GRAY, 0.25 ), 1.0 )
			draw_string( ThemeDB.fallback_font, start_point + Vector2(0,8), str( x ), HORIZONTAL_ALIGNMENT_CENTER, 16, 8)

		for y in map.map_size.end.y:
			var start_point 	:= Vector2( map.map_size.position.x , y * map.get_tileset().get_tile_size().y )
			var end_point 		:= Vector2( map.map_size.end.x * map.get_tileset().get_tile_size().x, y * map.get_tileset().get_tile_size().y )
			draw_line( start_point, end_point, Color( Color.GRAY, 0.25 ), 1.0 )
			draw_string( ThemeDB.fallback_font, start_point + Vector2(0,8), str( y ), HORIZONTAL_ALIGNMENT_CENTER, 16, 8)
			
	if Global.show_track_debug:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("aaaaaa") # force a predictive "random" color
		for region in map.track_regions.keys():
			
			var color := Color(rng.randf(), rng.randf(), rng.randf(), 0.25)
			# draw debug over selected track pieces
			for pos in map.track_regions[region]:
				draw_circle( map.map_to_local(pos), 8, color )
			# draw debug over signal pieces
			for s in map.track_signals:
				if map.track_signals[s] == INF: # INF means invalid
					draw_circle( map.map_to_local(s), 8, Color.BLACK )
					continue
				if region == map.track_signals[s]:
					draw_circle( map.map_to_local(s), 8, color.darkened(0.40) )
					
	if Global.show_disabled_debug:
		#for tile in map.disabled_tiles:
		#	draw_circle( map.map_to_local(tile), 9, Color(Color.GRAY, 0.25) )
		
		for region in map.disabled_regions:
			for tile : Vector2i in map.track_regions[region]:
				draw_circle( map.map_to_local(tile), 9, Color(Color.GRAY, 0.25) )
