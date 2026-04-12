extends Area2D
class_name EnergyOrb

## Premium magnetized plasma pickup — four-phase lifecycle:
##   SCATTER → APPROACH (orbital drift + grace) → SNAP → ABSORB

enum Phase { SCATTER, APPROACH, SNAP, ABSORB }

const ABSORB_DURATION:      float = 0.13
const DEFAULT_ATTRACT_RADIUS: float = 140.0
const LIFETIME:             float = 20.0

# ── Inspector ──────────────────────────────────────────────────────────────────
@export var player_group: StringName = &"player"
@export_range(0.0, 100.0, 0.1, "suffix:%") var energy_percent_gain: float = 1.0
@export_range(1, 100, 1) var iron_value: int = 1
@export_range(1, 100, 1) var gold_value: int = 1
@export_range(1, 100, 1) var titanium_value: int = 1

@export_group("Spawn")
@export var scatter_duration:    float = 0.18
@export var scatter_impulse_min: float = 70.0
@export var scatter_impulse_max: float = 160.0
@export var scatter_drag:        float = 6.0   # lerp-toward-zero rate during scatter

@export_group("Attraction")
@export var attract_radius: float = 140.0
@export var base_speed:     float = 27.0
@export var acceleration:   float = 500.0
@export var max_speed:      float = 300.0
@export var grace_duration: float = 0.40   # after scatter: pull active, collect blocked

@export_group("Orbit")
@export var orbit_strength: float = 0.55   # tangential blend at approach edge
@export var orbit_fade_dist: float = 45.0  # orbit blend fades to zero inside snap_radius
@export var snap_radius:    float = 28.0   # inside: straight magnetic snap

@export_group("Pickup")
@export var pickup_radius: float = 4.0

const IRON_PICKUP_RADIUS: float = 2.0
const GOLD_PICKUP_RADIUS: float = 2.5
const URANIUM_PICKUP_RADIUS: float = 2.8
const TITANIUM_PICKUP_RADIUS: float = 2.6
const ENERGY_MIN_PICKUP_RADIUS: float = 3.0

# ── Internal state ─────────────────────────────────────────────────────────────
var _phase:         Phase   = Phase.SCATTER
var _player:        Node2D  = null
var _velocity:      Vector2 = Vector2.ZERO
var _current_speed: float   = 0.0
var _scatter_timer: float   = 0.0
var _grace_timer:   float   = 0.0
var _lookup_cd:     float   = 0.0
var _orbit_sign:    float   = 1.0
var _resource_kind: StringName = &"energy"
var _spawn_scatter_radius: float = 0.0
var _lifetime:      float   = LIFETIME

# ── Visual state ───────────────────────────────────────────────────────────────
var _draw_scale: float = 1.0
var _absorb_t:   float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	monitoring  = true
	monitorable = true
	add_to_group("energy_pickup")
	body_entered.connect(_on_body_entered)

	_current_speed = base_speed
	_orbit_sign    = 1.0 if randf() < 0.5 else -1.0
	_apply_collision_radius()

	var angle   := randf() * TAU
	var impulse := randf_range(scatter_impulse_min, scatter_impulse_max)
	_velocity = Vector2.RIGHT.rotated(angle) * impulse

	_refresh_player(true)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _phase != Phase.ABSORB:
		_lifetime -= delta
		if _lifetime <= 0.0:
			queue_free()
			return
	match _phase:
		Phase.ABSORB:   _tick_absorb(delta)
		Phase.SCATTER:  _tick_scatter(delta)
		Phase.APPROACH: _tick_approach(delta)
		Phase.SNAP:     _tick_snap(delta)


# ── Phase tickers ──────────────────────────────────────────────────────────────

func _tick_absorb(delta: float) -> void:
	_absorb_t  += delta / ABSORB_DURATION
	_draw_scale = lerpf(0.55, 0.0, clampf(_absorb_t, 0.0, 1.0))
	queue_redraw()
	if _absorb_t >= 1.0:
		queue_free()


func _tick_scatter(delta: float) -> void:
	_scatter_timer += delta
	global_position += _velocity * delta
	_velocity = _velocity.lerp(Vector2.ZERO, minf(delta * scatter_drag, 1.0))
	queue_redraw()
	if _scatter_timer >= scatter_duration:
		_current_speed = base_speed
		_grace_timer   = grace_duration
		_phase         = Phase.APPROACH


