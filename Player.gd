extends Spatial

export(String, FILE, "*.tscn,*.scn") var next_level: String

func go_to_next_level():
	get_tree().change_scene(next_level)
