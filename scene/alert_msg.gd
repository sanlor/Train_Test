extends Label

func setup(color, msg, pos):
	text = msg
	position = pos + Vector2(0, -20)
	modulate = color
	position -= size / 2
	

func _ready():
	var tween = get_tree().create_tween()
	#tween.set_parallel(true)
	tween.tween_property(self, "position", position + Vector2(0, -20)	, 1)
	tween.parallel().tween_property(self, "modulate", Color.TRANSPARENT			, 1)
	tween.tween_callback(queue_free)

	
