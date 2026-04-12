extends Area2D
class_name AsteroidBase

enum OrbitState {
	FREE,
	ORBITING,
	LAUNCHED,
}

@export_range(1.0, 50.0, 1.0) var max_hp: float = 3.0
@export_range(4.0, 300.0, 1.0) var radius: float = 24.0
@export_range(10.0, 300.0, 1.0) var speed: float = 42.0
@export_range(0.0, 0.8, 0.01) var drift_variation: float = 0.04
@export_range(0.0, 4.0, 0.05) var drift_frequency: float = 0.45
@export_range(0.0, 6.0, 0.05) var drift_response: float = 0.75
@export_range(-2.0, 2.0, 0.01) var rotation_speed: float = 0.15
@export_range(0.0, 2.0, 0.01) var magnetic_influence: float = 1.0
@export_range(0.1, 4.0, 0.05) var magnetic_resistance: float = 1.0
@export_range(0.0, 400.0, 1.0) var min_pull: float = 14.0
@export_range(0.0, 4.0, 0.05) var velocity_blend: float = 1.4
@export_range(0.0, 4.0, 0.05) var side_damping: float = 0.85
@export_range(0.0, 200.0, 1.0) var pickup_commit_distance: float = 56.0
@export_range(0.0, 120.0, 0.5) var orbital_offset_motion: float = 0.0
@export_range(0.0, 6.0, 0.05) var orbital_frequency: float = 0.0
@export_range(0.0, 120.0, 0.5) var resonance_pulse_motion: float = 0.0
@export_range(0.0, 6.0, 0.05) var resonance_frequency: float = 0.0
@export_range(0.5, 10.0, 0.1) var player_progress_timeout: float = 1.5
@export_range(0.0, 50.0, 0.5) var player_progress_epsilon: float = 2.0
@export var glow_color: Color = Color(0.72, 0.78, 0.84, 1.0)
@export var mid_color: Color = Color(0.6, 0.66, 0.74, 1.0)
@export var core_color: Color = Color(0.82, 0.86, 0.92, 1.0)
@export var death_core_color: Color = Color(0.78, 0.84, 0.9, 1.0)
@export var death_burst_color: Color = Color(0.58, 0.64, 0.72, 1.0)
@export var death_arc_color: Color = Color(0.92, 0.96, 1.0, 1.0)
@export var definition: Resource

var hp: float = 0.0
var velocity: Vector2 = Vector2.ZERO
var world_bounds: Rect2 = Rect2(0.0, 0.0, 0.0, 0.0)
var _has_world_bounds: bool = false
var _pulse_t: float = 0.0
var _hit_flash_left: float = 0.0
var _is_dying: bool = false
var _death_time_left: float = 0.0
var _player: Node2D = null
var _last_player_distance: float = INF
var _no_progress_time: float = 0.0
var _destroyed_by_player: bool = false
var _drift_phase: float = 0.0
var _wobble_phase: float = 0.0
var _resonance_phase: float = 0.0
var _orbit_state: int = OrbitState.FREE
var _orbit_owner: Node2D = null
var _orbit_target_position: Vector2 = Vector2.ZERO
var _launched_by_player: bool = false
var _launch_damage: float = 0.0
var _launch_lifetime_left: float = 0.0
var _orbit_reentry_cooldown_left: float = 0.0
var _orbit_contact_damage_cooldown_left: float = 0.0
var _default_collision_mask: int = 0
var _default_monitoring: bool = true
var _default_monitorable: bool = true

const HIT_FLASH_DURATION: float = 0.1
const DEATH_DURATION: float = 0.2
const HIT_FLASH_BRIGHTNESS_MULT: float = 2.0
const ORBIT_REENTRY_COOLDOWN: float = 0.2
const LAUNCH_LIFETIME: float = 3.5
const LAUNCH_COLLISION_MASK: int = 2
const ORBIT_CONTACT_DAMAGE_COOLDOWN: float = 0.18
const ENERGY_ORB_DROP_MULTIPLIER: int = 1

