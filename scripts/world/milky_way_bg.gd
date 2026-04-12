extends ColorRect

var _mat: ShaderMaterial = null
var _player: Node2D = null


func _ready() -> void:
	_mat = material as ShaderMaterial


func _process(_delta: float) -> void:
	if _mat == null:
		return
	if _player == null or not is_instance_valid(_player):
		var tree := get_tree()
		if tree != null:
			var p := tree.get_first_node_in_group("player")
			if p is Node2D:
				_player = p as Node2D
	if _player != null and is_instance_valid(_player):
		# accumulated_position: wrap olmayan sürekli koordinat.
		# global_position kullanmak shader'da da UV jump'a yol açar.
		var cam_pos: Vector2
		if _player.get("accumulated_position") != null:
			cam_pos = _player.accumulated_position
		else:
			cam_pos = _player.global_position
		_mat.set_shader_parameter("camera_pos", cam_pos)
