extends CharacterBody2D
## Player controller — Godot 4, production-quality movement.
##
## JITTER FIXES:
##   1. Camera2D position_smoothing disabled in _ready() (was the primary jitter source:
##      smoothing on a CharacterBody2D child creates viewport lag at high refresh rates).
##   2. Physics interpolation: visual_root + camera.offset lerp between physics ticks
##      in _process(), eliminating stutter on 120/144Hz+ displays.
##
## MOUSE CONTROL FIX:
##   Mouse distance now measured in SCREEN PIXELS (viewport space), not world units.
##   This makes responsiveness zoom-independent and requires far less mouse movement.

const UpgradeEffects = preload("res://scripts/upgrades/upgrade_effects.gd")

signal died
signal energy_full

# ── Movement: mouse steering ───────────────────────────────────────────────────
## Screen pixels from center below which input is ignored (prevents micro-drift).
@export_range(0.0, 120.0, 1.0)  var mouse_deadzone_px:    float = 20.0
## Screen pixels from center at which max speed is reached. Smaller = more reactive.
@export_range(50.0, 700.0, 1.0) var mouse_full_speed_px:  float = 240.0
## Scales raw screen offset before the curve. 1.0 = neutral, 1.5 = 50% more reactive.
@export_range(0.5, 3.0, 0.05)   var mouse_sensitivity:    float = 1.2
## Speed ramp shape. 1.0 = linear, 1.6 = slow-start then fast.
@export_range(1.0, 4.0, 0.05)   var mouse_curve_power:    float = 1.6

# ── Movement: speed & physics ─────────────────────────────────────────────────
@export_range(10.0, 800.0, 1.0)    var min_speed:    float = 80.0
@export_range(20.0, 2000.0, 1.0)   var max_speed:    float = 420.0
@export_range(10.0, 6000.0, 10.0)  var acceleration: float = 2200.0
@export_range(10.0, 6000.0, 10.0)  var deceleration: float = 2600.0

# ── Camera ─────────────────────────────────────────────────────────────────────
@export_range(0.2, 4.0, 0.01) var camera_zoom_min:  float = 0.65
@export_range(0.2, 4.0, 0.01) var camera_zoom_max:  float = 1.8
@export_range(0.01, 0.5, 0.01) var camera_zoom_step: float = 0.12

# ── Visual smoothing (anti-jitter) ────────────────────────────────────────────
## Interpolates visuals between physics ticks. Eliminates stutter on high-Hz monitors.
@export var physics_interpolation: bool = true

# ── Player stats ───────────────────────────────────────────────────────────────
@export_range(1.0, 1000.0, 1.0) var max_energy:              float = 100.0
@export_range(0.0, 100.0, 0.1)  var energy_drain_per_second: float = 2.5
@export var start_immortal: bool = false

# ── Runtime state ──────────────────────────────────────────────────────────────
var energy:  float = 0.0
var iron:    int   = 0
var gold:    int   = 0
var crystal: int   = 0
var uranium: int   = 0
var titanium: int  = 0

var _is_dead:              bool  = false
var _movement_bounds:      Rect2 = Rect2(0.0, 0.0, 0.0, 0.0)
var _has_movement_bounds:  bool  = false
var _energy_overload_armed: bool = false
var _is_immortal:          bool  = false
var _storm_glow_boost:     float = 0.0
var _storm_energy_modifier: float = 1.0
var _storm_active:         bool  = false
var _storm_visual_time:    float = 0.0

# Physics interpolation buffers (updated every _physics_process tick)
var _prev_pos: Vector2 = Vector2.ZERO
var _curr_pos: Vector2 = Vector2.ZERO

# Wrap olmayan birikimli pozisyon — background sistemleri bunu kullanır.
# global_position wrap anında zıplar; accumulated_position sürekli artar.
var accumulated_position: Vector2 = Vector2.ZERO

# Wrap sonrası kamera geçiş düzeltmesi
var _wrap_cam_correction: Vector2 = Vector2.ZERO
var _wrap_tween: Tween = null