func _tick_approach(delta: float) -> void:
	if _grace_timer > 0.0:
		_grace_timer -= delta

	_maybe_refresh_player(delta)
	if not is_instance_valid(_player):
		_coast(delta)
		return

	var to_player := _player.global_position - global_position
	var dist      := to_player.length()

	var attract_r := _get_attract_radius()
	if attract_r <= 0.0 or dist > attract_r or dist <= 0.001:
		_coast(delta)
		return

	# Quadratic proximity curve: slow drift at edge, explosive near center
	var prox      := 1.0 - clampf(dist / attract_r, 0.0, 1.0)
	var curve     := prox * prox
	var eff_accel := lerpf(acceleration * 0.18, acceleration * 4.0, curve)
	_current_speed = minf(_current_speed + eff_accel * delta, max_speed * 2.2)

	# Direct approach — no orbital tangent, straight toward player
	var target_dir := to_player.normalized()
	_velocity   = _velocity.lerp(target_dir * _current_speed, minf(delta * 14.0, 1.0))
	_draw_scale = lerpf(1.0, 0.55, prox)
	global_position += _velocity * delta
	queue_redraw()

	if dist <= _get_collect_dist():
		_begin_collect()
		return
	if dist <= snap_radius:
		_phase = Phase.SNAP


func _tick_snap(delta: float) -> void:
	if not is_instance_valid(_player):
		_phase = Phase.APPROACH
		return

	var to_player := _player.global_position - global_position
	var dist      := to_player.length()

	# Hard magnetic pull, no orbital component
	_current_speed = minf(_current_speed + acceleration * 6.0 * delta, max_speed * 2.2)
	_velocity   = _velocity.lerp(to_player.normalized() * _current_speed, minf(delta * 18.0, 1.0))
	_draw_scale = lerpf(0.55, 0.2, clampf(1.0 - dist / snap_radius, 0.0, 1.0))
	global_position += _velocity * delta
	queue_redraw()

	if dist <= _get_collect_dist():
		_begin_collect()
		return
	if dist > snap_radius * 1.5:
		_phase = Phase.APPROACH


# ── Collection ─────────────────────────────────────────────────────────────────

func _begin_collect() -> void:
	if _phase == Phase.ABSORB:
		return
	_phase      = Phase.ABSORB
	set_deferred("monitoring",  false)
	set_deferred("monitorable", false)
	_give_resource(_player)
	_absorb_t   = 0.0
	_draw_scale = 0.55
	queue_redraw()


func _give_resource(p: Node2D) -> void:
	if _resource_kind == &"iron":
		if p != null and p.has_method("add_iron"):
			p.call("add_iron", iron_value)
		else:
			push_warning("EnergyOrb: add_iron() not found on player.")
	elif _resource_kind == &"gold":
		if p != null and p.has_method("add_gold"):
			p.call("add_gold", gold_value)
		else:
			push_warning("EnergyOrb: add_gold() not found on player.")
	elif _resource_kind == &"crystal":
		if p != null and p.has_method("add_crystal"):
			p.call("add_crystal", gold_value)
		else:
			push_warning("EnergyOrb: add_crystal() not found on player.")
	elif _resource_kind == &"uranium":
		if p != null and p.has_method("add_uranium"):
			p.call("add_uranium", gold_value)
		else:
			push_warning("EnergyOrb: add_uranium() not found on player.")
	elif _resource_kind == &"titanium":
		if p != null and p.has_method("add_titanium"):
			p.call("add_titanium", titanium_value)
		else:
			push_warning("EnergyOrb: add_titanium() not found on player.")
	else:
		if p != null and p.has_method("add_energy_percent"):
			p.call("add_energy_percent", energy_percent_gain)
		else:
			push_warning("EnergyOrb: add_energy_percent() not found on player.")


# ── Signals ────────────────────────────────────────────────────────────────────

func _on_body_entered(body: Node2D) -> void:
	if _phase == Phase.ABSORB or _phase == Phase.SCATTER:
		return
	if _matches_collect_target(body):
		_begin_collect()


func _on_area_entered(area: Area2D) -> void:
	if _phase == Phase.ABSORB or _phase == Phase.SCATTER:
		return
	if _matches_collect_target(area):
		_begin_collect()


func _matches_collect_target(n: Node) -> bool:
	if is_instance_valid(_player):
		var cur: Node = n
		var hops := 0
		while cur != null and hops < 8:
			if cur == _player:
				return true
			cur = cur.get_parent()
			hops += 1
	return _resolve_player(n) != null


