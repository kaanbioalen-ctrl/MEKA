extends Area2D
## Homing roket — en yakın hedefe kilitlenir, çarptığında patlama alanı hasarı.

const ROCKET_SPEED:     float = 220.0
const ROCKET_TURN:      float = 3.5    # rad/s
const ROCKET_LIFETIME:  float = 6.0
const TRAIL_LEN:        int   = 18

var _velocity:         Vector2 = Vector2.ZERO
var _damage:           float   = 12.0
var _explosion_radius: float   = 80.0
var _elapsed:          float   = 0.0
var _time:             float   = 0.0
var _target:           Node2D  = null
var _exploded:         bool    = false
var _trail:            Array   = []


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	monitoring   = true
	monitorable  = false
	collision_layer = 128   # bit 7
	collision_mask  = 3     # bit 0 + 1


func setup(initial_dir: Vector2, damage: float, explosion_radius: float) -> void:
	_velocity         = initial_dir.normalized() * ROCKET_SPEED
	_damage           = damage
	_explosion_radius = explosion_radius
	_acquire_target()


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_elapsed += delta
	_time    += delta

	if _elapsed >= ROCKET_LIFETIME:
		_explode()
		return

	# Hedef doğrulama ve yeniden kilit
	if _target == null or not is_instance_valid(_target):
		_acquire_target()

	# Steering
	if _target != null and is_instance_valid(_target):
		var desired := (_target.global_position - global_position).normalized()
		var current := _velocity.normalized()
		var new_dir  := current.slerp(desired, clampf(ROCKET_TURN * delta, 0.0, 1.0))
		_velocity    = new_dir * ROCKET_SPEED

	# Hareket
	global_position += _velocity * delta
	# Sprite yönü (draw_colored_polygon yönünü de döndürmek için rotation kullan)
	if _velocity.length_squared() > 0.01:
		rotation = _velocity.angle()

	# Trail
	_trail.append(global_position)
	if _trail.size() > TRAIL_LEN:
		_trail.pop_front()

	queue_redraw()


func _acquire_target() -> void:
	_target = null
	var candidates: Array = []
	candidates.append_array(get_tree().get_nodes_in_group("asteroid"))
	candidates.append_array(get_tree().get_nodes_in_group("enemy"))

	var best_dist := INF
	for node in candidates:
		if not is_instance_valid(node):
			continue
		if not (node is Node2D):
			continue
		var d := global_position.distance_squared_to((node as Node2D).global_position)
		if d < best_dist:
			best_dist = d
			_target   = node


func _on_area_entered(area: Area2D) -> void:
	if _exploded:
		return
	if area.is_in_group("asteroid") or area.is_in_group("enemy"):
		_explode()


func _on_body_entered(body: Node2D) -> void:
	if _exploded:
		return
	if body.is_in_group("asteroid") or body.is_in_group("enemy"):
		_explode()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	monitoring = false

	# Patlama alanındaki tüm hedeflere hasar
	var candidates: Array = []
	candidates.append_array(get_tree().get_nodes_in_group("asteroid"))
	candidates.append_array(get_tree().get_nodes_in_group("enemy"))

	for node in candidates:
		if not is_instance_valid(node):
			continue
		if not (node is Node2D):
			continue
		var dist := global_position.distance_to((node as Node2D).global_position)
		if dist > _explosion_radius:
			continue
		var falloff := 1.0 - clampf(dist / _explosion_radius, 0.0, 1.0)
		var final_dmg := _damage * falloff
		if node.has_method("take_mining_damage"):
			node.take_mining_damage(final_dmg)
		elif node.has_method("take_damage"):
			node.take_damage(final_dmg)

	# Patlama görsel efekti
	_spawn_explosion_visual()
	queue_free()


func _spawn_explosion_visual() -> void:
	# player_overload_burst.gd'ye benzer basit patlama efekti
	var burst: Node2D = Node2D.new()
	burst.name = "RocketExplosion"
	get_parent().add_child(burst)
	burst.global_position = global_position

	var script := preload("res://scripts/weapons/rocket_explosion.gd")
	burst.set_script(script)
	burst.call("setup", _explosion_radius)


func _draw() -> void:
	# Trail — local space
	var trail_count := _trail.size()
	for i in range(1, trail_count):
		var from:  Vector2 = _trail[i - 1] - global_position
		var to_pt: Vector2 = _trail[i]     - global_position
		var t     := float(i) / float(trail_count)
		draw_line(from, to_pt, Color(1.00, 0.40, 0.08, t * 0.55), lerpf(0.5, 3.0, t), true)

	# Roket gövdesi — 0° = sağa (rotation ile döner)
	# draw çağrıları local space'de; rotation zaten uygulanıyor
	var body_pts := PackedVector2Array([
		Vector2( 9.0,  0.0),   # burun
		Vector2( 5.0,  2.5),
		Vector2(-5.0,  3.0),   # kuyruk üst
		Vector2(-8.0,  5.5),   # kanat uç
		Vector2(-8.0, -5.5),
		Vector2(-5.0, -3.0),   # kuyruk alt
		Vector2( 5.0, -2.5),
	])
	draw_colored_polygon(body_pts, Color(1.00, 0.35, 0.08, 0.95))
	draw_colored_polygon(body_pts, Color(1.00, 0.85, 0.50, 0.25))

	# Motor exhaust
	var ex_a := sin(_time * 20.0) * 0.4 + 0.6
	draw_circle(Vector2(-8.0, 0.0), 3.5, Color(1.0, 0.6, 0.1, ex_a * 0.85))
	draw_circle(Vector2(-8.0, 0.0), 2.0, Color(1.0, 1.0, 0.6, ex_a))

	# Hedef kilit göstergesi
	if _target != null and is_instance_valid(_target):
		var lock_dir := (_target.global_position - global_position).normalized()
		var a_start  := lock_dir.angle() - 0.35
		var a_end    := lock_dir.angle() + 0.35
		draw_arc(Vector2.ZERO, 12.0, a_start, a_end, 6,
			Color(1.0, 0.4, 0.1, 0.55 + sin(_time * 6.0) * 0.2), 1.5, true)