# ── Node references ────────────────────────────────────────────────────────────
@onready var collision_shape:   CollisionShape2D = $CollisionShape2D
@onready var visual_root:       Node2D           = $VisualRoot
@onready var contact_detector:  Area2D           = $ContactDetector
@onready var damage_aura:       Area2D           = $DamageAura
@onready var damage_tick:       Timer            = $DamageTick
@onready var energy_field_ring: Node2D           = $EnergyFieldRing
@onready var aura_ring:         Node2D           = $AuraRing
@onready var attraction_field:  Area2D           = $AttractionField
@onready var outer_glow:        Node2D           = $VisualRoot/OuterGlow
@onready var mid_glow:          Node2D           = $VisualRoot/MidGlow
@onready var core_glow:         Node2D           = $VisualRoot/Core
@onready var player_camera:     Camera2D         = $Camera2D

const GRAB_RANGE:       float = 150.0
const GRAB_HOLD_RADIUS: float = 80.0

const DEATH_SHATTER_SCENE: PackedScene  = preload("res://scenes/effects/player_death_shatter.tscn")
const OVERLOAD_BURST_SCENE: PackedScene = preload("res://scenes/effects/player_overload_burst.tscn")
const _WAVE_EMITTER_SCRIPT              = preload("res://scripts/player/wave_damage_emitter.gd")
const _GRAVITY_VISUAL_SCRIPT            = preload("res://scripts/player/player_gravity_visual.gd")
const _WEAPON_RING_SCRIPT               = preload("res://scripts/player/weapon_ring.gd")
const _ATTACK_CONTROLLER_SCRIPT         = preload("res://scripts/player/attack_controller.gd")
const _CELL_BARRIER_SCRIPT              = preload("res://scripts/player/cell_barrier.gd")

var _base_damage_aura_radius: float = 100.0
var _energy_field_radius:     float = 8.0
var _wave_emitter:       Node2D = null
var _gravity_visual:     Node2D = null
var _weapon_ring:        Node2D = null
var _attack_controller:  Node2D = null
var _cell_barrier:       Node2D = null
var _grabbed_asteroid:   Node2D = null


func _ready() -> void:
	add_to_group(&"player")
	_is_immortal = start_immortal
	energy = max_energy * 0.5
	_energy_overload_armed = false
	_prev_pos = global_position
	_curr_pos = global_position
	accumulated_position = global_position

	# ── JITTER FIX 1: disable camera position smoothing ──────────────────────
	# Camera2D is a child of CharacterBody2D. Smoothing on a child of the moving
	# body makes the viewport lag behind the physics position → visual jitter.
	# We handle smooth following ourselves via physics_interpolation below.
	if player_camera != null:
		player_camera.position_smoothing_enabled = false
		player_camera.drag_horizontal_enabled    = false
		player_camera.drag_vertical_enabled      = false

	_setup_wave_emitter()
	_setup_gravity_visual()
	_setup_cell_barrier()
	_setup_attack_controller()
	_update_mining_tick_interval()
	_update_damage_aura_size()
	_update_attraction_field_state()
	_update_energy_field_visual()
	_update_energy_visual()


# ── Physics process: movement + game logic ─────────────────────────────────────

func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	_storm_visual_time += delta
	# Shift interpolation buffer at the start of each physics tick.
	_prev_pos = _curr_pos

	_update_mining_tick_interval()
	_update_damage_aura_size()
	_update_attraction_field_state()
	_drain_energy(delta)
	if _is_dead:
		return

	var _pre_move_pos := global_position
	_handle_movement(delta)
	# accumulated_position: wrap delta hariç gerçek hareketi biriktirir.
	# _handle_movement içinde _wrap_to_bounds çağrılır; wrap sonrası global_position
	# zıplar ama accumulated_position sürekliliğini korur.
	# Wrap delta = (global_position - _pre_move_pos) içindeki "büyük sıçrama" kısmı.
	var move_delta := global_position - _pre_move_pos
	# Wrap olmuşsa move_delta dünya genişliği/yüksekliğinin yarısından büyük olur.
	if _has_movement_bounds:
		if absf(move_delta.x) > _movement_bounds.size.x * 0.5:
			move_delta.x -= signf(move_delta.x) * _movement_bounds.size.x
		if absf(move_delta.y) > _movement_bounds.size.y * 0.5:
			move_delta.y -= signf(move_delta.y) * _movement_bounds.size.y
	accumulated_position += move_delta
	_update_grab(delta)
	_curr_pos = global_position


