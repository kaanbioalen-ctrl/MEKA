extends Node2D

@export_range(10, 20, 1) var min_piece_count: int = 10
@export_range(10, 30, 1) var max_piece_count: int = 20
@export_range(0.5, 5.0, 0.1) var life_time: float = 2.0

var _elapsed: float = 0.0
var _pieces: Array[Dictionary] = []


func setup(source_radius: float) -> void:
	_create_pieces(source_radius)


func _ready() -> void:
	if _pieces.is_empty():
		_create_pieces(12.0)


func _process(delta: float) -> void:
	_elapsed += delta
	var t := clampf(_elapsed / life_time, 0.0, 1.0)

	for piece in _pieces:
		piece.pos += piece.vel * delta
		piece.vel *= 0.96

	queue_redraw()

	if t >= 1.0:
		queue_free()


func _draw() -> void:
	var t := clampf(_elapsed / life_time, 0.0, 1.0)
	for piece in _pieces:
		var fade := pow(1.0 - t, 1.7)
		var r := maxf(0.2, piece.radius * (1.0 - t * 0.75))
		var glow_col := Color(0.8, 1.0, 1.0, 0.22 * fade)
		var core_col := Color(1.0, 1.0, 1.0, 0.95 * fade)
		draw_circle(piece.pos, r * 1.85, glow_col)
		draw_circle(piece.pos, r, core_col)


func _create_pieces(source_radius: float) -> void:
	_pieces.clear()
	_elapsed = 0.0

	var max_piece_radius := maxf(0.6, source_radius * 0.25)
	var min_piece_radius := maxf(0.3, max_piece_radius * 0.35)
	var piece_count := randi_range(min_piece_count, max_piece_count)

	for i in piece_count:
		var angle := randf() * TAU
		var dir := Vector2.RIGHT.rotated(angle)
		var speed := randf_range(60.0, 380.0)
		var spawn_r := randf_range(0.0, source_radius * 0.3)
		var radius := randf_range(min_piece_radius, max_piece_radius)
		_pieces.append({
			"pos": dir * spawn_r,
			"vel": dir * speed,
			"radius": radius
		})
