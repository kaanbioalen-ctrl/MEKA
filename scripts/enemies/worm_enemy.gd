extends Area2D
class_name WormEnemy

@export_range(1.0, 100.0, 1.0) var max_hp: float = 2.0
@export_range(10.0, 400.0, 1.0) var move_speed: float = 135.0
@export_range(20.0, 400.0, 1.0) var turn_speed: float = 3.2
@export_range(0.0, 200.0, 1.0) var wave_amplitude: float = 30.0
@export_range(0.1, 10.0, 0.1) var wave_frequency: float = 2.0
@export_range(3, 24, 1) var segment_count: int = 8
@export_range(4.0, 40.0, 1.0) var segment_spacing: float = 14.0
@export_range(4.0, 40.0, 1.0) var head_radius: float = 14.0
@export_range(0.1, 10.0, 0.1) var offscreen_despawn_time: float = 2.0
@export_range(0.0, 30.0, 0.1) var lifetime: float = 0.0

var _player: Node2D = null
var _world_bounds: Rect2 = Rect2(0.0, 0.0, 0.0, 0.0)
var _has_world_bounds: bool = false
var _travel_dir: Vector2 = Vector2.RIGHT
var _time_alive: float = 0.0
var _trail_points: Array[Vector2] = []
var _offscreen_time: float = 0.0
var _lifetime_left: float = 0.0
var _hp: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("worm_enemy")
	_hp = max_hp
	_player = _find_player()
	_lifetime_left = lifetime
	_apply_collision_radius()
	_seed_trail()
	queue_redraw()


func _physics_process(delta: float) -> void:
	_time_alive += delta
	if lifetime > 0.0:
		_lifetime_left = maxf(0.0, _lifetime_left - delta)
		if _lifetime_left <= 0.0:
			queue_free()
			return
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()

	var desired_dir := _get_desired_direction()
	if desired_dir != Vector2.ZERO:
		_travel_dir = _travel_dir.slerp(desired_dir, clampf(turn_speed * delta, 0.0, 1.0)).normalized()

	global_position += _travel_dir * move_speed * delta
	_wrap_to_world()
	_update_offscreen_timer(delta)
	if _offscreen_time >= offscreen_despawn_time:
		queue_free()
		return
	_update_trail()
	queue_redraw()


func set_world_bounds(bounds: Rect2) -> void:
	_world_bounds = bounds
	_has_world_bounds = true


func set_player(player_node: Node2D) -> void:
	_player = player_node


func take_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	_hp = maxf(0.0, _hp - amount)
	if _hp <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area == null:
		return
	if area.is_in_group("asteroid_1"):
		if area.has_method("take_mining_damage"):
			var damage := 0.0
			var hp_variant: Variant = area.get("hp")
			if hp_variant != null:
				damage = float(hp_variant)
			else:
				var max_hp_variant: Variant = area.get("max_hp")
				if max_hp_variant != null:
					damage = float(max_hp_variant)
			if damage > 0.0:
				area.call("take_mining_damage", damage)
		queue_free()
		return
	if area.is_in_group("asteroid"):
		queue_free()


func _draw() -> void:
	var count := _trail_points.size()
	for index in range(count - 1, -1, -1):
		var t := float(index + 1) / float(count + 1)
		var radius := lerpf(head_radius * 0.42, head_radius * 0.9, t)
		var alpha := lerpf(0.18, 0.85, t)
		var point := to_local(_trail_points[index])
		draw_circle(point, radius * 1.35, Color(0.12, 1.0, 0.62, alpha * 0.22))
		draw_circle(point, radius, Color(0.1, 0.78, 0.48, alpha))

	draw_circle(Vector2.ZERO, head_radius * 1.45, Color(0.25, 1.0, 0.7, 0.18))
	draw_circle(Vector2.ZERO, head_radius, Color(0.18, 0.92, 0.58, 0.96))
	draw_circle(_travel_dir * (head_radius * 0.25), head_radius * 0.28, Color(0.92, 1.0, 0.95, 0.8))


func _get_desired_direction() -> Vector2:
	if _player == null or not is_instance_valid(_player):
		return _travel_dir

	var to_player := _player.global_position - global_position
	if to_player.length_squared() <= 0.001:
		return _travel_dir

	var forward := to_player.normalized()
	var wave := sin(_time_alive * wave_frequency) * wave_amplitude
	var offset_target := _player.global_position + forward.orthogonal() * wave
	var curved_dir := (offset_target - global_position).normalized()
	return curved_dir if curved_dir != Vector2.ZERO else forward


func _update_trail() -> void:
	_trail_points.push_front(global_position)
	var max_points: float = float(max(1, segment_count)) * maxf(1.0, segment_spacing)
	while _estimate_trail_length() > max_points and _trail_points.size() > 1:
		_trail_points.pop_back()


func _estimate_trail_length() -> float:
	if _trail_points.size() < 2:
		return 0.0
	var total := 0.0
	for i in range(1, _trail_points.size()):
		total += _trail_points[i - 1].distance_to(_trail_points[i])
	return total


func _seed_trail() -> void:
	_trail_points.clear()
	for i in range(segment_count):
		_trail_points.append(global_position - (_travel_dir * segment_spacing * float(i + 1)))


func _wrap_to_world() -> void:
	if not _has_world_bounds:
		return
	if not WorldWrap.needs_wrap(global_position, _world_bounds):
		return
	global_position = WorldWrap.apply(global_position, _world_bounds)
	# Trail sıfırla — wrap sonrası eski pozisyon noktaları dünya genelinde
	# uzanan görsel bir çizgiye yol açar, _seed_trail bunu temizler.
	_seed_trail()


func _apply_collision_radius() -> void:
	if collision_shape == null:
		return
	if collision_shape.shape is CircleShape2D:
		var circle := collision_shape.shape as CircleShape2D
		circle.radius = head_radius


func _find_player() -> Node2D:
	var tree := get_tree()
	if tree == null:
		return null
	var p := tree.get_first_node_in_group("player")
	if p is Node2D:
		return p as Node2D
	return null


func _update_offscreen_timer(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_offscreen_time = 0.0
		return
	var screen_rect := _get_player_screen_rect()
	if screen_rect.has_point(global_position):
		_offscreen_time = 0.0
	else:
		_offscreen_time += delta


func _get_player_screen_rect() -> Rect2:
	if _player == null:
		return Rect2(global_position, Vector2.ZERO)
	var screen_size := _player.get_viewport_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		screen_size = Vector2(1920.0, 1080.0)
	var top_left := _player.global_position - (screen_size * 0.5)
	return Rect2(top_left, screen_size)