func _handle_movement(delta: float) -> void:
	# ── MOUSE FIX: screen-space steering (zoom-independent) ──────────────────
	# Measure mouse offset from viewport CENTER in screen pixels.
	# This means the same physical mouse movement always produces the same speed
	# regardless of camera zoom level.
	var vp_half:    Vector2 = get_viewport().get_visible_rect().size * 0.5
	var mouse_vp:   Vector2 = get_viewport().get_mouse_position()
	var scr_offset: Vector2 = mouse_vp - vp_half
	var scr_dist:   float   = scr_offset.length() * mouse_sensitivity

	var target_velocity := Vector2.ZERO

	if scr_dist > mouse_deadzone_px:
		# Smooth ramp: 0 at deadzone edge → 1 at full-speed distance.
		var range_len: float = maxf(1.0, mouse_full_speed_px - mouse_deadzone_px)
		var t:         float = clampf((scr_dist - mouse_deadzone_px) / range_len, 0.0, 1.0)
		# Deadzone soft-entry: ease the first 10% of the ramp to avoid abrupt start.
		var soft_t: float    = t * t * (3.0 - 2.0 * t)            # smoothstep within deadzone edge
		var curved: float    = pow(soft_t, mouse_curve_power)      # power curve for overall shape
		var spd:    float    = lerpf(min_speed, max_speed, curved)
		# Direction from screen offset → this matches world direction for top-down games.
		target_velocity = scr_offset.normalized() * spd

	var step: float = acceleration * delta if target_velocity.length_squared() > 0.01 else deceleration * delta
	velocity = velocity.move_toward(target_velocity, step)
	move_and_slide()
	_wrap_to_bounds()


# ── Process: visuals + physics interpolation ──────────────────────────────────

func _process(_delta: float) -> void:
	if _is_dead:
		return
	_update_energy_field_visual()
	_update_energy_visual()

	if physics_interpolation:
		_apply_physics_interpolation()


func _apply_physics_interpolation() -> void:
	## JITTER FIX 2: interpolate visuals between physics ticks.
	## The physics body snaps every 1/60s. At 120/144Hz, render frames see the
	## same physics position repeatedly → stutter.  We compute a smooth position
	## between _prev_pos and _curr_pos and offset the visual nodes by the delta.
	## The physics body (collision) stays at the real tick position.
	var alpha:      float   = Engine.get_physics_interpolation_fraction()
	var smooth_pos: Vector2 = _prev_pos.lerp(_curr_pos, alpha)
	var offset:     Vector2 = smooth_pos - global_position

	# Offset visuals (local offset from CharacterBody2D position)
	if visual_root != null:
		visual_root.position = offset
	if energy_field_ring != null:
		energy_field_ring.position = offset
	if aura_ring != null:
		aura_ring.position = offset

	# Shift camera viewport to center on smooth position (not physics tick position).
	# _wrap_cam_correction: wrap anında kamera anlık atlamasın diye uygulanan
	# geçici offset. Tween ile sıfıra iner → smooth geçiş.
	if player_camera != null:
		player_camera.offset = offset + _wrap_cam_correction


func _reset_smooth_offsets() -> void:
	if visual_root       != null: visual_root.position       = Vector2.ZERO
	if energy_field_ring != null: energy_field_ring.position = Vector2.ZERO
	if aura_ring         != null: aura_ring.position         = Vector2.ZERO
	if player_camera     != null: player_camera.offset       = Vector2.ZERO


# ── Energy ─────────────────────────────────────────────────────────────────────

