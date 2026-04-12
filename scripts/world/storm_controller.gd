extends Node2D
class_name StormController

const StormFlowLayer = preload("res://scripts/effects/storm_flow_layer.gd")
const StormGlowLayer = preload("res://scripts/effects/storm_glow_layer.gd")
const StormPlasmaLayer = preload("res://scripts/effects/storm_plasma_layer.gd")
const StormVortexLayer = preload("res://scripts/effects/storm_vortex_layer.gd")
const LIGHTNING_SCENE: PackedScene = preload("res://scenes/effects/lightning_arc.tscn")
const PORTAL_SCENE: PackedScene = preload("res://scenes/world/portal.tscn")

enum StormState {
	IDLE,
	WARNING,
	ACTIVE,
	FADING,
}

@export var player_group: StringName = &"player"
@export var random_seed_mode: bool = true
@export var auto_start_enabled: bool = true
@export var start_immediately_on_ready: bool = true
@export_range(0.0, 1.0, 0.001) var auto_trigger_chance_per_second: float = 0.01
@export_range(1.0, 20.0, 0.1) var warning_duration: float = 3.0
@export_range(2.0, 120.0, 0.1) var storm_duration: float = 36.0
@export_range(1.0, 20.0, 0.1) var fade_duration: float = 4.0
@export_range(0.5, 3.0, 0.05) var storm_intensity: float = 1.0
@export_range(16.0, 320.0, 1.0) var particle_density: float = 74.0
@export_range(20.0, 1200.0, 1.0) var energy_flow_speed: float = 210.0
@export_range(0.05, 5.0, 0.01) var lightning_interval_min: float = 0.18
@export_range(0.05, 5.0, 0.01) var lightning_interval_max: float = 0.55
@export_range(0.03, 2.0, 0.01) var lightning_lifetime: float = 0.18
@export_range(1.0, 4.0, 0.05) var asteroid_velocity_multiplier: float = 1.45
@export_range(0.0, 1.0, 0.01) var asteroid_drift_noise: float = 0.2
@export_range(0.0, 4.0, 0.05) var player_energy_modifier: float = 1.2
@export_range(0.0, 20.0, 0.05) var player_energy_gain_per_second: float = 10.0
@export_range(0.0, 1.0, 0.01) var player_energy_outer_gain_ratio: float = 0.1
@export_range(0.0, 3.0, 0.05) var glow_boost: float = 0.068
@export_range(40.0, 1200.0, 1.0) var storm_radius: float = 93.0
@export_range(10.0, 2000.0, 1.0) var pull_strength: float = 260.0
@export_range(0.0, 400.0, 1.0) var min_pull: float = 30.0
@export_range(20.0, 2000.0, 1.0) var max_pull_speed: float = 360.0
@export_range(0.1, 8.0, 0.05) var velocity_blend: float = 2.0
@export_range(0.0, 4.0, 0.05) var side_damping: float = 1.1
@export_range(0.0, 200.0, 1.0) var pickup_commit_distance: float = 48.0
@export_range(10.0, 800.0, 1.0) var storm_move_speed: float = 90.0

var _player: Node2D = null
var _state: int = StormState.IDLE
var _state_time_left: float = 0.0
var _lightning_time_left: float = 0.0
var _visual_t: float = 0.0
var _flow_direction: Vector2 = Vector2.RIGHT
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _vortex_layer: Node2D = null
var _flow_layer: Node2D = null
var _plasma_layer: Node2D = null
var _glow_layer: Node2D = null
var _arc_layer: Node2D = null
var _world_bounds: Rect2 = Rect2(0.0, 0.0, 0.0, 0.0)
var _has_world_bounds: bool = false
var _storm_velocity: Vector2 = Vector2.ZERO
var _portal: Node2D = null


func configure(player: Node2D, world_bounds: Rect2 = Rect2(0.0, 0.0, 0.0, 0.0)) -> void:
	_player = player
	_world_bounds = world_bounds
	_has_world_bounds = world_bounds.size.x > 0.0 and world_bounds.size.y > 0.0
	_pick_flow_direction()
	_pick_start_position()
	_spawn_portal()


