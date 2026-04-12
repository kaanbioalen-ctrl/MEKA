extends Node2D

@export_range(16, 64, 1) var min_piece_count: int = 24
@export_range(16, 96, 1) var max_piece_count: int = 42
@export_range(0.2, 3.0, 0.1) var life_time: float = 0.9

var _elapsed: float = 0.0
var _pieces: Array[Dictionary] = []
var _flash_radius: float = 0.0


func setup(source_radius: float) -> void:
	_create_burst(source_radius)


func _ready() -> void:
	if _pieces.is_empty():
		_create_burst(18.0)


func _process(delta: float) -> void:
	_elapsed += delta
	var t := clampf(_elapsed / life_time, 0.0, 1.0)

	for piece in _pieces:
		piece.pos += piece.vel * delta
		piece.vel *= 0.95

	_flash_radius = lerpf(_flash_radius, _flash_radius * 1.35 + 280.0, minf(1.0, delta * 7.0))
	queue_redraw()

	if t >= 1.0:
		queue_free()


func _draw() -> void:
	var t := clampf(_elapsed / life_time, 0.0, 1.0)
	var fade := pow(1.0 - t, 1.3)
	var shock_radius := lerpf(18.0, _flash_radius, t)
	draw_circle(Vector2.ZERO, shock_radius, Color(1.0, 0.96, 0.72, 0.06 * fade))
	draw_circle(Vector2.ZERO, shock_radius * 0.55, Color(1.0, 1.0, 0.92, 0.12 * fade))

	for piece in _pieces:
		var piece_fade := pow(1.0 - t, 1.5)
		var radius := maxf(0.5, piece.radius * (1.0 - (t * 0.6)))
		draw_circle(piece.pos, radius * 2.2, Color(1.0, 0.82, 0.28, 0.2 * piece_fade))
		draw_circle(piece.pos, radius * 1.1, Color(1.0, 0.96, 0.68, 0.85 * piece_fade))
		draw_circle(piece.pos, radius * 0.45, Color(1.0, 1.0, 1.0, 0.95 * piece_fade))


func _create_burst(source_radius: float) -> void:
	_pieces.clear()
	_elapsed = 0.0
	_flash_radius = maxf(70.0, source_radius * 2.4)

	var piece_count := randi_range(min_piece_count, max_piece_count)
	var min_piece_radius := maxf(1.2, source_radius * 0.12)
	var max_piece_radius := maxf(2.0, source_radius * 0.28)

	for _i in range(piece_count):
		var angle := randf() * TAU
		var dir := Vector2.RIGHT.rotated(angle)
		var speed := randf_range(180.0, 720.0)
		var offset := randf_range(0.0, source_radius * 0.45)
		var radius := randf_range(min_piece_radius, max_piece_radius)
		_pieces.append({
			"pos": dir * offset,
			"vel": dir * speed,
			"radius": radius
		})
