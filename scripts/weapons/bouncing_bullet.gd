extends Area2D
## Seken mermi — her sekte hasar verir, bounce_count kadar sekip yok olur.
## setup() çağrıldıktan sonra fizik döngüsünde kendi kendine hareket eder.

const BULLET_SPEED:    float  = 380.0
const BULLET_LIFETIME: float  = 4.0
const TRAIL_LEN:       int    = 14
const BULLET_RADIUS:   float  = 4.0

var _velocity:       Vector2 = Vector2.ZERO
var _damage:         float   = 4.0
var _bounces_left:   int     = 3
var _elapsed:        float   = 0.0
var _time:           float   = 0.0
var _world_bounds:   Rect2   = Rect2()
var _has_bounds:     bool    = false
var _trail:          Array   = []
var _hit_ids:        Dictionary = {}   # çift hasar önleme


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	monitoring   = true
	monitorable  = false
	# Layer/mask: layer 8 (projectile), mask 1+2 (asteroid)
	collision_layer = 128   # bit 7
	collision_mask  = 3     # bit 0 + 1


func setup(direction: Vector2, damage: float, bounces: int, world_bounds: Rect2) -> void:
	_velocity     = direction.normalized() * BULLET_SPEED
	_damage       = damage
	_bounces_left = bounces
	if world_bounds.size.length_squared() > 0.0:
		_world_bounds = world_bounds
		_has_bounds   = true


func _physics_process(delta: float) -> void:
	_elapsed += delta
	_time    += delta

	if _elapsed >= BULLET_LIFETIME:
		queue_free()
		return

	# Hareket
	global_position += _velocity * delta

	# Dünya sınırı sekme
	if _has_bounds:
		_bounce_off_bounds()

	# Trail kaydet
	_trail.append(global_position)
	if _trail.size() > TRAIL_LEN:
		_trail.pop_front()

	# Frame başında hit_ids temizle (çift hasar önle)
	_hit_ids.clear()

	queue_redraw()


func _bounce_off_bounds() -> void:
	var b := _world_bounds
	var bounced := false
	if global_position.x < b.position.x:
		global_position.x = b.position.x + 1.0
		_velocity.x = absf(_velocity.x)
		bounced = true
	elif global_position.x > b.position.x + b.size.x:
		global_position.x = b.position.x + b.size.x - 1.0
		_velocity.x = -absf(_velocity.x)
		bounced = true
	if global_position.y < b.position.y:
		global_position.y = b.position.y + 1.0
		_velocity.y = absf(_velocity.y)
		bounced = true
	elif global_position.y > b.position.y + b.size.y:
		global_position.y = b.position.y + b.size.y - 1.0
		_velocity.y = -absf(_velocity.y)
		bounced = true
	if bounced:
		_do_bounce()


func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)


func _on_body_entered(body: Node2D) -> void:
	_try_hit(body)


func _try_hit(target: Node) -> void:
	if target == null:
		return
	var uid := target.get_instance_id()
	if _hit_ids.has(uid):
		return
	_hit_ids[uid] = true

	# Sadece asteroid veya enemy grubundaki şeylere çarp
	var is_target := target.is_in_group("asteroid") or target.is_in_group("enemy")
	if not is_target:
		return

	# Hasar ver
	if target.has_method("take_mining_damage"):
		target.take_mining_damage(_damage)
	elif target.has_method("take_damage"):
		target.take_damage(_damage)

	# Yüzeyden sekme
	_reflect_off(target)
	_do_bounce()


func _reflect_off(target: Node) -> void:
	# Hedefin merkezinden uzaklaşacak şekilde yansıt
	var to_target := Vector2.ZERO
	if target is Node2D:
		to_target = (target as Node2D).global_position - global_position
	if to_target.length_squared() < 0.01:
		to_target = Vector2.RIGHT
	var normal := -to_target.normalized()
	_velocity = _velocity.bounce(normal)
	# Küçük rastgele saçılma ekle — daha organik
	var scatter := randf_range(-0.25, 0.25)
	_velocity = _velocity.rotated(scatter)
	_velocity  = _velocity.normalized() * BULLET_SPEED


func _do_bounce() -> void:
	_bounces_left -= 1
	if _bounces_left <= 0:
		queue_free()


func _draw() -> void:
	# Trail
	var trail_count := _trail.size()
	for i in range(1, trail_count):
		var from:  Vector2 = _trail[i - 1] - global_position
		var to_pt: Vector2 = _trail[i]     - global_position
		var t     := float(i) / float(trail_count)
		draw_line(from, to_pt, Color(1.00, 0.82, 0.18, t * 0.5), lerpf(0.5, 2.5, t), true)

	# Core bullet
	draw_circle(Vector2.ZERO, BULLET_RADIUS, Color(1.00, 0.90, 0.30, 1.0))
	# Glow
	draw_circle(Vector2.ZERO, BULLET_RADIUS + 3.0, Color(1.00, 0.70, 0.10, 0.35))

	# Kalan sekme sayısı göstergesi — küçük dönen noktalar
	if _bounces_left > 0:
		var dot_r := BULLET_RADIUS + 7.0
		var base_angle := _time * 2.5
		for i in _bounces_left:
			var a := base_angle + (float(i) / float(max(1, _bounces_left))) * TAU
			var pt := Vector2(cos(a), sin(a)) * dot_r
			draw_circle(pt, 1.5, Color(1.00, 0.82, 0.18, 0.8))
