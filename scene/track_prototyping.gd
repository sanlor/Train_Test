@tool
extends Sprite2D

@export var reload := false :
	set(x):
		_reload()

@export var track_res : TrackPieces :
	set(piece):
		track_res = piece
		_reload()
		

func _ready():
	_reload()

func _reload():
	texture.region.position = track_res.sprite_offset * 16
	queue_redraw()
	
func _draw():
	if track_res != null:
		
		for entry in track_res.entry_points:
			draw_circle(entry * 16, 1, Color(Color.BLUE, 0.25))
			
		for exit in track_res.exit_points:
			draw_circle(exit * 16, 1, Color(Color.RED, 0.25))