func _ready() -> void:
	if random_seed_mode:
		_rng.randomize()
	else:
		_rng.seed = 1337
	_find_player()
	_create_visual_layers()
	set_process(true)
	set_physics_process(true)
	if start_immediately_on_ready:
		_start_storm_immediately()


func _process(delta: float) -> void:
	_visual_t += delta
	_update_visual_state()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_find_player()

	_sync_portal_position()
	match _state:
		StormState.IDLE:
			if auto_start_enabled and _rng.randf() < auto_trigger_chance_per_second * delta:
				trigger_storm()
		StormState.WARNING:
			_tick_state(delta)
			_move_storm(delta, 0.65)
			if _state_time_left <= 0.0:
				_enter_active()
		StormState.ACTIVE:
			_tick_state(delta)
			_move_storm(delta, 1.0)
			_apply_storm_to_world(delta, 1.0)
			_tick_lightning(delta, 1.0)
			if _state_time_left <= 0.0:
				_enter_fading()
		StormState.FADING:
			_tick_state(delta)
			_move_storm(delta, 0.55)
			_apply_storm_to_world(delta, _get_phase_alpha())
			_tick_lightning(delta, 0.45)
			if _state_time_left <= 0.0:
				_end_storm()


func trigger_storm() -> void:
	if _state != StormState.IDLE:
		return
	_state = StormState.WARNING
	_state_time_left = warning_duration
	_lightning_time_left = _rand_lightning_interval()
	_pick_flow_direction()
	_pick_start_position()


func stop_storm_immediately() -> void:
	_end_storm()


func is_active() -> bool:
	return _state == StormState.ACTIVE or _state == StormState.FADING


func get_storm_position() -> Vector2:
	return global_position


func _start_storm_immediately() -> void:
	if _state != StormState.IDLE:
		return
	_pick_flow_direction()
	_pick_start_position()
	_enter_active()


func _enter_active() -> void:
	_state = StormState.ACTIVE
	_state_time_left = storm_duration
	_lightning_time_left = 0.05
	_spawn_portal()


func _spawn_portal() -> void:
	if PORTAL_SCENE == null:
		return
	if is_instance_valid(_portal):
		return
	# Sahneye world.gd tarafından önceden eklenmiş portal varsa onu benimse
	var tree := get_tree()
	if tree != null:
		var existing := tree.get_first_node_in_group("portal")
		if is_instance_valid(existing):
			_portal = existing as Node2D
			return
	var parent := get_parent()
	if parent == null:
		return
	_portal = PORTAL_SCENE.instantiate() as Node2D
	if _portal == null:
		return
	_portal.global_position = global_position
	parent.add_child(_portal)


func _enter_fading() -> void:
	_state = StormState.FADING
	_state_time_left = fade_duration


func _end_storm() -> void:
	_state = StormState.IDLE
	_state_time_left = 0.0
	_lightning_time_left = 0.0
	_apply_player_feedback(0.0, 0.0)
	_update_effect_layers(0.0)


func _tick_state(delta: float) -> void:
	_state_time_left = maxf(0.0, _state_time_left - delta)


func _tick_lightning(delta: float, strength_scale: float) -> void:
	_lightning_time_left -= delta
	if _lightning_time_left > 0.0:
		return
	_spawn_lightning_arc(strength_scale)
	_lightning_time_left = _rand_lightning_interval()


func _apply_storm_to_world(delta: float, phase_alpha: float) -> void:
	_apply_player_feedback(phase_alpha, delta)
	var asteroids: Array = get_tree().get_nodes_in_group("asteroid")
	for asteroid in asteroids:
		var asteroid_node := asteroid as Node2D
		if asteroid_node == null:
			continue
		var distance := asteroid_node.global_position.distance_to(global_position)
		if distance > storm_radius:
			continue
		if asteroid_node.has_method("apply_storm_pull"):
			asteroid_node.call(
				"apply_storm_pull",
				global_position,
				storm_radius,
				pull_strength * storm_intensity * phase_alpha,
				min_pull,
				max_pull_speed * asteroid_velocity_multiplier,
				velocity_blend,
				side_damping,
				pickup_commit_distance,
				delta
			)
		if asteroid_node.has_method("apply_storm_flow"):
			asteroid_node.call(
				"apply_storm_flow",
				_flow_direction,
				asteroid_velocity_multiplier,
				asteroid_drift_noise,
				storm_intensity * phase_alpha,
				delta
			)


