extends Area2D
class_name MiningField

# Inspector tuning
@export var player_group: StringName = &"player"
@export var target_group: StringName = &"minable"
@export var radius: float = 160.0
@export var pickup_radius: float = 28.0
@export var attract_acceleration: float = 133.4
@export var base_speed: float = 160.0
@export var max_speed: float = 2000.0
@export var settle_time: float = 0.08
@export var scan_interval: float = 0.20
@export_range(0.0, 100.0, 0.1, "suffix:%") var energy_percent_gain: float = 2.0
@export var destroy_target_on_collect: bool = true
@export var collect_vfx_scene: PackedScene
@export var collision_shape_path: NodePath = ^"CollisionShape2D"
@export var ring_path: NodePath = ^"Ring"
@export var ring_segments: int = 72

var _player: Node2D = null
var _tracked: Dictionary = {}
var _collected_ids: Dictionary = {}
var _scan_left: float = 0.0
var _player_lookup_left: float = 0.0


func _ready() -> void:
	monitoring = true
	monitorable = true

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

	_sanitize_params()
	_apply_radius_to_collision()
	_build_ring()
	_refresh_player(true)
	_rescan_overlaps()


func _physics_process(delta: float) -> void:
	_maybe_refresh_player(delta)

	if scan_interval <= 0.0:
		_rescan_overlaps()
	else:
		_scan_left -= delta
		if _scan_left <= 0.0:
			_scan_left = scan_interval
			_rescan_overlaps()

	if not is_instance_valid(_player):
		return

	var center: Vector2 = _player.global_position
	var pickup_r2: float = pickup_radius * pickup_radius
	var keys: Array = _tracked.keys()

	for id_var in keys:
		var id := int(id_var)
		var state_variant: Variant = _tracked.get(id, {})
		if not (state_variant is Dictionary):
			_tracked.erase(id)
			continue

		var state: Dictionary = state_variant
		var node_variant: Variant = state.get("node", null)
		var n: Node2D = node_variant as Node2D

		if not is_instance_valid(n) or n.is_queued_for_deletion():
			_tracked.erase(id)
			continue

		if _collected_ids.has(id):
			_tracked.erase(id)
			continue

		var to_center := center - n.global_position
		if to_center.length_squared() <= pickup_r2:
			_collect_target(n)
			continue

		_pull_target(n, id, state, to_center, delta)


func _pull_target(n: Node2D, id: int, state: Dictionary, to_center: Vector2, delta: float) -> void:
	var settle_variant: Variant = state.get("settle_left", 0.0)
	var settle_left := float(settle_variant)
	if settle_left > 0.0:
		settle_left = maxf(settle_left - delta, 0.0)
		state["settle_left"] = settle_left
		_tracked[id] = state
		return

	if to_center.length_squared() <= 0.0001:
		return

	var dir: Vector2 = to_center.normalized()
	var speed_variant: Variant = state.get("speed", base_speed)
	var speed := float(speed_variant)
	speed = maxf(speed, base_speed)
	speed = minf(speed + attract_acceleration * delta, max_speed)
	state["speed"] = speed

	var vel_variant: Variant = state.get("vel", Vector2.ZERO)
	var vel := Vector2.ZERO
	if vel_variant is Vector2:
		vel = vel_variant
	var desired: Vector2 = dir * speed
	vel = vel.lerp(desired, minf(delta * 12.0, 1.0))
	state["vel"] = vel
	_tracked[id] = state

	if n.has_method("mining_pull_to"):
		n.call("mining_pull_to", _player.global_position, radius, attract_acceleration, max_speed, delta)
		return

	if n is RigidBody2D:
		var rb := n as RigidBody2D
		rb.apply_central_force(dir * attract_acceleration * rb.mass)
		if rb.linear_velocity.length_squared() > (max_speed * max_speed * 1.44):
			rb.linear_velocity = rb.linear_velocity.limit_length(max_speed)
		return

	n.global_position += vel * delta


