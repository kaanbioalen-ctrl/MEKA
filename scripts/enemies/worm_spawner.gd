extends Node2D

@export var worm_scene: PackedScene
@export_range(0, 10, 1) var target_max_count: int = 1
@export_range(0.1, 2.0, 0.05) var tick_interval: float = 0.8
@export_range(12.0, 200.0, 1.0) var spawn_margin: float = 64.0
@export_range(24.0, 400.0, 1.0) var offscreen_spawn_distance: float = 180.0
@export_range(16.0, 300.0, 1.0) var initial_spawn_spacing: float = 140.0

var _player: Node2D = null
var _world_bounds: Rect2 = Rect2(0.0, 0.0, 0.0, 0.0)
var _screen_size: Vector2 = Vector2(1920.0, 1080.0)
var _tick_left: float = 0.0
var _initial_fill_done: bool = false
var _start_screen: Vector2i = Vector2i.ZERO
var _worms_unlocked: bool = false
var _spawn_move_speed: float = 0.0   # 0 = worm default kullan
var _spawn_turn_speed: float = 0.0   # 0 = worm default kullan


func set_spawn_overrides(move_speed: float, turn_speed: float) -> void:
	_spawn_move_speed = move_speed
	_spawn_turn_speed = turn_speed


func configure(player: Node2D, world_bounds: Rect2, screen_size: Vector2) -> void:
	_player = player
	_world_bounds = world_bounds
	_screen_size = screen_size
	_tick_left = tick_interval
	_initial_fill_done = false
	_start_screen = _get_player_screen_grid()
	_worms_unlocked = false


func _process(delta: float) -> void:
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left = tick_interval
	_update_unlock_state()
	if not _worms_unlocked:
		return
	if not _initial_fill_done:
		_fill_initial_screen()
	_fill_worm_quota()


func _fill_worm_quota() -> void:
	if worm_scene == null or _player == null or not is_instance_valid(_player):
		return
	var current := get_tree().get_nodes_in_group("worm_enemy").size()
	while current < target_max_count:
		var worm := worm_scene.instantiate() as Node2D
		if worm == null:
			return
		worm.global_position = _pick_spawn_position_offscreen()
		get_parent().add_child(worm)
		if worm.has_method("set_player"):
			worm.call("set_player", _player)
		if worm.has_method("set_world_bounds"):
			worm.call("set_world_bounds", _world_bounds)
		_apply_spawn_overrides(worm)
		current += 1


func _pick_spawn_position_offscreen() -> Vector2:
	var rect := _get_player_screen_rect()
	var side := randi() % 4
	match side:
		0:
			return Vector2(
				randf_range(rect.position.x + spawn_margin, rect.end.x - spawn_margin),
				maxf(_world_bounds.position.y + spawn_margin, rect.position.y - offscreen_spawn_distance)
			)
		1:
			return Vector2(
				randf_range(rect.position.x + spawn_margin, rect.end.x - spawn_margin),
				minf(_world_bounds.end.y - spawn_margin, rect.end.y + offscreen_spawn_distance)
			)
		2:
			return Vector2(
				maxf(_world_bounds.position.x + spawn_margin, rect.position.x - offscreen_spawn_distance),
				randf_range(rect.position.y + spawn_margin, rect.end.y - spawn_margin)
			)
		_:
			return Vector2(
				minf(_world_bounds.end.x - spawn_margin, rect.end.x + offscreen_spawn_distance),
				randf_range(rect.position.y + spawn_margin, rect.end.y - spawn_margin)
			)


func _get_player_screen_rect() -> Rect2:
	var visible_size := _screen_size
	if _player != null:
		var viewport_rect := _player.get_viewport_rect()
		if viewport_rect.size.x > 0.0 and viewport_rect.size.y > 0.0:
			visible_size = viewport_rect.size
	var top_left := _player.global_position - (visible_size * 0.5)
	var rect := Rect2(top_left, visible_size)
	var min_pos := _world_bounds.position
	var max_pos := _world_bounds.end - visible_size
	rect.position = Vector2(
		clampf(rect.position.x, min_pos.x, maxf(min_pos.x, max_pos.x)),
		clampf(rect.position.y, min_pos.y, maxf(min_pos.y, max_pos.y))
	)
	return rect


func _random_point_in_rect(rect: Rect2, margin: float) -> Vector2:
	return Vector2(
		randf_range(rect.position.x + margin, rect.end.x - margin),
		randf_range(rect.position.y + margin, rect.end.y - margin)
	)


func _fill_initial_screen() -> void:
	if _initial_fill_done or worm_scene == null or _player == null or not is_instance_valid(_player):
		return
	var screen_rect := _get_player_screen_rect()
	var positions: Array[Vector2] = []
	for _i in range(target_max_count):
		var worm := worm_scene.instantiate() as Node2D
		if worm == null:
			continue
		var spawn_pos := _pick_non_overlapping_offscreen_point(screen_rect, positions, initial_spawn_spacing)
		positions.append(spawn_pos)
		worm.global_position = spawn_pos
		get_parent().add_child(worm)
		if worm.has_method("set_player"):
			worm.call("set_player", _player)
		if worm.has_method("set_world_bounds"):
			worm.call("set_world_bounds", _world_bounds)
		_apply_spawn_overrides(worm)
	_initial_fill_done = true


func _pick_non_overlapping_offscreen_point(_rect: Rect2, existing: Array[Vector2], min_distance: float) -> Vector2:
	for _attempt in range(40):
		var candidate := _pick_spawn_position_offscreen()
		var overlaps := false
		for point in existing:
			if point.distance_to(candidate) < min_distance:
				overlaps = true
				break
		if not overlaps:
			return candidate
	return _pick_spawn_position_offscreen()


func _update_unlock_state() -> void:
	if _worms_unlocked or _player == null or not is_instance_valid(_player):
		return
	var current_screen := _get_player_screen_grid()
	var delta := current_screen - _start_screen
	var screen_distance := maxi(abs(delta.x), abs(delta.y))
	if screen_distance >= 2:
		_worms_unlocked = true


func _get_player_screen_grid() -> Vector2i:
	if _player == null:
		return Vector2i.ZERO
	var cell_x := int(floor((_player.global_position.x - _world_bounds.position.x) / maxf(1.0, _screen_size.x)))
	var cell_y := int(floor((_player.global_position.y - _world_bounds.position.y) / maxf(1.0, _screen_size.y)))
	return Vector2i(cell_x, cell_y)


func _apply_spawn_overrides(worm: Node2D) -> void:
	if _spawn_move_speed > 0.0:
		worm.set("move_speed", _spawn_move_speed)
	if _spawn_turn_speed > 0.0:
		worm.set("turn_speed", _spawn_turn_speed)
