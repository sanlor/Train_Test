extends Camera2D

@export_category("Movement")
@export var cam_speed := 1000.0
@export var cam_accel := 0.05

@export_category("Zoom")
@export var max_zoom := Vector2(4,4)
@export var min_zoom := Vector2(1,1)

var speed := 0.0



func _process(delta):
	var h := Input.get_axis("left", "right")
	var v := Input.get_axis("up", "down")
	var z := Input.get_axis("zoom_in","zoom_out")
	
	if h != 0 or v != 0 or z != 0:
		speed = lerpf(speed, cam_speed, cam_accel)
	else:
		speed = lerpf(speed, 0.0, cam_accel)
		
	if Input.is_action_just_pressed("zoom_in"):
		zoom = zoom.move_toward(max_zoom, 0.25)
	if Input.is_action_just_pressed("zoom_out"):
		zoom = zoom.move_toward(min_zoom, 0.25)
	
	position.x += h * speed * delta
	position.y += v * speed * delta
