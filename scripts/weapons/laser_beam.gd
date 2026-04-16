extends Node2D
## Lazer saldırısı — raycast tabanlı, sürekli hasar veren ışın.
## attack_controller tarafından sahneye eklenir; belirli bir süre sonra queue_free().

const BEAM_LIFETIME:   float  = 0.09   # saniye (attack_controller'ın cooldown'uyla eşleşir)
const DAMAGE_TICK_HZ:  float  = 30.0   # saniyede kaç hasar tick'i

var _player:      Node2D = null
var _direction:   Vector2 = Vector2.RIGHT
var _damage:      float   = 3.0
var _elapsed:     float   = 0.0
var _tick_timer:  float   = 0.0
var _hit_point:   Vector2 = Vector2.ZERO
var _hit_body:    Object  = null
var _hit_valid:   bool    = false
var _time:        float   = 0.0  # görsel animasyon
var _beam_length: float   = 650.0  # her frame viewport'tan hesaplanır


func setup(player: Node2D, initial_dir: Vector2, damage: float) -> void:
	_player    = player
	_direction = initial_dir.normalized()
	_damage    = damage


func _physics_process(delta: float) -> void:
	_elapsed  += delta
	_time     += delta
	_tick_timer += delta

	if _elapsed >= BEAM_LIFETIME:
		queue_free()
		return

	if _player == null or not is_instance_valid(_player):
		queue_free()
		return

	# global_position'ı her fizik tick'inde player'a sabitle
	global_position = _player.global_position

	# Aim yönünü güncelle
	var to_mouse := get_global_mouse_position() - _player.global_position
	if to_mouse.length_squared() > 1.0:
		_direction = to_mouse.normalized()

	# Raycast
	_perform_raycast()

	# Hasar tick
	if _tick_timer >= (1.0 / DAMAGE_TICK_HZ):
		_tick_timer = 0.0
		_apply_damage()

	queue_redraw()


func _screen_half_diagonal() -> float:
	var vp := get_viewport()
	if vp == null:
		return 650.0
	var vp_size := vp.get_visible_rect().size
	var scale   := vp.get_canvas_transform().get_scale()
	var world_w := vp_size.x / maxf(scale.x, 0.001)
	var world_h := vp_size.y / maxf(scale.y, 0.001)
	return Vector2(world_w, world_h).length() * 0.5


func _perform_raycast() -> void:
	_hit_valid    = false
	_hit_body     = null
	_beam_length  = _screen_half_diagonal()
	var space := get_world_2d().direct_space_state
	if space == null:
		return

	var from  := _player.global_position + _direction * 37.0
	var to_pt := _player.global_position + _direction * _beam_length

	var params := PhysicsRayQueryParameters2D.create(from, to_pt)
	params.collision_mask = 0b0011   # layer 1 + 2 (asteroidler)
	# Oyuncuyu ve kendi node'unu dışarıda bırak
	var exclude_rids: Array[RID] = []
	if _player.get_class() == "CharacterBody2D":
		exclude_rids.append(_player.get_rid())
	if exclude_rids.size() > 0:
		params.exclude = exclude_rids

	var result := space.intersect_ray(params)
	if result.size() > 0:
		_hit_valid = true
		_hit_point = result["position"]
		_hit_body  = result.get("collider", null)


func _apply_damage() -> void:
	if not _hit_valid or _hit_body == null:
		return
	if not is_instance_valid(_hit_body):
		return
	if _hit_body.has_method("is_player_friendly") and bool(_hit_body.call("is_player_friendly")):
		return
	if _hit_body.has_method("add_scorch_mark"):
		var local_hit: Vector2 = _hit_body.to_local(_hit_point)
		var local_dir: Vector2 = _direction.rotated(-_hit_body.global_rotation)
		_hit_body.call("add_scorch_mark", local_hit, local_dir, randf_range(1.5, 3.2))
	if _hit_body.has_method("take_mining_damage"):
		_hit_body.take_mining_damage(_damage / DAMAGE_TICK_HZ)
	elif _hit_body.has_method("take_damage"):
		_hit_body.take_damage(_damage / DAMAGE_TICK_HZ)


func _draw() -> void:
	if _player == null:
		return

	# Lazer başlangıç/bitiş noktaları (local space — global_position = player.global_position)
	var start_local := _direction * 37.0
	var end_local: Vector2
	if _hit_valid:
		end_local = _hit_point - global_position
	else:
		end_local = _direction * _beam_length

	var life_t  := 1.0 - (_elapsed / BEAM_LIFETIME)
	var flicker := sin(_time * 45.0) * 0.12 + 0.88

	# Dış glow
	draw_line(start_local, end_local,
		Color(0.10, 0.88, 1.00, 0.20 * life_t * flicker), 7.0, true)
	# Orta katman
	draw_line(start_local, end_local,
		Color(0.20, 0.96, 1.00, 0.55 * life_t * flicker), 2.5, true)
	# Core
	draw_line(start_local, end_local,
		Color(0.85, 1.00, 1.00, 0.90 * life_t), 1.2, true)

	# İsabet noktası parlama
	if _hit_valid:
		var lp := end_local
		draw_circle(lp, 6.0,  Color(0.10, 0.88, 1.00, 0.30 * life_t))
		draw_circle(lp, 3.5,  Color(0.50, 1.00, 1.00, 0.70 * life_t))
		draw_circle(lp, 1.5,  Color(1.00, 1.00, 1.00, 0.95 * life_t))