@export var energy_orb_scene: PackedScene = preload("res://scenes/pickups/energy_orb.tscn")
@export_range(0, 10, 1) var energy_drop_count: int = 1
@export var orb_resource_kind: StringName = &"iron"
var energy_orb_drop_count: int = 0
var orb_value: int = 1


func _ready() -> void:
	_apply_definition()
	hp = max_hp
	_destroyed_by_player = false
	_drift_phase = randf() * TAU
	_wobble_phase = randf() * TAU
	_resonance_phase = randf() * TAU
	if velocity == Vector2.ZERO:
		set_move_direction(Vector2.RIGHT.rotated(randf() * TAU))
	add_to_group("asteroid")
	add_to_group("minable")
	_default_collision_mask = collision_mask
	_default_monitoring = monitoring
	_default_monitorable = monitorable
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	_apply_collision_radius()
	if definition != null and definition.get("definition_id") != null:
		var definition_id := String(definition.get("definition_id"))
		if not definition_id.is_empty():
			add_to_group(definition_id)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_orbit_reentry_cooldown_left = maxf(0.0, _orbit_reentry_cooldown_left - delta)
	_orbit_contact_damage_cooldown_left = maxf(0.0, _orbit_contact_damage_cooldown_left - delta)
	if _is_dying:
		_death_time_left = maxf(0.0, _death_time_left - delta)
		if _death_time_left <= 0.0:
			queue_free()
			return
		queue_redraw()
		return

	if _orbit_state == OrbitState.ORBITING:
		_pulse_t += delta * 1.6
		rotation += rotation_speed * delta * 1.8
		queue_redraw()
		return

	_pulse_t += delta * 1.6
	_hit_flash_left = maxf(0.0, _hit_flash_left - delta)
	_update_drift_motion(delta)
	global_position += _get_step_motion(delta)
	rotation += rotation_speed * delta
	_wrap_in_bounds()
	if _orbit_state == OrbitState.LAUNCHED:
		_launch_lifetime_left = maxf(0.0, _launch_lifetime_left - delta)
		if _launch_lifetime_left <= 0.0:
			queue_free()
			return
	else:
		if _should_timeout_from_player(delta):
			queue_free()
			return
	queue_redraw()


func _draw() -> void:
	if _is_dying:
		_draw_death_burst()
		return

	var pulse := sin(_pulse_t) * 2.0
	var glow_r := radius + 12.0 + pulse
	var mid_r := radius + 5.0 + pulse * 0.5
	var core_r := radius + pulse * 0.2
	var flash_t := _hit_flash_left / HIT_FLASH_DURATION
	var flash_boost := 1.0 + (3.0 * flash_t * HIT_FLASH_BRIGHTNESS_MULT)
	var glow_alpha := 0.18 + (0.22 * flash_t * HIT_FLASH_BRIGHTNESS_MULT)
	var mid_alpha := 0.38 + (0.24 * flash_t * HIT_FLASH_BRIGHTNESS_MULT)

	draw_circle(Vector2.ZERO, glow_r, Color(glow_color.r, glow_color.g, glow_color.b, glow_alpha))
	draw_circle(Vector2.ZERO, mid_r, Color(mid_color.r, mid_color.g, mid_color.b, mid_alpha))
	draw_circle(
		Vector2.ZERO,
		core_r,
		Color(
			minf(1.0, core_color.r * flash_boost),
			minf(1.0, core_color.g * flash_boost),
			minf(1.0, core_color.b * flash_boost),
			0.95
		)
	)

	if _is_dev_mode():
		_draw_dev_overlay()


func _is_dev_mode() -> bool:
	var rs := get_node_or_null("/root/RunState")
	return rs != null and bool(rs.developer_mode_enabled)