func _drain_energy(delta: float) -> void:
	if energy_drain_per_second <= 0.0:
		return
	energy = maxf(0.0, energy - (energy_drain_per_second * maxf(0.0, _storm_energy_modifier) * delta))
	if energy < maxf(0.0, max_energy) - 0.01:
		_energy_overload_armed = true
	if energy <= 0.0 and not _is_immortal and not _is_developer_mode_enabled():
		die()


# ── Bounds ─────────────────────────────────────────────────────────────────────

func set_movement_bounds(bounds: Rect2) -> void:
	_movement_bounds     = bounds
	_has_movement_bounds = true
	# Wrap uygulama: ilk atama sırasında oyuncu zaten bounds içindeyse no-op.


func _wrap_to_bounds() -> void:
	if not _has_movement_bounds:
		return
	if not WorldWrap.needs_wrap(global_position, _movement_bounds):
		return

	var old_pos := global_position
	global_position = WorldWrap.apply(global_position, _movement_bounds)
	var delta := global_position - old_pos

	# Physics interpolation buffer — wrap delta'sı ile kaydır (snap değil).
	# Böylece 1 frame içinde kamera konumu sürekliliğini korur.
	_prev_pos += delta
	_curr_pos += delta

	# accumulated_position asla wrap etmez: background sistemleri bunu kullanır.
	# delta uygulanmaz — önceki konumun sürekli birikimi devam eder.
	# (Zaten wrap olmadan önceki değeri korunur; hiçbir şey yapmaya gerek yok.)

	# Kamera görüntüsünü smooth geçiş için geriye offset'le, sonra tween ile sıfırla.
	# Dünya genişliğinin yarısından büyük bir düzeltme görsel pan'a yol açar;
	# bu durumda snap daha iyidir — geçiş süresini clamp'le.
	var world_w := _movement_bounds.size.x
	var world_h := _movement_bounds.size.y
	var abs_dx := absf(delta.x)
	var abs_dy := absf(delta.y)
	# Maksimum kamera offset'ini viewport boyutunun 1.5×'i ile sınırla
	var vp_size := get_viewport_rect().size if get_viewport_rect().size.x > 0.0 else Vector2(1920.0, 1080.0)
	var max_smooth_x := vp_size.x * 1.5
	var max_smooth_y := vp_size.y * 1.5
	if abs_dx <= max_smooth_x and abs_dy <= max_smooth_y:
		# Kısa wrap — smooth kamera geçişi yapılabilir
		_wrap_cam_correction -= delta
		if _wrap_tween != null:
			_wrap_tween.kill()
		var dur := clampf(maxf(abs_dx, abs_dy) / 3200.0, 0.06, 0.22)
		_wrap_tween = create_tween()
		_wrap_tween.tween_property(self, "_wrap_cam_correction", Vector2.ZERO, dur)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		# Büyük wrap (dünya genişliğinden büyük) — snap daha temiz
		_wrap_cam_correction = Vector2.ZERO
		if _wrap_tween != null:
			_wrap_tween.kill()
			_wrap_tween = null
		snap_interpolation_to_current_position()


func _get_collision_radius() -> float:
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		var circle := collision_shape.shape as CircleShape2D
		var scale_len := maxf(absf(collision_shape.global_scale.x), absf(collision_shape.global_scale.y))
		return circle.radius * scale_len
	return 12.0


# ── Collision / damage ─────────────────────────────────────────────────────────

func _on_contact_detector_body_entered(body: Node2D) -> void:
	if _is_dead or not _is_harmful_asteroid(body):
		return
	_take_asteroid_damage()


func _on_contact_detector_area_entered(area: Area2D) -> void:
	if _is_dead or not _is_harmful_asteroid(area):
		return
	_take_asteroid_damage()


func _take_asteroid_damage() -> void:
	if _is_immortal or _is_developer_mode_enabled():
		return
	max_energy = 0.0
	energy     = 0.0
	die()


func _is_harmful_asteroid(node: Node) -> bool:
	if node == null or node == self or node == contact_detector:
		return false
	if not node.is_in_group("asteroid"):
		return false
	if node.is_in_group("asteroid_uranium"):
		return false
	if node == _grabbed_asteroid:
		return false
	if node.has_method("is_player_friendly") and bool(node.call("is_player_friendly")):
		return false
	return true


