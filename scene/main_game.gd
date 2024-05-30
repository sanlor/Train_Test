extends Node2D

const alert_colors := {
	Global.MsgTypes.Info: Color.WHITE,
	Global.MsgTypes.Alert: Color.YELLOW,
	Global.MsgTypes.Error: Color.RED,
}

func _ready():
	Global.alert.connect( display_msg )
	
func display_msg(type, msg, pos):
	var label = preload("res://scene/alert_msg.tscn").instantiate()
	label.setup(alert_colors[type], msg, pos)
	add_child(label)