func _draw_dev_overlay() -> void:
	var overlay_spd := velocity.length()
	var overlay_angle_deg := fmod(rad_to_deg(velocity.angle()) + 360.0, 360.0)
	var hp_text := "HP %.0f/%.0f" % [hp, max_hp]
	var stat_text := "SPD %.0f  DIR %.0f°  R %.0f  DROP %d" % [overlay_spd, overlay_angle_deg, radius, energy_drop_count]
	var font_legacy := ThemeDB.fallback_font
	var font_size_legacy := 11
	var text_origin := Vector2(-radius - 8.0, -radius - 20.0)

	draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)

	var arrow_color_legacy := Color(1.0, 0.85, 0.1, 0.9)
	if overlay_spd > 0.1:
		var dir := velocity.normalized()
		var arrow_tip := dir * (radius + 22.0)
		draw_line(Vector2.ZERO, arrow_tip, arrow_color_legacy, 1.5)
		draw_line(arrow_tip, arrow_tip - dir * 9.0 + dir.orthogonal() * 5.0, arrow_color_legacy, 1.5)
		draw_line(arrow_tip, arrow_tip - dir * 9.0 - dir.orthogonal() * 5.0, arrow_color_legacy, 1.5)

	draw_string(font_legacy, text_origin + Vector2(1.0, 1.0), hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size_legacy, Color(0.0, 0.0, 0.0, 0.75))
	draw_string(font_legacy, text_origin, hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size_legacy, Color(1.0, 0.48, 0.48, 1.0))
	draw_string(font_legacy, text_origin + Vector2(1.0, 15.0), stat_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size_legacy, Color(0.0, 0.0, 0.0, 0.75))
	draw_string(font_legacy, text_origin + Vector2(0.0, 14.0), stat_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size_legacy, Color(1.0, 0.95, 0.3, 1.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return

	var spd := velocity.length()
	var angle_deg := fmod(rad_to_deg(velocity.angle()) + 360.0, 360.0)

	# Yön oku
	var arrow_color := Color(1.0, 0.85, 0.1, 0.9)
	if spd > 0.1:
		var arrow_tip := velocity.normalized() * (radius + 22.0)
		var left  := (arrow_tip - velocity.normalized() * 10.0).rotated( 0.45) * 0.55 + velocity.normalized() * (radius + 22.0 - 10.0)
		var right := (arrow_tip - velocity.normalized() * 10.0).rotated(-0.45) * 0.55 + velocity.normalized() * (radius + 22.0 - 10.0)
		draw_line(Vector2.ZERO, arrow_tip, arrow_color_legacy, 1.5)
		draw_line(arrow_tip, arrow_tip - velocity.normalized() * 9.0 + velocity.normalized().orthogonal() *  5.0, arrow_color_legacy, 1.5)
		draw_line(arrow_tip, arrow_tip - velocity.normalized() * 9.0 + velocity.normalized().orthogonal() * -5.0, arrow_color_legacy, 1.5)

	# Metin: hız ve açı
	var font := ThemeDB.fallback_font
	var font_size := 11
	var label := "%.0f px/s  %.0f°" % [spd, angle_deg]
	var text_pos := Vector2(-radius, -radius - 10.0)
	# Gölge (okunabilirlik için)
	draw_string(font_legacy, text_pos + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size_legacy, Color(0, 0, 0, 0.75))
	draw_string(font_legacy, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size_legacy, Color(1.0, 0.95, 0.3, 1.0))


func set_move_direction(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		velocity = Vector2.RIGHT * speed
		return
	velocity = dir.normalized() * speed


func set_world_bounds(bounds: Rect2) -> void:
	world_bounds = bounds
	_has_world_bounds = true


func set_speed(new_speed: float) -> void:
	speed = maxf(1.0, new_speed)
	if velocity != Vector2.ZERO:
		velocity = velocity.normalized() * speed


func set_player(player_node: Node2D) -> void:
	_player = player_node
	if _player != null and is_instance_valid(_player):
		_last_player_distance = global_position.distance_to(_player.global_position)
		_no_progress_time = 0.0


func take_mining_damage(amount: float, is_crit: bool = false) -> void:
	if _is_dying:
		return
	if _orbit_state == OrbitState.ORBITING:
		return
	if amount <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	_spawn_damage_number(amount, is_crit)
	if hp <= 0.0:
		_destroyed_by_player = true
		_start_death()
		return
	_hit_flash_left = HIT_FLASH_DURATION


func _spawn_damage_number(amount: float, is_crit: bool) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var parent := tree.current_scene
	if parent == null:
		return
	var num := _damage_number_scene().instantiate()
	parent.add_child(num)
	var offset := Vector2(randf_range(-radius * 0.35, radius * 0.35), randf_range(-radius * 0.5, 0.0))
	num.global_position = global_position + offset
	if num.has_method("setup"):
		num.call("setup", amount, is_crit)


static func _damage_number_scene() -> PackedScene:
	return load("res://scenes/effects/damage_number.tscn")


func on_mined(_collector: Node) -> void:
	if _is_dying:
		return
	_destroyed_by_player = true
	take_mining_damage(max_hp)


func can_enter_orbit() -> bool:
	if _is_dying:
		return false
	if _orbit_state == OrbitState.ORBITING:
		return false
	if _orbit_reentry_cooldown_left > 0.0:
		return false
	return true


func enter_orbit(owner: Node2D) -> void:
	if not can_enter_orbit():
		return
	_orbit_state = OrbitState.ORBITING
	_orbit_owner = owner
	_launched_by_player = false
	_launch_damage = 0.0
	_launch_lifetime_left = 0.0
	velocity = Vector2.ZERO
	collision_mask = _default_collision_mask


func update_orbit_motion(target_pos: Vector2, delta: float, follow_lerp: float) -> void:
	if _orbit_state != OrbitState.ORBITING:
		return
	# Wrap-aware hedef: oyuncu dünya sınırından geçince asteroid'in kısa yolu
	# (sınır boyunca) almasını sağlar. Olmadan asteroid tüm dünyayı dolaşırdı.
	var effective_target := target_pos
	if _has_world_bounds:
		effective_target = WorldWrap.closest_wrapped_target(global_position, target_pos, world_bounds)
	_orbit_target_position = effective_target
	var prev_position := global_position
	var weight := clampf(delta * maxf(1.0, follow_lerp), 0.0, 1.0)
	global_position = global_position.lerp(effective_target, weight)
	# Orbit state _physics_process'te erken return yapar; wrap burada elle yapılır.
	if _has_world_bounds and WorldWrap.needs_wrap(global_position, world_bounds):
		global_position = WorldWrap.apply(global_position, world_bounds)
	var step := global_position - prev_position
	if delta > 0.0001:
		velocity = step / delta
	if step.length_squared() > 0.0001:
		rotation = step.angle()


func launch_from_orbit(origin: Vector2, force: float, damage: float, player_velocity: Vector2 = Vector2.ZERO, player_speed_boost: float = 1.0, launch_direction: Vector2 = Vector2.ZERO) -> void:
	if _orbit_state != OrbitState.ORBITING:
		return
	var launch_dir := launch_direction
	if launch_dir.length_squared() <= 0.0001:
		launch_dir = global_position - origin
	if launch_dir.length_squared() <= 0.0001:
		launch_dir = Vector2.RIGHT.rotated(randf() * TAU)
	launch_dir = launch_dir.normalized()
	var forward_player_speed := maxf(0.0, player_velocity.dot(launch_dir))
	_orbit_state = OrbitState.LAUNCHED
	_orbit_owner = null
	_launched_by_player = true
	_launch_damage = maxf(0.0, damage)
	_launch_lifetime_left = LAUNCH_LIFETIME
	_orbit_reentry_cooldown_left = ORBIT_REENTRY_COOLDOWN
	velocity = launch_dir * (maxf(speed, force) + (forward_player_speed * maxf(0.0, player_speed_boost)))
	collision_mask = LAUNCH_COLLISION_MASK
	monitoring = _default_monitoring
	monitorable = _default_monitorable


func is_player_friendly() -> bool:
	return _orbit_state == OrbitState.ORBITING or (_orbit_state == OrbitState.LAUNCHED and _launched_by_player)


func mining_pull_to(target_pos: Vector2, field_radius: float, accel: float, max_pull_speed: float, delta: float) -> void:
	_apply_field_pull(
		target_pos,
		field_radius,
		accel,
		min_pull,
		max_pull_speed,
		velocity_blend,
		side_damping,
		_get_pickup_commit_distance(),
		magnetic_influence,
		magnetic_resistance,
		delta
	)


func apply_storm_pull(target_pos: Vector2, field_radius: float, pull_strength: float, storm_min_pull: float, storm_max_pull_speed: float, storm_velocity_blend: float, storm_side_damping: float, storm_commit_distance: float, delta: float) -> void:
	_apply_field_pull(
		target_pos,
		field_radius,
		pull_strength,
		storm_min_pull,
		storm_max_pull_speed,
		storm_velocity_blend,
		storm_side_damping,
		storm_commit_distance,
		maxf(0.15, magnetic_influence * 1.1),
		maxf(0.1, magnetic_resistance * 0.9),
		delta
	)


func apply_storm_flow(flow_direction: Vector2, speed_multiplier: float, drift_noise: float, intensity: float, delta: float) -> void:
	if _is_dying:
		return
	if flow_direction == Vector2.ZERO or intensity <= 0.0:
		return
	if velocity.length_squared() <= 0.0001:
		set_move_direction(flow_direction)
	var current_dir: Vector2 = velocity.normalized()
	var flow_dir: Vector2 = flow_direction.normalized()
	var noise_dir: Vector2 = flow_dir.rotated(sin((_pulse_t * (1.8 + drift_frequency)) + _drift_phase) * drift_noise)
	var desired_dir: Vector2 = current_dir.slerp(noise_dir, clampf(delta * (0.8 + intensity * 1.6), 0.0, 1.0)).normalized()
	var target_speed: float = speed * lerpf(1.0, maxf(1.0, speed_multiplier), clampf(intensity, 0.0, 1.0))
	var desired_velocity: Vector2 = desired_dir * maxf(target_speed, velocity.length())
	velocity = velocity.lerp(desired_velocity, clampf(delta * (1.2 + intensity * 1.4), 0.0, 1.0))


func _apply_field_pull(target_pos: Vector2, field_radius: float, accel: float, field_min_pull: float, field_max_pull_speed: float, field_velocity_blend: float, field_side_damping: float, field_commit_distance: float, field_influence: float, field_resistance: float, delta: float) -> void:
	if _is_dying:
		return
	var to_target := target_pos - global_position
	var distance_sq: float = to_target.length_squared()
	if distance_sq <= 0.0001:
		return
	if velocity.length_squared() <= 0.0001:
		set_move_direction(to_target.normalized())

	var current_velocity: Vector2 = velocity
	var current_speed: float = maxf(speed, current_velocity.length())
	var target_dir: Vector2 = to_target.normalized()
	var current_dir: Vector2 = current_velocity.normalized()
	var max_speed_limit: float = maxf(speed, field_max_pull_speed)
	var field_size: float = maxf(field_radius, maxf(field_commit_distance, radius * 1.2))
	var distance: float = sqrt(distance_sq)
	var normalized_distance: float = clampf(distance / maxf(field_size, 1.0), 0.0, 1.0)
	var proximity_strength: float = 1.0 - normalized_distance
	var effective_resistance: float = maxf(0.1, field_resistance)
	var gravity_strength: float = clampf((maxf(0.0, accel) / maxf(1.0, field_max_pull_speed)) * field_influence / effective_resistance, 0.0, 3.0)
	var pull_force: float = maxf(field_min_pull, accel * gravity_strength * lerpf(0.2, 1.65, proximity_strength))
	var desired_dir: Vector2 = current_dir.slerp(target_dir, clampf((pull_force / maxf(1.0, max_speed_limit)) * delta * 6.0, 0.0, 1.0)).normalized()
	var tangent_dir: Vector2 = target_dir.orthogonal()
	var orbit_sign: float = signf(current_dir.cross(target_dir))
	if is_zero_approx(orbit_sign):
		orbit_sign = 1.0 if sin((_pulse_t * 0.7) + _wobble_phase) >= 0.0 else -1.0
	var orbit_mix: float = clampf(proximity_strength * (current_speed / maxf(1.0, max_speed_limit)) * 0.22 * effective_resistance, 0.0, 0.28)
	desired_dir = (desired_dir + (tangent_dir * orbit_sign * orbit_mix)).normalized()
	if orbital_offset_motion > 0.0:
		var anomaly_mix: float = minf(0.45, orbital_offset_motion / maxf(1.0, radius * 5.0))
		var anomaly_sign: float = sin((_pulse_t * maxf(0.1, orbital_frequency)) + _wobble_phase)
		desired_dir = (desired_dir + (desired_dir.orthogonal() * anomaly_sign * anomaly_mix)).normalized()

	var radial_speed: float = current_velocity.dot(target_dir)
	var radial_velocity: Vector2 = target_dir * radial_speed
	var sideways_velocity: Vector2 = current_velocity - radial_velocity
	var sideways_damp: float = clampf(delta * field_side_damping * lerpf(0.65, 2.4, proximity_strength), 0.0, 0.55)
	sideways_velocity *= 1.0 - sideways_damp

	var inward_accel: Vector2 = target_dir * pull_force
	var tangential_accel: Vector2 = tangent_dir * orbit_sign * pull_force * orbit_mix * 0.75
	var warped_velocity: Vector2 = radial_velocity + sideways_velocity + ((inward_accel + tangential_accel) * delta)
	var commit_distance: float = maxf(field_commit_distance, radius * 1.2)
	if distance <= commit_distance:
		var commit_ratio: float = 1.0 - clampf(distance / maxf(commit_distance, 1.0), 0.0, 1.0)
		warped_velocity = warped_velocity.lerp(target_dir * maxf(current_speed, field_min_pull * 2.0), clampf(delta * lerpf(5.0, 10.0, commit_ratio), 0.0, 1.0))
	var desired_velocity: Vector2 = desired_dir * minf(max_speed_limit, maxf(speed * 0.8, warped_velocity.length()))
	var blend_weight: float = clampf(delta * field_velocity_blend * lerpf(1.8, 7.0, proximity_strength), 0.0, 1.0)
	velocity = warped_velocity.lerp(desired_velocity, blend_weight)
	if velocity.length_squared() > (max_speed_limit * max_speed_limit):
		velocity = velocity.limit_length(max_speed_limit)
	elif velocity.length_squared() < (speed * speed * 0.55):
		velocity = velocity.normalized() * (speed * 0.55)


func _get_pickup_commit_distance() -> float:
	return maxf(pickup_commit_distance, radius * 1.2)


func _update_drift_motion(delta: float) -> void:
	if velocity.length_squared() <= 0.0001:
		return
	if drift_variation <= 0.0 or drift_frequency <= 0.0:
		velocity = velocity.normalized() * speed
		return

	var current_dir := velocity.normalized()
	var offset_angle := sin((_pulse_t * drift_frequency) + _drift_phase) * drift_variation
	var desired_dir := current_dir.rotated(offset_angle * delta)
	current_dir = current_dir.slerp(desired_dir, clampf(drift_response * delta, 0.0, 1.0)).normalized()
	velocity = current_dir * speed


func _get_step_motion(delta: float) -> Vector2:
	var motion := velocity * delta
	if velocity.length_squared() <= 0.0001:
		return motion

	var dir := velocity.normalized()
	if orbital_offset_motion > 0.0 and orbital_frequency > 0.0:
		motion += dir.orthogonal() * sin((_pulse_t * orbital_frequency) + _wobble_phase) * orbital_offset_motion * delta
	if resonance_pulse_motion > 0.0 and resonance_frequency > 0.0:
		motion += dir * sin((_pulse_t * resonance_frequency) + _resonance_phase) * resonance_pulse_motion * delta
	return motion


func _start_death() -> void:
	_is_dying = true
	_death_time_left = DEATH_DURATION
	_orbit_state = OrbitState.FREE
	_orbit_owner = null
	velocity = Vector2.ZERO
	monitoring = false
	monitorable = false
	_hit_flash_left = 0.0
	_spawn_energy_orbs()
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null:
		shape_node.disabled = true
	queue_redraw()


func _draw_death_burst() -> void:
	var t := 1.0 - (_death_time_left / DEATH_DURATION)
	var core_radius := lerpf(radius, radius * 1.25, t)
	var burst_radius := lerpf(radius * 0.55, radius * 1.6, t)
	var fade := pow(1.0 - t, 1.2)
	var lethal_flash_mul := 4.0

	draw_circle(Vector2.ZERO, core_radius * 0.9, Color(1.0, 1.0, 0.95, minf(1.0, 0.3 * lethal_flash_mul) * fade))
	draw_circle(Vector2.ZERO, core_radius, Color(death_core_color.r, death_core_color.g, death_core_color.b, 0.95 * fade))
	draw_circle(Vector2.ZERO, burst_radius, Color(death_burst_color.r, death_burst_color.g, death_burst_color.b, 0.45 * fade))
	draw_arc(Vector2.ZERO, burst_radius, 0.0, TAU, 96, Color(death_arc_color.r, death_arc_color.g, death_arc_color.b, 0.95 * fade), 3.0, true)


func _wrap_in_bounds() -> void:
	if not _has_world_bounds:
		return
	if _player != null and is_instance_valid(_player):
		# Oyuncuya en kısa wrap yolunu hesapla ve o konuma geç.
		# Oyuncu sınırı geçince asteroid de aynı tarafta kalır —
		# geçiş bölgesinde görsel sürekliliği sağlar.
		var target := WorldWrap.closest_wrapped_target(
			_player.global_position, global_position, world_bounds
		)
		if target.distance_squared_to(global_position) > 0.5:
			global_position = target
	else:
		# Oyuncu bilinmiyorsa standart wrap uygula.
		if not WorldWrap.needs_wrap(global_position, world_bounds):
			return
		global_position = WorldWrap.apply(global_position, world_bounds)


func _apply_collision_radius() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	if shape_node.shape is CircleShape2D:
		var circle := shape_node.shape as CircleShape2D
		circle.radius = radius


func _spawn_energy_orbs() -> void:
	if energy_orb_scene == null:
		return
	var tree := get_tree()
	if tree == null:
		return
	var parent: Node = tree.current_scene
	if parent == null:
		parent = tree.root

	var total_drop_count := maxi(energy_drop_count, 0) * ENERGY_ORB_DROP_MULTIPLIER
	var collector := _find_drop_collector()
	for _i in range(total_drop_count):
		var orb := energy_orb_scene.instantiate()
		if orb == null:
			continue
		if orb is Node2D:
			(orb as Node2D).global_position = global_position
		parent.add_child(orb)
		if orb.has_method("setup"):
			orb.call("setup", collector, radius, orb_resource_kind)
		if orb_value > 1:
			match orb_resource_kind:
				&"iron":
					if "iron_value" in orb:
						orb.iron_value = orb_value
				&"gold", &"crystal", &"uranium":
					if "gold_value" in orb:
						orb.gold_value = orb_value
				&"titanium":
					if "titanium_value" in orb:
						orb.titanium_value = orb_value


func _find_drop_collector() -> Node2D:
	var black_hole := _find_black_hole()
	if black_hole != null:
		var collect_radius := 0.0
		if black_hole.has_method("get_collect_radius"):
			collect_radius = float(black_hole.call("get_collect_radius"))
		elif black_hole.has_method("get_radius"):
			collect_radius = float(black_hole.call("get_radius")) * 0.40
		if collect_radius > 0.0 and global_position.distance_to(black_hole.global_position) <= collect_radius:
			return black_hole
	return _find_player()


func _find_black_hole() -> Node2D:
	var tree := get_tree()
	if tree == null:
		return null
	var bh := tree.get_first_node_in_group("black_hole")
	if bh is Node2D:
		return bh as Node2D
	return null


func _find_player() -> Node2D:
	var tree := get_tree()
	if tree == null:
		return null
	var p := tree.get_first_node_in_group("Player")
	if p is Node2D:
		return p as Node2D
	p = tree.get_first_node_in_group("player")
	if p is Node2D:
		return p as Node2D
	return null


func _on_area_entered(area: Area2D) -> void:
	if _is_dying:
		return
	if area == null or not is_instance_valid(area):
		return
	if area == self:
		return
	if area.has_method("is_player_friendly") and bool(area.call("is_player_friendly")):
		return
	if _orbit_state == OrbitState.ORBITING:
		if _orbit_contact_damage_cooldown_left > 0.0:
			return
		if area.is_in_group("asteroid"):
			_resolve_asteroid_collision(area, false)
			_orbit_contact_damage_cooldown_left = ORBIT_CONTACT_DAMAGE_COOLDOWN
		return
	if _orbit_state != OrbitState.LAUNCHED:
		return
	if area.is_in_group("asteroid"):
		_resolve_asteroid_collision(area, true)
		return
	if area.is_in_group("enemy"):
		if area.has_method("take_damage"):
			area.call("take_damage", _launch_damage)
		queue_free()


func _resolve_asteroid_collision(other: Area2D, destroy_after_hit: bool) -> void:
	if other == null or not is_instance_valid(other):
		return
	var own_damage: float = maxf(0.0, hp)
	var other_hp_variant: Variant = other.get("hp")
	var return_damage: float = 0.0
	if other_hp_variant != null:
		return_damage = maxf(0.0, float(other_hp_variant))

	if other.has_method("take_mining_damage") and own_damage > 0.0:
		other.call("take_mining_damage", own_damage)
	if return_damage > 0.0:
		take_mining_damage(return_damage)
	if destroy_after_hit and not _is_dying:
		queue_free()


func _should_timeout_from_player(delta: float) -> bool:
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
	if _player == null:
		return false

	var player_screen_rect := _get_player_screen_rect()
	if player_screen_rect.has_point(global_position):
		_no_progress_time = 0.0
		_last_player_distance = global_position.distance_to(_player.global_position)
		return false

	var current_distance := global_position.distance_to(_player.global_position)
	if _last_player_distance == INF:
		_last_player_distance = current_distance
		return false

	if current_distance < _last_player_distance - player_progress_epsilon:
		_no_progress_time = 0.0
	else:
		_no_progress_time += delta

	_last_player_distance = current_distance
	return _no_progress_time >= player_progress_timeout


func _get_player_screen_rect() -> Rect2:
	if _player == null:
		return Rect2(global_position, Vector2.ZERO)
	var screen_size := _player.get_viewport_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		screen_size = Vector2(1920.0, 1080.0)
	var top_left := _player.global_position - (screen_size * 0.5)
	return Rect2(top_left, screen_size)


func set_definition(next_definition: Resource) -> void:
	definition = next_definition
	_apply_definition()
	if is_inside_tree():
		_apply_collision_radius()
		queue_redraw()


func _apply_definition() -> void:
	if definition == null:
		return
	max_hp = float(definition.get("max_hp"))
	hp = max_hp
	radius = float(definition.get("radius"))
	speed = float(definition.get("speed"))
	drift_variation = float(definition.get("drift_variation"))
	drift_frequency = float(definition.get("drift_frequency"))
	drift_response = float(definition.get("drift_response"))
	rotation_speed = float(definition.get("rotation_speed"))
	magnetic_influence = float(definition.get("magnetic_influence"))
	magnetic_resistance = float(definition.get("magnetic_resistance"))
	min_pull = float(definition.get("min_pull"))
	velocity_blend = float(definition.get("velocity_blend"))
	side_damping = float(definition.get("side_damping"))
	pickup_commit_distance = float(definition.get("pickup_commit_distance"))
	orbital_offset_motion = float(definition.get("orbital_offset_motion"))
	orbital_frequency = float(definition.get("orbital_frequency"))
	resonance_pulse_motion = float(definition.get("resonance_pulse_motion"))
	resonance_frequency = float(definition.get("resonance_frequency"))
	energy_drop_count = int(definition.get("energy_drop_count"))
	orb_resource_kind = StringName(definition.get("orb_resource_kind"))
	var eod_variant: Variant = definition.get("energy_orb_drop_count")
	energy_orb_drop_count = int(eod_variant) if eod_variant != null else 0
	var ov_variant: Variant = definition.get("orb_value")
	orb_value = int(ov_variant) if ov_variant != null else 1
	glow_color = definition.get("glow_color")
	mid_color = definition.get("mid_color")
	core_color = definition.get("core_color")
	death_core_color = definition.get("death_core_color")
	death_burst_color = definition.get("death_burst_color")
	death_arc_color = definition.get("death_arc_color")
