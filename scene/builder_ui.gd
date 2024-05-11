extends HBoxContainer

@onready var track_sel = $track_sel
@onready var obj_sel = $obj_sel

func _ready():
	var track_pieces := TrackPieces.new()
	for track in track_pieces.list:
		var piece : TrackPieces = track
		track_sel.add_icon_item( piece.get_image(), piece.ID)