func _resolve_player(n: Node) -> Node2D:
	var cur: Node = n
	var hops := 0
	while cur != null and hops < 8:
		if cur.is_in_group(player_group):
			return cur as Node2D
		cur = cur.get_parent()
		hops += 1
	return null


# ── Public API ─────────────────────────────────────────────────────────────────

func setup(player_node: Node2D, source_radius: float = 0.0, resource_kind: StringName = &"energy") -> void:
	_player        = player_node
	_resource_kind = resource_kind
	_apply_resource_visual_size()
	if source_radius > 0.0:
		_spawn_scatter_radius = source_radius * 2.0
		attract_radius = maxf(attract_radius, source_radius * 4.0)
	_apply_collision_radius()
	_apply_spawn_scatter()


func set_collect_target(target_node: Node2D) -> void:
	if target_node == null or not is_instance_valid(target_node):
		return
	_player = target_node


func force_collect() -> void:
	_begin_collect()


# ── Drawing ────────────────────────────────────────────────────────────────────

func _draw() -> void:
	if _phase == Phase.ABSORB:
		var t       := clampf(_absorb_t, 0.0, 1.0)
		var burst_r := pickup_radius * lerpf(1.8, 5.5, t)
		var burst_a := lerpf(0.90, 0.0, t)
		var col     := _element_color()
		draw_circle(Vector2.ZERO, burst_r, Color(col.r, col.g, col.b, burst_a * 0.55))
		draw_arc(Vector2.ZERO, burst_r * 0.7, 0.0, TAU, 32,
			Color(col.r, col.g, col.b, burst_a), 1.2, true)
		return

	var s := _draw_scale
	if s <= 0.01:
		return

	var proximity_glow := _get_player_proximity_glow()
	var white_mix := proximity_glow * proximity_glow
	if _resource_kind == &"iron":
		_draw_energy_orb(s, proximity_glow, true)
		return
	if _resource_kind == &"gold":
		_draw_gold_pentagon(s, proximity_glow)
		return
	if _resource_kind == &"titanium":
		_draw_titanium_hex(s, proximity_glow)
		return
	_draw_energy_orb(s, proximity_glow)


func _element_color() -> Color:
	if _resource_kind == &"iron": return Color(0.98, 0.99, 1.0)
	if _resource_kind == &"gold": return Color(1.00, 0.96, 0.62)
	if _resource_kind == &"uranium": return Color(0.35, 1.0, 0.28)
	if _resource_kind == &"titanium": return Color(0.72, 0.90, 1.0)
	return Color(0.98, 0.99, 1.0)


func _get_player_proximity_glow() -> float:
	if not is_instance_valid(_player):
		return 0.0
	var attract_r := _get_attract_radius()
	if attract_r <= 0.001:
		return 0.0
	var dist := global_position.distance_to(_player.global_position)
	var proximity := 1.0 - clampf(dist / attract_r, 0.0, 1.0)
	if _phase == Phase.SNAP:
		proximity = maxf(proximity, 0.85)
	return proximity


# ── Helpers ────────────────────────────────────────────────────────────────────

func _coast(delta: float) -> void:
	_velocity   = _velocity.lerp(Vector2.ZERO, 0.05)
	_draw_scale = 1.0
	global_position += _velocity * delta
	queue_redraw()


func _get_attract_radius() -> float:
	if is_instance_valid(_player) and _player.has_method("get_energy_orb_attract_radius_multiplier"):
		return attract_radius * maxf(1.0, float(_player.call("get_energy_orb_attract_radius_multiplier")))
	return attract_radius


func _get_collect_dist() -> float:
	var pr := 12.0
	if is_instance_valid(_player) and _player.has_method("get_collect_radius"):
		pr = float(_player.call("get_collect_radius"))
	return maxf(pickup_radius, pickup_radius + pr + 6.0)


func _maybe_refresh_player(delta: float) -> void:
	if is_instance_valid(_player):
		return
	_lookup_cd -= delta
	if _lookup_cd <= 0.0:
		_refresh_player(false)
		_lookup_cd = 0.25


func _refresh_player(force: bool) -> void:
	var node  := get_tree().get_first_node_in_group(player_group)
	var as_2d := node as Node2D
	if as_2d != null:
		_player = as_2d
	elif force:
		_player = null


func _match_size_to_player() -> void:
	if not is_instance_valid(_player):
		return
	var pr := 24.0
	if _player.has_method("get_collect_radius"):
		pr = float(_player.call("get_collect_radius"))
	pickup_radius = maxf(ENERGY_MIN_PICKUP_RADIUS, pr / 6.0)