func _apply_player_feedback(phase_alpha: float, delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var distance := _player.global_position.distance_to(global_position)
	if distance > storm_radius:
		phase_alpha = 0.0
	else:
		phase_alpha *= 1.0 - clampf(distance / maxf(storm_radius, 1.0), 0.0, 1.0)
	if _player.has_method("set_storm_feedback"):
		_player.call(
			"set_storm_feedback",
			phase_alpha > 0.0,
			glow_boost * phase_alpha,
			lerpf(1.0, player_energy_modifier, phase_alpha)
		)
	if phase_alpha <= 0.0:
		return
	if not _player.has_method("add_energy"):
		return
	var proximity := clampf(distance / maxf(storm_radius, 1.0), 0.0, 1.0)
	var gain_ratio := 1.0 - proximity
	var energy_gain_scale := lerpf(player_energy_outer_gain_ratio, 1.0, gain_ratio)
	var energy_gain := player_energy_gain_per_second * energy_gain_scale * phase_alpha
	if energy_gain > 0.0:
		_player.call("add_energy", energy_gain * delta)


func _update_visual_state() -> void:
	var phase_alpha: float = _get_phase_alpha()
	_update_effect_layers(phase_alpha)


func _update_effect_layers(phase_alpha: float) -> void:
	if _vortex_layer != null and _vortex_layer.has_method("set_storm_params"):
		_vortex_layer.call("set_storm_params", storm_radius, phase_alpha * storm_intensity)
	if _flow_layer != null and _flow_layer.has_method("set_storm_params"):
		_flow_layer.call(
			"set_storm_params",
			storm_radius,
			particle_density * lerpf(0.35, 1.0, phase_alpha),
			energy_flow_speed,
			storm_intensity,
			phase_alpha * 0.45,
			_flow_direction
		)
	if _plasma_layer != null and _plasma_layer.has_method("set_storm_params"):
		_plasma_layer.call(
			"set_storm_params",
			storm_radius * 0.92,
			particle_density * 0.62 * lerpf(0.2, 1.0, phase_alpha),
			energy_flow_speed * 0.7,
			storm_intensity,
			phase_alpha * 0.5,
			_flow_direction
		)
	if _glow_layer != null and _glow_layer.has_method("set_storm_params"):
		var warning_mul: float = 0.55 if _state == StormState.WARNING else 1.0
		_glow_layer.call(
			"set_storm_params",
			storm_radius * 1.08,
			phase_alpha * warning_mul,
			storm_intensity
		)


func _spawn_lightning_arc(strength_scale: float) -> void:
	if LIGHTNING_SCENE == null or _arc_layer == null or not is_instance_valid(_player):
		return
	var arc := LIGHTNING_SCENE.instantiate()
	if arc == null:
		return
	var start: Vector2 = _random_point_on_rotating_band(0.72, 0.92)
	var end: Vector2 = _random_point_on_rotating_band(0.78, 1.08)
	if start.distance_to(end) < storm_radius * 0.22:
		end = _random_point_on_rotating_band(0.9, 1.15)
	_arc_layer.add_child(arc)
	if arc.has_method("configure"):
		arc.call("configure", start, end, lightning_lifetime * lerpf(0.9, 1.25, strength_scale), clampf(storm_intensity * strength_scale, 0.0, 1.0))


func _random_point_in_storm(min_ratio: float, max_ratio: float) -> Vector2:
	var angle: float = _rng.randf() * TAU
	var dist: float = storm_radius * _rng.randf_range(min_ratio, max_ratio)
	return global_position + (Vector2.RIGHT.rotated(angle) * dist)


func _random_point_on_rotating_band(min_ratio: float, max_ratio: float) -> Vector2:
	var rotating_angle: float = (_visual_t * 1.8) + (_rng.randf_range(-0.45, 0.45) * PI)
	var band_angle: float = rotating_angle + (_rng.randf() * TAU / 3.0)
	var dist: float = storm_radius * _rng.randf_range(min_ratio, max_ratio)
	return global_position + (Vector2.RIGHT.rotated(band_angle) * dist)


func _pick_flow_direction() -> void:
	var base_angle: float = _rng.randf() * TAU
	_flow_direction = Vector2.RIGHT.rotated(base_angle)
	_storm_velocity = _flow_direction * storm_move_speed


func _pick_start_position() -> void:
	if _has_world_bounds:
		global_position = Vector2(
			_rng.randf_range(_world_bounds.position.x + storm_radius, _world_bounds.end.x - storm_radius),
			_rng.randf_range(_world_bounds.position.y + storm_radius, _world_bounds.end.y - storm_radius)
		)
		return
	if is_instance_valid(_player):
		global_position = _player.global_position + (Vector2.RIGHT.rotated(_rng.randf() * TAU) * storm_radius * 1.4)


func _move_storm(delta: float, speed_scale: float) -> void:
	if _storm_velocity == Vector2.ZERO:
		_storm_velocity = _flow_direction * storm_move_speed
	global_position += _storm_velocity * speed_scale * delta
	if not _has_world_bounds:
		return
	var margin := storm_radius * 0.8
	var bounced := false
	if global_position.x < _world_bounds.position.x + margin:
		global_position.x = _world_bounds.position.x + margin
		_storm_velocity.x = absf(_storm_velocity.x)
		bounced = true
	elif global_position.x > _world_bounds.end.x - margin:
		global_position.x = _world_bounds.end.x - margin
		_storm_velocity.x = -absf(_storm_velocity.x)
		bounced = true
	if global_position.y < _world_bounds.position.y + margin:
		global_position.y = _world_bounds.position.y + margin
		_storm_velocity.y = absf(_storm_velocity.y)
		bounced = true
	elif global_position.y > _world_bounds.end.y - margin:
		global_position.y = _world_bounds.end.y - margin
		_storm_velocity.y = -absf(_storm_velocity.y)
		bounced = true
	if bounced:
		_flow_direction = _storm_velocity.normalized()


func _sync_portal_position() -> void:
	if is_instance_valid(_portal):
		_portal.global_position = global_position


func _rand_lightning_interval() -> float:
	return _rng.randf_range(lightning_interval_min, maxf(lightning_interval_min, lightning_interval_max))


func _get_phase_alpha() -> float:
	if _state == StormState.WARNING:
		var warning_ratio := 1.0 - clampf(_state_time_left / maxf(warning_duration, 0.001), 0.0, 1.0)
		return lerpf(0.18, 0.62, warning_ratio)
	if _state == StormState.ACTIVE:
		return 1.0
	if _state == StormState.FADING:
		return clampf(_state_time_left / maxf(fade_duration, 0.001), 0.0, 1.0)
	return 0.0


func _find_player() -> void:
	var tree := get_tree()
	if tree == null:
		_player = null
		return
	_player = tree.get_first_node_in_group(player_group) as Node2D


func _create_visual_layers() -> void:
	# Vortex spiral (bottom — rendered first so arcs appear on top)
	_vortex_layer = Node2D.new()
	_vortex_layer.name = "VortexLayer"
	_vortex_layer.set_script(StormVortexLayer)
	add_child(_vortex_layer)

	_flow_layer = Node2D.new()
	_flow_layer.name = "EnergyFlowLayer"
	_flow_layer.set_script(StormFlowLayer)
	add_child(_flow_layer)

	_plasma_layer = Node2D.new()
	_plasma_layer.name = "PlasmaLayer"
	_plasma_layer.set_script(StormPlasmaLayer)
	add_child(_plasma_layer)

	_glow_layer = Node2D.new()
	_glow_layer.name = "GlowLayer"
	_glow_layer.set_script(StormGlowLayer)
	add_child(_glow_layer)

	_arc_layer = Node2D.new()
	_arc_layer.name = "LightningArcLayer"
	add_child(_arc_layer)
