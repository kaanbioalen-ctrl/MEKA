class_name UraniumRadiationCloud
extends Node2D

const DEFAULT_LIFETIME: float = 4.8
const DEFAULT_GLOW_BOOST: float = 0.42
const DEFAULT_ENERGY_DRAIN_MULT: float = 8.5

var radius: float = 220.0
var lifetime: float = DEFAULT_LIFETIME
var _player: Node2D = null
var _time: float = 0.0


func setup(center: Vector2, next_radius: float, player_node: Node2D = null) -> void:
	global_position = center
	radius = maxf(24.0, next_radius)
	_player = player_node
	z_index = 3
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	lifetime = maxf(0.0, lifetime - delta)
	_update_player_radiation()
	queue_redraw()
	if lifetime <= 0.0:
		_clear_player_radiation()
		queue_free()


func _draw() -> void:
	var fade := clampf(lifetime / DEFAULT_LIFETIME, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(_time * 4.6)
	var outer_r := radius * lerpf(1.0, 1.08, pulse)
	var inner_r := radius * 0.62
	draw_circle(Vector2.ZERO, outer_r, Color(0.05, 0.22, 0.03, 0.16 * fade))
	draw_circle(Vector2.ZERO, inner_r, Color(0.16, 0.82, 0.08, 0.09 * fade))
	draw_arc(Vector2.ZERO, radius * 0.86, 0.0, TAU, 72, Color(0.42, 1.0, 0.22, 0.18 * fade), 2.0, true)
	draw_arc(Vector2.ZERO, radius * 0.58, 0.0, TAU, 64, Color(0.12, 0.84, 0.10, 0.12 * fade), 1.3, true)


func _update_player_radiation() -> void:
	if _player == null or not is_instance_valid(_player):
		var tree := get_tree()
		if tree != null:
			var maybe_player := tree.get_first_node_in_group("player")
			if maybe_player is Node2D:
				_player = maybe_player as Node2D
	if _player == null or not is_instance_valid(_player):
		return
	var inside := global_position.distance_to(_player.global_position) <= radius
	if _player.has_method("set_storm_feedback"):
		if inside:
			_player.call("set_storm_feedback", true, DEFAULT_GLOW_BOOST, DEFAULT_ENERGY_DRAIN_MULT)
		else:
			_player.call("set_storm_feedback", false, 0.0, 1.0)


func _clear_player_radiation() -> void:
	if _player != null and is_instance_valid(_player) and _player.has_method("set_storm_feedback"):
		_player.call("set_storm_feedback", false, 0.0, 1.0)
