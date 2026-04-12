extends Node2D
## LEGACY — This Node2D was the SubViewport background renderer.
## It is no longer used; upgrade_screen.gd purges it in _ready().
## Left here so existing .tscn files don't break on load.
## All visual logic has moved to the new Control-based UI system.

var screen_size: Vector2 = Vector2(1920.0, 1080.0)
var grid_size: Vector2i  = Vector2i(3, 3)


func _ready() -> void:
	# Immediately hide and disable to prevent any residual rendering.
	visible      = false
	process_mode = Node.PROCESS_MODE_DISABLED


func configure(view_size: Vector2) -> void:
	screen_size = view_size
	queue_redraw()


func get_map_size() -> Vector2:
	return Vector2(
		screen_size.x * float(grid_size.x),
		screen_size.y * float(grid_size.y)
	)


func get_map_center() -> Vector2:
	return get_map_size() * 0.5


func _draw() -> void:
	var map_size := get_map_size()
	_draw_background(map_size)
	_draw_tree_layout(map_size)


func _draw_background(map_size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, map_size), Color(0.015, 0.02, 0.04, 1.0), true)

	var grid_color := Color(0.10, 0.16, 0.24, 0.32)
	var fine_x := 160.0
	var fine_y := 120.0
	var x := 0.0
	while x <= map_size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, map_size.y), grid_color, 1.0)
		x += fine_x
	var y := 0.0
	while y <= map_size.y:
		draw_line(Vector2(0.0, y), Vector2(map_size.x, y), grid_color, 1.0)
		y += fine_y

	var center := map_size * 0.5
	for ring_idx in range(5):
		var radius := 180.0 + float(ring_idx) * 120.0
		draw_arc(center, radius, 0.0, TAU, 128, Color(0.14, 0.24, 0.34, 0.18), 2.0, true)

	for star_idx in range(72):
		var seed := float(star_idx + 1)
		var star_pos := Vector2(
			fmod(sin(seed * 13.17) * 43758.5, 1.0),
			fmod(cos(seed * 9.31) * 24691.8, 1.0)
		)
		star_pos = Vector2(absf(star_pos.x), absf(star_pos.y)) * map_size
		var radius := 1.4 + fmod(seed * 0.73, 2.2)
		draw_circle(star_pos, radius, Color(0.75, 0.9, 1.0, 0.22))


func _draw_tree_layout(map_size: Vector2) -> void:
	var center := map_size * 0.5
	var root := center + Vector2(0.0, -90.0)
	var mining := root + Vector2(-290.0, -170.0)
	var mining_speed := root + Vector2(-290.0, -25.0)
	var damage_aura := root + Vector2(-290.0, 120.0)
	var drop_collection := root + Vector2(0.0, 220.0)
	var orbit_mode := root + Vector2(390.0, -20.0)

	_draw_link(root, mining, false)
	_draw_link(root, mining_speed, false)
	_draw_link(root, damage_aura, false)
	_draw_link(root, drop_collection, false)
	_draw_link(root, orbit_mode, true)

	_draw_skill_node(root, 62.0, Color(0.85, 0.18, 0.22, 0.95), Color(1.0, 0.62, 0.62, 0.65))
	_draw_skill_node(mining, 34.0, Color(0.20, 0.78, 1.0, 0.92), Color(0.56, 0.88, 1.0, 0.30))
	_draw_skill_node(mining_speed, 34.0, Color(0.20, 0.78, 1.0, 0.92), Color(0.56, 0.88, 1.0, 0.30))
	_draw_skill_node(damage_aura, 34.0, Color(0.28, 0.96, 0.76, 0.92), Color(0.52, 1.0, 0.84, 0.28))
	_draw_skill_node(drop_collection, 34.0, Color(1.0, 0.76, 0.24, 0.95), Color(1.0, 0.88, 0.56, 0.26))
	_draw_skill_node(orbit_mode, 38.0, Color(0.88, 0.54, 1.0, 0.92), Color(0.96, 0.74, 1.0, 0.30))


func _draw_link(from: Vector2, to: Vector2, is_side_branch: bool) -> void:
	var mid := Vector2((from.x + to.x) * 0.5, from.y)
	var line_color := Color(0.66, 0.72, 0.84, 0.16)
	if is_side_branch:
		line_color = Color(0.92, 0.68, 1.0, 0.24)
	draw_polyline(PackedVector2Array([from, mid, to]), line_color, 4.0, true)
	draw_circle(to, 4.0, Color(line_color.r, line_color.g, line_color.b, 0.85))


func _draw_skill_node(pos: Vector2, radius: float, core_color: Color, glow_color: Color) -> void:
	draw_circle(pos, radius * 1.75, Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * 0.22))
	draw_circle(pos, radius * 1.25, Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a))
	draw_circle(pos, radius, core_color)
	draw_arc(pos, radius * 1.15, 0.0, TAU, 72, Color(1.0, 1.0, 1.0, 0.22), 2.0, true)
