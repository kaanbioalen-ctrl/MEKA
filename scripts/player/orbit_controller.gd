extends Node2D
class_name OrbitController

const UpgradeEffects = preload("res://scripts/upgrades/upgrade_effects.gd")

@export_range(1, 32, 1) var max_orbit_count: int = 6
@export_range(8.0, 600.0, 1.0) var capture_radius: float = 96.0
@export_range(8.0, 600.0, 1.0) var orbit_radius: float = 42.0
@export_range(-12.0, 12.0, 0.05) var orbit_angular_speed: float = 2.8
@export_range(0.1, 4.0, 0.05) var orbit_mode_speed_multiplier: float = 0.5
@export_range(10.0, 4000.0, 1.0) var launch_force: float = 1100.0
@export_range(0.0, 4.0, 0.05) var player_speed_launch_boost: float = 1.0
@export_range(1.0, 40.0, 0.1) var orbit_pull_lerp: float = 16.0
@export_range(0.0, 500.0, 1.0) var launch_damage: float = 2.0
@export_range(0.0, 5.0, 0.01) var capture_cooldown: float = 0.12
@export_range(0.0, 10.0, 0.01) var auto_release_timeout: float = 0.0

@onready var orbit_collector: Area2D = $OrbitCollector
@onready var orbit_shape: CollisionShape2D = $OrbitCollector/CollisionShape2D

var _player: Node2D = null
var _mode_active: bool = false
var _shared_angle: float = 0.0
var _hold_time: float = 0.0
var _cooldown_left: float = 0.0
var _candidate_map: Dictionary = {}
var _orbiting: Array[Node2D] = []


func _ready() -> void:
	_player = get_parent() as Node2D
	if orbit_collector != null:
		if not orbit_collector.area_entered.is_connected(_on_orbit_collector_area_entered):
			orbit_collector.area_entered.connect(_on_orbit_collector_area_entered)
		if not orbit_collector.area_exited.is_connected(_on_orbit_collector_area_exited):
			orbit_collector.area_exited.connect(_on_orbit_collector_area_exited)
	_apply_capture_radius()
	_rescan_candidates()


func _physics_process(delta: float) -> void:
	var parent_node := get_parent()
	if parent_node is Node2D:
		_player = parent_node as Node2D
	_apply_capture_radius()
	_cleanup_invalid_state()
	_cooldown_left = maxf(0.0, _cooldown_left - delta)

	var pressed := Input.is_action_pressed(&"orbit_mode")
	if pressed and not _mode_active and _cooldown_left <= 0.0:
		_begin_mode()
	elif not pressed and _mode_active:
		_release_all()
		_cooldown_left = capture_cooldown

	if _mode_active:
		_hold_time += delta
		_capture_available_asteroids()
		_update_orbit_positions(delta)
		if auto_release_timeout > 0.0 and _hold_time >= auto_release_timeout:
			_release_all()
			_cooldown_left = capture_cooldown


func _begin_mode() -> void:
	_mode_active = true
	_hold_time = 0.0
	_rescan_candidates()


func _release_all() -> void:
	if _orbiting.is_empty():
		_mode_active = false
		_hold_time = 0.0
		return

	var launch_origin := _player.global_position if is_instance_valid(_player) else global_position
	var launch_direction := _get_release_direction(launch_origin)
	var player_velocity := _get_player_velocity()
	for asteroid in _orbiting:
		if not is_instance_valid(asteroid):
			continue
		if asteroid.has_method("launch_from_orbit"):
			asteroid.call("launch_from_orbit", launch_origin, launch_force, launch_damage, player_velocity, player_speed_launch_boost, launch_direction)

	_orbiting.clear()
	_mode_active = false
	_hold_time = 0.0


func _capture_available_asteroids() -> void:
	if _orbiting.size() >= _get_max_orbit_count():
		return

	var candidates: Array[Node2D] = []
	for candidate_variant in _candidate_map.values():
		var asteroid := candidate_variant as Node2D
		if asteroid == null or not is_instance_valid(asteroid):
			continue
		if asteroid in _orbiting:
			continue
		if asteroid.has_method("can_enter_orbit") and not bool(asteroid.call("can_enter_orbit")):
			continue
		candidates.append(asteroid)

	candidates.sort_custom(Callable(self, "_sort_candidates_by_distance"))

	for asteroid in candidates:
		if _orbiting.size() >= _get_max_orbit_count():
			break
		_capture_asteroid(asteroid)