# ── Death ──────────────────────────────────────────────────────────────────────

func die() -> void:
	if _is_dead:
		return
	_is_dead = true
	energy   = 0.0
	velocity = Vector2.ZERO
	_reset_smooth_offsets()

	if collision_shape  != null: collision_shape.set_deferred("disabled", true)
	if contact_detector != null: contact_detector.set_deferred("monitoring", false)
	if damage_aura      != null: damage_aura.set_deferred("monitoring", false)
	if visual_root      != null: visual_root.visible = false
	if _attack_controller != null:
		_attack_controller.set_physics_process(false)
		_attack_controller.set_process(false)

	_spawn_death_shatter()
	died.emit()
	queue_free()


func _explode_from_overload() -> void:
	if _is_dead:
		return
	var rs := get_node_or_null("/root/RunState")
	if rs != null and bool(rs.get("developer_mode_enabled")):
		_energy_overload_armed = false
		energy = maxf(0.0, max_energy) * 0.80
		return
	_spawn_overload_burst()
	die()


func _spawn_death_shatter() -> void:
	if DEATH_SHATTER_SCENE == null:
		return
	var shatter := DEATH_SHATTER_SCENE.instantiate() as Node2D
	if shatter == null:
		return
	shatter.global_position = global_position
	var parent := get_parent()
	(parent if parent != null else get_tree().current_scene).add_child(shatter)
	if shatter.has_method("setup"):
		shatter.call("setup", _get_collision_radius())


func _spawn_overload_burst() -> void:
	if OVERLOAD_BURST_SCENE == null:
		return
	var burst := OVERLOAD_BURST_SCENE.instantiate() as Node2D
	if burst == null:
		return
	burst.global_position = global_position
	var parent := get_parent()
	(parent if parent != null else get_tree().current_scene).add_child(burst)
	if burst.has_method("setup"):
		burst.call("setup", _get_collision_radius() * 1.2)


# ── Resources / energy ─────────────────────────────────────────────────────────

func add_energy(amount: float) -> void:
	if amount <= 0.0 or _is_dead:
		return
	var clamped_max := maxf(0.0, max_energy)
	energy = clampf(energy + amount, 0.0, clamped_max)
	if energy < clamped_max - 0.01:
		_energy_overload_armed = true
	elif _energy_overload_armed and energy >= clamped_max and clamped_max > 0.0:
		_energy_overload_armed = false
		energy_full.emit()


func add_energy_percent(percent: float) -> void:
	if percent <= 0.0 or _is_dead:
		return
	add_energy(maxf(0.0, max_energy) * (percent / 100.0))


func add_iron(amount: int) -> void:
	if amount <= 0 or _is_dead:
		return
	iron += amount
	var rs := get_node_or_null("/root/RunState")
	if rs != null: rs.iron = iron
	add_energy_percent(1.0)


func add_gold(amount: int) -> void:
	if amount <= 0 or _is_dead:
		return
	gold += amount
	var rs := get_node_or_null("/root/RunState")
	if rs != null: rs.gold = gold
	add_energy_percent(15.0)


func add_crystal(amount: int) -> void:
	if amount <= 0 or _is_dead:
		return
	crystal += amount
	var rs := get_node_or_null("/root/RunState")
	if rs != null: rs.crystal = crystal


func add_uranium(amount: int) -> void:
	if amount <= 0 or _is_dead:
		return
	uranium += amount
	var rs := get_node_or_null("/root/RunState")
	if rs != null: rs.uranium = uranium


func add_titanium(amount: int) -> void:
	if amount <= 0 or _is_dead:
		return
	titanium += amount
	var rs := get_node_or_null("/root/RunState")
	if rs != null:
		rs.titanium = titanium


# ── Storm feedback ─────────────────────────────────────────────────────────────

