extends CanvasLayer

func _ready():
	Global.open_context_menu.connect(_create_context_window)
	
func _create_context_window(node, type):
	match type:
		Global.NodeTypes.Trains:
			var window := preload("res://ui/context_window_trains.tscn").instantiate()
			window.setup(node)
			add_child(window)
			
		Global.NodeTypes.Garage:
			pass
			
		Global.NodeTypes.Station:
			pass