func _capture_asteroid(asteroid: Node2D) -> void:
	if asteroid == null or not is_instance_valid(asteroid):
		return
	if asteroid in _orbiting:
		return
	if asteroid.has_method("enter_orbit"):
		asteroid.call("enter_orbit", _player)
	_orbiting.append(asteroid)


func _update_orbit_positions(delta: float) -> void:
	if _orbiting.is_empty():
		return
	if not is_instance_valid(_player):
		return

	_shared_angle = wrapf(_shared_angle + (orbit_angular_speed * orbit_mode_speed_multiplier * delta), -TAU, TAU)
	var count := _orbiting.size()
	var center := _player.global_position

	for i in range(count):
		var asteroid := _orbiting[i]
		if asteroid == null or not is_instance_valid(asteroid):
			continue

		var angle := _shared_angle + (TAU * float(i) / float(count))
		var target_pos := center + Vector2.RIGHT.rotated(angle) * orbit_radius
		if asteroid.has_method("update_orbit_motion"):
			asteroid.call("update_orbit_motion", target_pos, delta, orbit_pull_lerp)


func _cleanup_invalid_state() -> void:
	var valid_orbiting: Array[Node2D] = []
	for asteroid in _orbiting:
		if asteroid != null and is_instance_valid(asteroid) and not asteroid.is_queued_for_deletion():
			valid_orbiting.append(asteroid)
	_orbiting = valid_orbiting

	var dead_ids: Array[int] = []
	for id_variant in _candidate_map.keys():
		var id := int(id_variant)
		var asteroid := _candidate_map[id] as Node2D
		if asteroid == null or not is_instance_valid(asteroid) or asteroid.is_queued_for_deletion():
			dead_ids.append(id)
	for id in dead_ids:
		_candidate_map.erase(id)


func _rescan_candidates() -> void:
	if orbit_collector == null:
		return
	for area in orbit_collector.get_overlapping_areas():
		_register_candidate(area)


func _apply_capture_radius() -> void:
	if orbit_shape == null:
		return
	if orbit_shape.shape is CircleShape2D:
		var circle := orbit_shape.shape as CircleShape2D
		if not is_equal_approx(circle.radius, capture_radius):
			circle.radius = capture_radius


func _register_candidate(area: Area2D) -> void:
	if area == null or not is_instance_valid(area):
		return
	if not area.is_in_group("asteroid"):
		return
	_candidate_map[area.get_instance_id()] = area


func _get_max_orbit_count() -> int:
	var run_state := get_node_or_null("/root/RunState")
	return mini(max_orbit_count, maxi(1, UpgradeEffects.get_current_orbit_mode_capacity(run_state)))


func _get_player_velocity() -> Vector2:
	if not is_instance_valid(_player):
		return Vector2.ZERO
	var velocity_variant: Variant = _player.get("velocity")
	if velocity_variant is Vector2:
		return velocity_variant
	return Vector2.ZERO


func _get_release_direction(launch_origin: Vector2) -> Vector2:
	var to_mouse := get_global_mouse_position() - launch_origin
	if to_mouse.length_squared() > 0.0001:
		return to_mouse.normalized()
	var player_velocity := _get_player_velocity()
	if player_velocity.length_squared() > 0.0001:
		return player_velocity.normalized()
	return Vector2.RIGHT


func _on_orbit_collector_area_entered(area: Area2D) -> void:
	_register_candidate(area)


func _on_orbit_collector_area_exited(area: Area2D) -> void:
	if area == null:
		return
	_candidate_map.erase(area.get_instance_id())


func _sort_candidates_by_distance(a: Node2D, b: Node2D) -> bool:
	if not is_instance_valid(_player):
		return true
	return a.global_position.distance_squared_to(_player.global_position) < b.global_position.distance_squared_to(_player.global_position)