func set_storm_feedback(active: bool, next_glow_boost: float, next_energy_modifier: float) -> void:
	_storm_active          = active
	_storm_glow_boost      = maxf(0.0, next_glow_boost)
	_storm_energy_modifier = maxf(0.0, next_energy_modifier)


# ── Getters (called by HUD / upgrade screen) ───────────────────────────────────

func get_damage_aura_radius() -> float:
	var rs := get_node_or_null("/root/RunState")
	return UpgradeEffects.get_current_damage_aura_radius(rs, _base_damage_aura_radius)


func is_point_inside_damage_aura(point: Vector2) -> bool:
	var r := get_damage_aura_radius()
	return r > 0.0 and global_position.distance_to(point) <= r


func get_collect_radius() -> float:
	return _get_collision_radius()


func get_energy_field_radius() -> float:
	var rs := get_node_or_null("/root/RunState")
	if not UpgradeEffects.is_attraction_skill_unlocked(rs):
		return 0.0
	return UpgradeEffects.get_current_energy_field_radius(rs, _energy_field_radius)


func get_energy_orb_attract_radius_multiplier() -> float:
	var rs := get_node_or_null("/root/RunState")
	return UpgradeEffects.get_energy_orb_attract_radius_multiplier(rs)


func get_current_speed() -> float:
	return velocity.length()


func snap_interpolation_to_current_position() -> void:
	_prev_pos = global_position
	_curr_pos = global_position


func can_collect_drops_in_attraction_field() -> bool:
	var rs := get_node_or_null("/root/RunState")
	return UpgradeEffects.is_drop_collection_skill_unlocked(rs)


# ── Camera zoom ────────────────────────────────────────────────────────────────

func apply_camera_zoom_step(direction: int) -> void:
	if direction == 0:
		return
	_apply_camera_zoom(camera_zoom_step * float(direction))


func _apply_camera_zoom(delta_zoom: float) -> void:
	if player_camera == null:
		return
	var next_zoom := clampf(player_camera.zoom.x + delta_zoom, camera_zoom_min, camera_zoom_max)
	player_camera.zoom = Vector2(next_zoom, next_zoom)


# ── Damage tick ────────────────────────────────────────────────────────────────

func _on_damage_tick_timeout() -> void:
	if _is_dead or _wave_emitter == null:
		return
	var mining_damage   := 1.0
	var crit_chance     := 0.0
	var crit_multiplier := 1.0
	var rs := get_node_or_null("/root/RunState")
	if rs != null:
		mining_damage   = UpgradeEffects.get_current_mining_damage(rs)
		crit_chance     = UpgradeEffects.get_current_crit_chance(rs)
		crit_multiplier = UpgradeEffects.get_crit_damage_multiplier()

	var is_crit := crit_chance > 0.0 and randf() < crit_chance
	var damage  := mining_damage * (crit_multiplier if is_crit else 1.0)

	# Test haritasında +1000 bonus hasar — devasa asteroidleri deneyebilmek için.
	var cur_scene := get_tree().current_scene
	if cur_scene != null and String(cur_scene.scene_file_path) == "res://scenes/world/world_test.tscn":
		damage += 1000.0

	_wave_emitter.call("emit_wave", damage, is_crit)


# ── Private: wave emitter setup ────────────────────────────────────────────────

func _setup_wave_emitter() -> void:
	_wave_emitter      = _WAVE_EMITTER_SCRIPT.new()
	_wave_emitter.name = "WaveEmitter"
	add_child(_wave_emitter)


func _setup_gravity_visual() -> void:
	# Eski neon orb katmanlarını gizle
	if outer_glow != null: outer_glow.visible = false
	if mid_glow   != null: mid_glow.visible   = false
	if core_glow  != null: core_glow.visible   = false
	if visual_root == null:
		return
	_gravity_visual      = _GRAVITY_VISUAL_SCRIPT.new()
	_gravity_visual.name = "GravityVisual"
	visual_root.add_child(_gravity_visual)


func _setup_cell_barrier() -> void:
	if visual_root == null:
		return
	_cell_barrier      = _CELL_BARRIER_SCRIPT.new()
	_cell_barrier.name = "CellBarrier"
	visual_root.add_child(_cell_barrier)


