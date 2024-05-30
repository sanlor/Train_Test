extends Node

enum NodeTypes {None,Trains,Garage,Station,Industry}
enum MsgTypes {Info, Alert, Error}

var show_grid := false
var show_track_debug := false
var show_disabled_debug := false
var show_run_time := false

signal open_context_menu (Node, NodeTypes) ## opens a window with the data from the source node
signal alert(type : MsgTypes, msg : String, pos : Vector2)
signal changed_debug_display
signal map_loaded

func _unhandled_input(event):
	if event is InputEventKey:
		if Input.is_key_pressed(KEY_1):
			show_grid = not show_grid
			print("show_grid ",show_grid)
			changed_debug_display.emit()
		if Input.is_key_pressed(KEY_2):
			show_track_debug = not show_track_debug
			print("show_track_debug ",show_track_debug)
			changed_debug_display.emit()
		if Input.is_key_pressed(KEY_3):
			show_disabled_debug = not show_disabled_debug
			print("show_disabled_debug ",show_disabled_debug)
			changed_debug_display.emit()
		if Input.is_key_pressed(KEY_4):
			show_run_time = not show_run_time
