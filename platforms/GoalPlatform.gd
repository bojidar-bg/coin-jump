extends "res://platforms/Platform.gd"

export(String, FILE, "*.tscn,*.scn") var next_level: String

func _land(_side, stable):
	if stable:
		# warning-ignore:return_value_discarded
		get_tree().change_scene(next_level if next_level != "" else owner.filename)
	return true