func _setup_attack_controller() -> void:
	_attack_controller      = _ATTACK_CONTROLLER_SCRIPT.new()
	_attack_controller.name = "AttackController"
	add_child(_attack_controller)


func _setup_weapon_ring() -> void:
	if visual_root == null:
		return
	_weapon_ring      = _WEAPON_RING_SCRIPT.new()
	_weapon_ring.name = "WeaponRing"
	visual_root.add_child(_weapon_ring)
	# Attack controller'a ring referansını ver
	if _attack_controller != null:
		_attack_controller.set("_weapon_ring", _weapon_ring)


# ── Yakalama ──────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if _is_dead:
		return
	if event is InputEventKey \
			and (event as InputEventKey).keycode == KEY_E \
			and event.pressed and not event.echo:
		if _grabbed_asteroid != null:
			_release_grab()
		else:
			_try_grab_nearest()


func _try_grab_nearest() -> void:
	var best: Node2D     = null
	var best_dist: float = GRAB_RANGE
	for node in get_tree().get_nodes_in_group("asteroid"):
		if not is_instance_valid(node):
			continue
		if not node.has_method("set_grabbed"):
			continue
		var d: float = global_position.distance_to(node.global_position)
		if d < best_dist:
			best_dist = d
			best      = node
	if best == null:
		return
	_grabbed_asteroid = best
	best.call("set_grabbed", true)
	if _cell_barrier != null and _cell_barrier.has_method("set_grab_target"):
		_cell_barrier.call("set_grab_target", best)


func _release_grab() -> void:
	if _grabbed_asteroid != null and is_instance_valid(_grabbed_asteroid):
		_grabbed_asteroid.call("set_grabbed", false)
	_grabbed_asteroid = null
	if _cell_barrier != null and _cell_barrier.has_method("set_grab_target"):
		_cell_barrier.call("set_grab_target", null)


func _update_grab(delta: float) -> void:
	if _grabbed_asteroid == null:
		return
	if not is_instance_valid(_grabbed_asteroid):
		_grabbed_asteroid = null
		if _cell_barrier != null and _cell_barrier.has_method("set_grab_target"):
			_cell_barrier.call("set_grab_target", null)
		return
	_grabbed_asteroid.call("apply_grab_pull", global_position, GRAB_HOLD_RADIUS, delta)


# ── Private: visual updates ────────────────────────────────────────────────────

func _is_developer_mode_enabled() -> bool:
	var rs := get_node_or_null("/root/RunState")
	return UpgradeEffects.is_developer_mode_enabled(rs)


func _update_mining_tick_interval() -> void:
	if damage_tick == null:
		return
	var rs            := get_node_or_null("/root/RunState")
	var next_interval := UpgradeEffects.get_current_mining_interval(rs)
	if not is_equal_approx(damage_tick.wait_time, next_interval):
		damage_tick.wait_time = next_interval


func _update_attraction_field_state() -> void:
	if attraction_field == null:
		return
	var rs      := get_node_or_null("/root/RunState")
	var enabled := UpgradeEffects.is_attraction_skill_unlocked(rs)
	attraction_field.visible         = enabled
	attraction_field.monitoring      = enabled
	attraction_field.monitorable     = enabled
	attraction_field.set_process(enabled)
	attraction_field.set_physics_process(enabled)


func _update_energy_field_visual() -> void:
	if energy_field_ring == null:
		return
	var radius := get_energy_field_radius()
	energy_field_ring.visible = radius > 0.0
	if radius <= 0.0:
		return
	energy_field_ring.set("radius", radius)
	energy_field_ring.queue_redraw()


func _cache_base_damage_aura_radius() -> void:
	if damage_aura == null:
		return
	var shape_node := damage_aura.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or not (shape_node.shape is CircleShape2D):
		return
	_base_damage_aura_radius = maxf(1.0, (shape_node.shape as CircleShape2D).radius)


