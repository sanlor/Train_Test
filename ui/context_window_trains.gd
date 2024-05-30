extends Window

@onready var speed = $margin/menu/stats/speed
@onready var max_speed = $margin/menu/stats/max_speed
@onready var state = $margin/menu/stats/state

@onready var popup_menu = $PopupMenu

@onready var station_list = $margin/menu/stations/station_list

var source_node : Node

func setup(node : Node):
	source_node = node
	position = source_node.position
	title = source_node.train_name

func _ready():
	source_node.curr_station_target_changed.connect( _populate_station_list )
	_populate_station_list()

func _on_close_requested():
	queue_free()

func _on_remove_selected_station_pressed():
	var selected : PackedInt32Array = station_list.get_selected_items()
	
	if not selected.is_empty():
		#station_list.remove_item( selected[0] )
		source_node.remove_station( selected[0] )
		_populate_station_list()

var avaiable_stations := []
func _on_add_station_pressed():
	popup_menu.position = get_parent().get_viewport().get_mouse_position()
	popup_menu.clear()
	avaiable_stations.clear()
	
	var stations = get_tree().get_nodes_in_group("Station")
	
	for station : Node in stations:
		if not source_node.station_list.has(station):
			popup_menu.add_item(station.station_name)
			avaiable_stations.append(station)
			
	popup_menu.show()

func _on_activate_destination_pressed():
	var selected : PackedInt32Array = station_list.get_selected_items()
	
	if not selected.is_empty():
		source_node.change_active_station( selected[0] )
		_populate_station_list()

func _on_popup_menu_id_pressed(id):
	source_node.add_station( avaiable_stations[id] )
	_populate_station_list()

func _populate_station_list():
	var selected : PackedInt32Array = station_list.get_selected_items()
	station_list.clear()
	#avaiable_stations.clear()
	var index := 0
	for station : Node in source_node.station_list:
		if source_node.curr_station_target == index:
			station_list.add_item("> " + station.station_name)
		else:
			station_list.add_item(station.station_name)
		index += 1
	
	if not selected.is_empty(): # Remember the player selection after rebuilding the itemlist
		station_list.select( selected[0] )

	
func _update_engine_data():
	speed.text = str(source_node.speed)
	max_speed.text = str(source_node.max_speed)
	state.text = Train.STATE.keys()[source_node.curr_STATE]

func _process(_delta):
	#_populate_station_list()
	_update_engine_data()