func _apply_resource_visual_size() -> void:
	if _resource_kind == &"iron":
		pickup_radius = IRON_PICKUP_RADIUS
		return
	if _resource_kind == &"gold":
		pickup_radius = GOLD_PICKUP_RADIUS
		return
	if _resource_kind == &"uranium":
		pickup_radius = URANIUM_PICKUP_RADIUS
		return
	if _resource_kind == &"titanium":
		pickup_radius = TITANIUM_PICKUP_RADIUS
		return
	_match_size_to_player()


func _apply_collision_radius() -> void:
	if collision_shape == null:
		return
	if collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = pickup_radius


func _apply_spawn_scatter() -> void:
	if _spawn_scatter_radius <= 0.0:
		return
	var angle    := randf() * TAU
	var distance := randf_range(0.0, _spawn_scatter_radius)
	global_position += Vector2.RIGHT.rotated(angle) * distance


func _draw_iron_square(scale_factor: float, proximity_glow: float) -> void:
	var half_side := pickup_radius * scale_factor
	var side := half_side * 2.0
	var glow_alpha := lerpf(0.06, 0.22, proximity_glow)
	var glow_rect := Rect2(Vector2(-half_side, -half_side), Vector2(side, side)).grow(1.4 + proximity_glow * 1.8)
	draw_rect(glow_rect, Color(0.12, 0.12, 0.12, glow_alpha), true)
	draw_rect(Rect2(Vector2(-half_side, -half_side), Vector2(side, side)), Color(0.02, 0.02, 0.02, 1.0), true)


func _draw_energy_orb(scale_factor: float, proximity_glow: float, compact: bool = false) -> void:
	var white_mix := proximity_glow * proximity_glow
	var outer_mul := 1.15 if compact else 1.4
	var inner_mul := 0.62 if compact else 0.7
	var r_outer := pickup_radius * outer_mul * scale_factor
	var r_inner := pickup_radius * inner_mul * scale_factor
	var bloom_radius := r_outer * lerpf(1.05, 2.8, proximity_glow)
	var bloom_alpha := lerpf(0.06, 0.72, white_mix)
	var hot_core_alpha := lerpf(0.0, 0.95, white_mix)
	draw_circle(Vector2.ZERO, bloom_radius, Color(1.0, 1.0, 1.0, bloom_alpha))
	draw_circle(Vector2.ZERO, r_outer, Color(lerpf(0.82, 0.96, white_mix), lerpf(0.84, 0.98, white_mix), 1.0, lerpf(0.18, 0.52, proximity_glow)))
	draw_circle(Vector2.ZERO, r_inner, Color(lerpf(0.94, 1.0, white_mix), lerpf(0.96, 1.0, white_mix), 1.0, lerpf(0.95, 1.0, proximity_glow)))
	if hot_core_alpha > 0.01:
		draw_circle(Vector2.ZERO, r_inner * 0.68, Color(1.0, 1.0, 1.0, hot_core_alpha))


func _draw_gold_pentagon(scale_factor: float, proximity_glow: float) -> void:
	var radius := pickup_radius * scale_factor
	var points := PackedVector2Array()
	for i in range(5):
		var angle := (-PI * 0.5) + (TAU * float(i) / 5.0)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	var glow_points := PackedVector2Array()
	for point in points:
		glow_points.append(point * (1.35 + proximity_glow * 0.35))
	draw_colored_polygon(glow_points, Color(1.0, 0.9, 0.2, lerpf(0.08, 0.24, proximity_glow)))
	draw_colored_polygon(points, Color(1.0, 0.84, 0.12, 1.0))


func _draw_titanium_hex(scale_factor: float, proximity_glow: float) -> void:
	var radius := pickup_radius * scale_factor
	var points := PackedVector2Array()
	for i in range(6):
		var angle := (-PI * 0.5) + (TAU * float(i) / 6.0)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	var glow_points := PackedVector2Array()
	for point in points:
		glow_points.append(point * (1.28 + proximity_glow * 0.34))
	draw_colored_polygon(glow_points, Color(0.56, 0.84, 1.0, lerpf(0.08, 0.24, proximity_glow)))
	draw_colored_polygon(points, Color(0.68, 0.86, 0.98, 1.0))
	var inner_points := PackedVector2Array()
	for point in points:
		inner_points.append(point * 0.56)
	draw_colored_polygon(inner_points, Color(0.92, 0.98, 1.0, lerpf(0.72, 0.96, proximity_glow)))