func _collect_target(n: Node2D) -> void:
	var id := n.get_instance_id()
	if _collected_ids.has(id):
		return
	_collected_ids[id] = true
	_tracked.erase(id)

	if is_instance_valid(_player) and _player.has_method("add_energy_percent"):
		_player.call("add_energy_percent", energy_percent_gain)

	if collect_vfx_scene != null:
		var vfx: Node = collect_vfx_scene.instantiate()
		if vfx is Node2D:
			(vfx as Node2D).global_position = n.global_position
		var tree := get_tree()
		var parent: Node = tree.current_scene if tree != null else null
		if parent == null and tree != null:
			parent = tree.root
		if parent != null:
			parent.add_child(vfx)

	if n.has_method("on_mined"):
		n.call("on_mined", self)
	elif destroy_target_on_collect:
		n.queue_free()


func _on_body_entered(body: Node2D) -> void:
	var t := _resolve_target(body)
	if t != null:
		_track_target(t)


func _on_body_exited(body: Node2D) -> void:
	var t := _resolve_target(body)
	if t != null:
		_untrack_target(t)


func _on_area_entered(area: Area2D) -> void:
	var t := _resolve_target(area)
	if t != null:
		_track_target(t)


func _on_area_exited(area: Area2D) -> void:
	var t := _resolve_target(area)
	if t != null:
		_untrack_target(t)


func _resolve_target(n: Node) -> Node2D:
	var cur: Node = n
	var hops := 0
	while cur != null and hops < 8:
		if cur.is_in_group(target_group):
			var target := cur as Node2D
			if _is_player_friendly_target(target):
				return null
			return target
		cur = cur.get_parent()
		hops += 1
	return null


func _track_target(n: Node2D) -> void:
	if not is_instance_valid(n):
		return
	var id := n.get_instance_id()
	if _collected_ids.has(id) or _tracked.has(id):
		return

	_tracked[id] = {
		"node": n,
		"speed": base_speed,
		"vel": Vector2.ZERO,
		"settle_left": maxf(settle_time, 0.0),
	}


func _untrack_target(n: Node2D) -> void:
	if not is_instance_valid(n):
		return
	_tracked.erase(n.get_instance_id())


func _is_player_friendly_target(n: Node2D) -> bool:
	if n == null:
		return false
	if n.has_method("is_player_friendly") and bool(n.call("is_player_friendly")):
		return true
	return false


func _rescan_overlaps() -> void:
	for b in get_overlapping_bodies():
		var t := _resolve_target(b)
		if t != null:
			_track_target(t)

	for a in get_overlapping_areas():
		var t2 := _resolve_target(a)
		if t2 != null:
			_track_target(t2)


func _maybe_refresh_player(delta: float) -> void:
	if is_instance_valid(_player):
		return
	_player_lookup_left -= delta
	if _player_lookup_left <= 0.0:
		_player_lookup_left = 0.25
		_refresh_player(false)


func _refresh_player(force: bool) -> void:
	var tree := get_tree()
	if tree == null:
		_player = null
		return
	var p: Node = tree.get_first_node_in_group(player_group)
	var p2d: Node2D = p as Node2D
	if p2d != null:
		_player = p2d
	elif force:
		_player = null


func _sanitize_params() -> void:
	radius = maxf(radius, 0.0)
	pickup_radius = maxf(pickup_radius, 0.0)
	if pickup_radius > radius:
		radius = pickup_radius
	base_speed = maxf(base_speed, 0.0)
	max_speed = maxf(max_speed, 0.0)
	attract_acceleration = maxf(attract_acceleration, 0.0)


func _apply_radius_to_collision() -> void:
	var cs := get_node_or_null(collision_shape_path) as CollisionShape2D
	if cs == null or cs.shape == null:
		push_warning("MiningField: CollisionShape2D veya shape eksik. Alan calismayabilir.")
		return

	if cs.shape is CircleShape2D:
		(cs.shape as CircleShape2D).radius = radius
	else:
		push_warning("MiningField: Shape CircleShape2D degil. radius otomatik uygulanmadi.")


func _build_ring() -> void:
	var ring := get_node_or_null(ring_path) as Line2D
	if ring == null:
		return

	var seg := clampi(ring_segments, 12, 256)
	var pts := PackedVector2Array()
	for i in range(seg + 1):
		var a := (float(i) / float(seg)) * TAU
		pts.append(Vector2(cos(a), sin(a)) * radius)
	ring.points = pts