func _update_damage_aura_size() -> void:
	if damage_aura == null:
		return
	var next_radius := get_damage_aura_radius()
	var shape_node := damage_aura.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null and shape_node.shape is CircleShape2D:
		var circle := shape_node.shape as CircleShape2D
		if not is_equal_approx(circle.radius, next_radius):
			# Duplicate the shape if it's still the shared PackedScene resource
			if not circle.is_local_to_scene():
				shape_node.shape = circle.duplicate()
			(shape_node.shape as CircleShape2D).radius = next_radius
	var aura_ring := get_node_or_null("AuraRing")
	if aura_ring != null:
		aura_ring.set("radius", next_radius)
		aura_ring.queue_redraw()


func _update_energy_visual() -> void:
	if visual_root == null:
		return
	var max_safe: float = maxf(1.0, max_energy)
	var ratio: float = clampf(energy / max_safe, 0.0, 1.0)
	var fade: float = lerpf(0.18, 1.05, sqrt(ratio))
	var near_full: float = clampf((ratio - 0.70) / 0.30, 0.0, 1.0)
	near_full = near_full * near_full * (3.0 - (2.0 * near_full))
	var white_hot_boost: float = near_full * 1.55
	var storm_pulse: float = sin(_storm_visual_time * 7.5) * 0.5 + 0.5
	var boosted: float = minf(2.9, fade + white_hot_boost + (_storm_glow_boost * lerpf(0.25, 0.7, storm_pulse)))
	var outer_alpha: float = (0.34 * boosted) + (0.22 * near_full)
	var mid_alpha: float = (0.62 * boosted) + (0.34 * near_full)
	var core_alpha: float = (1.08 * boosted) + (0.48 * near_full)

	var is_middle_pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
	var outer_color: Color
	var mid_color:   Color
	var core_color:  Color
	if is_middle_pressed:
		outer_color = Color(1.0, 0.10, 0.10, 1.0)
		mid_color   = Color(1.0, 0.35, 0.20, 1.0)
		core_color  = Color(1.0, 0.80, 0.60, 1.0)
	elif _storm_active and _storm_glow_boost > 0.0:
		var mix := clampf(_storm_glow_boost / 0.225, 0.0, 1.0)
		outer_color = Color(0.0, lerpf(0.85, 1.0, mix), lerpf(0.55, 0.30, mix), 1.0)
		mid_color   = Color(lerpf(0.6, 0.2, mix), 1.0, lerpf(0.8, 0.5, mix), 1.0)
		core_color  = Color(1.0, 1.0, 1.0, 1.0)
	else:
		outer_color = Color(0.20, 0.75, 1.00, 1.0)  # elektrik mavi
		mid_color   = Color(0.55, 0.92, 1.00, 1.0)  # açık cyan
		core_color  = Color(0.92, 0.99, 1.00, 1.0)  # saf beyaz-mavi

	_set_orb_layer_visual(outer_glow, outer_color, outer_alpha)
	_set_orb_layer_visual(mid_glow,   mid_color,   mid_alpha)
	_set_orb_layer_visual(core_glow,  core_color,  core_alpha)

	if _gravity_visual != null:
		var tint: Color
		if is_middle_pressed:
			tint = Color(1.00, 0.22, 0.18)   # overload — kırmızı
		elif _storm_active and _storm_glow_boost > 0.0:
			tint = Color(0.18, 1.00, 0.58)   # storm — teal
		else:
			tint = Color(0.97, 0.95, 1.00)   # normal — gümüş-beyaz
		_gravity_visual.call("set_visual_state", ratio, boosted, tint)


func _set_orb_layer_visual(layer: Node2D, color: Color, next_alpha: float) -> void:
	if layer == null:
		return
	if layer == outer_glow:
		color = Color(0.9725, 0.9922, 1.0, 1.0)
	elif layer == mid_glow:
		color = Color(0.9412, 0.9725, 1.0, 1.0)
	elif layer == core_glow:
		color = Color(1.0, 1.0, 1.0, 1.0)
	layer.set("layer_color", color)
	layer.set("alpha", next_alpha)
