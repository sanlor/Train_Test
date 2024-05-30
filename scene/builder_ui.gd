extends HBoxContainer

@export var map : TileMap

func _ready():
	$"../..".ready.connect(func(): _load_game("res://map.dat") )
	pass

func _on_add_track_pressed():
	map.change_mode( map.MODE.ADD_TRACK )

func _on_add_signal_pressed():
	map.change_mode( map.MODE.ADD_SIGNAL )

func _on_add_station_pressed():
	map.change_mode( map.MODE.ADD_STATION )

func _on_add_garage_pressed():
	map.change_mode( map.MODE.ADD_GARAGE )

func _on_add_train_pressed():
	map.change_mode( map.MODE.ADD_TRAIN )

func _on_delete_item_pressed():
	map.change_mode( map.MODE.DELETE )

func _on_delete_track_pressed():
	map.change_mode( map.MODE.DELETE_TRACK )

func _on_clear_everything_pressed():
	map.clear_everything()

func _on_save_pressed():
	if FileAccess.file_exists("user://map.dat"):
		DirAccess.remove_absolute("user://map.dat")
		
	var save_game = FileAccess.open("user://map.dat", FileAccess.WRITE)
	var tiledata : Array[Vector2i] = map.get_used_cells(map.TRACK_LAYER)
	save_game.store_line( var_to_str(tiledata) )
	
	var save_nodes = get_tree().get_nodes_in_group("saving")
	for node in save_nodes:
		var node_data : Dictionary = node.save()
		var json_string = JSON.stringify(node_data)
		save_game.store_line(json_string)
		#save_game.store_line( var_to_str(node_data) )
	#save_game.close()

func _on_load_pressed():
	_load_game("user://map.dat")
	
func _load_game(filepath : String):
	if not FileAccess.file_exists(filepath):
		print("no file to load: ",filepath)
		return
		
	map.clear_everything()
	var save_game = FileAccess.open(filepath, FileAccess.READ)
	
	var tiledata : Array[Vector2i] = str_to_var( save_game.get_line() ) # First line is always the tilemap data
	map.set_cells_terrain_connect(map.TRACK_LAYER,tiledata, 0, 0)
	
	while save_game.get_position() < save_game.get_length():
		var node_data : Dictionary = JSON.parse_string( save_game.get_line() )
		
		var node = load( node_data["filename"] ).instantiate()
		node.load( node_data  )
		map.add_child( node )
		
	Global.map_loaded.emit()
