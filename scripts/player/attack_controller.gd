extends Node2D
## Silah sistemi kontrolcüsü.
## player.gd'ye direkt child olarak eklenir (VisualRoot dışında — fizik/ateş işi).
## Auto-fire: cooldown'a göre mouse yönüne otomatik ateşler.

const UpgradeEffects = preload("res://scripts/upgrades/upgrade_effects.gd")

const BOUNCING_BULLET_SCENE: PackedScene = preload("res://scenes/weapons/bouncing_bullet.tscn")
const ROCKET_SCENE:          PackedScene = preload("res://scenes/weapons/rocket.tscn")
const _LASER_SCRIPT                      = preload("res://scripts/weapons/laser_beam.gd")

const _LASER_SFX_PATH := "res://assets/sfx/laser_fire.mp3"

enum WeaponType { NONE = 0, LASER = 1, BULLET = 2, ROCKET = 3 }

var _active_weapon:  int    = WeaponType.NONE
var _cooldown_left:  float  = 0.0
var _weapon_ring:    Node2D = null   # player.gd tarafından set edilir
var _player:         Node2D = null   # parent player

# Aktif lazer node'u (aynı anda yalnızca bir tane)
var _live_laser:     Node2D = null

# Lazer ses oynatıcısı
var _laser_sfx: AudioStreamPlayer = null


func _ready() -> void:
	_player = get_parent()
	_setup_laser_sfx()


func _setup_laser_sfx() -> void:
	_laser_sfx = AudioStreamPlayer.new()
	_laser_sfx.volume_db = -4.0
	var stream = load(_LASER_SFX_PATH)
	print("[LaserSFX] stream yuklendi mi: ", stream != null, " | yol: ", _LASER_SFX_PATH)
	if stream == null:
		push_warning("AttackController: lazer ses dosyası yüklenemedi: " + _LASER_SFX_PATH)
	else:
		_laser_sfx.stream = stream
	add_child(_laser_sfx)
	print("[LaserSFX] AudioStreamPlayer eklendi, stream: ", _laser_sfx.stream)


func _physics_process(delta: float) -> void:
	if _player == null or (_player.has_method("is_dead") and _player.call("is_dead")):
		return
	if _player.get("_is_dead") == true:
		return

	var rs          := get_node_or_null("/root/RunState")
	var new_weapon  := _determine_active_weapon(rs)

	# Silah değişimi
	if new_weapon != _active_weapon:
		_active_weapon = new_weapon
		_cooldown_left = 0.0
		if _weapon_ring != null:
			_weapon_ring.set_weapon_type(_active_weapon)
			_clean_live_laser()

	if _active_weapon == WeaponType.NONE:
		return

	# Aim yönünü ring'e ilet
	var aim_dir := _get_aim_direction()
	if _weapon_ring != null:
		_weapon_ring.set_aim_direction(aim_dir)

	# Cooldown
	_cooldown_left = maxf(0.0, _cooldown_left - delta)

	# Ring cooldown ratio
	var cd_total := _get_cooldown(rs)
	if _weapon_ring != null:
		_weapon_ring.set_cooldown_ratio(_cooldown_left / maxf(0.001, cd_total))

	# Ateş
	if _cooldown_left <= 0.0:
		_fire(rs, aim_dir)
		_cooldown_left = _get_cooldown(rs)


# ── Silah belirleme ────────────────────────────────────────────────────────────

func _determine_active_weapon(rs: Node) -> int:
	if UpgradeEffects.is_rocket_unlocked(rs):
		return WeaponType.ROCKET
	if UpgradeEffects.is_bullet_unlocked(rs):
		return WeaponType.BULLET
	if UpgradeEffects.is_laser_unlocked(rs):
		return WeaponType.LASER
	return WeaponType.NONE


# ── Cooldown getter ────────────────────────────────────────────────────────────

func _get_cooldown(rs: Node) -> float:
	match _active_weapon:
		WeaponType.LASER:
			return UpgradeEffects.get_laser_cooldown(rs)
		WeaponType.BULLET:
			return UpgradeEffects.get_bullet_cooldown(rs)
		WeaponType.ROCKET:
			return UpgradeEffects.get_rocket_cooldown(rs)
		_:
			return 1.0


# ── Aim yönü ──────────────────────────────────────────────────────────────────

func _get_aim_direction() -> Vector2:
	if _player == null:
		return Vector2.RIGHT

	# En yakın serbest asteroidi bul
	var nearest: Node2D = null
	var nearest_dist_sq: float = INF
	var tree := get_tree()
	if tree != null:
		for body in tree.get_nodes_in_group("asteroid"):
			if not is_instance_valid(body):
				continue
			var node := body as Node2D
			if node == null:
				continue
			# Yakalanmış (ORBITING=1) veya ölmekte olan asteroidi atla
			if body.get("_is_dying") == true:
				continue
			if int(body.get("orbit_state")) == 1:
				continue
			var d := _player.global_position.distance_squared_to(node.global_position)
			if d < nearest_dist_sq:
				nearest_dist_sq = d
				nearest = node

	if nearest != null:
		var to_target := nearest.global_position - _player.global_position
		if to_target.length_squared() > 1.0:
			return to_target.normalized()

	# Hedef yoksa mouse yönüne fallback
	var to_mouse := get_global_mouse_position() - _player.global_position
	if to_mouse.length_squared() < 1.0:
		return Vector2.RIGHT
	return to_mouse.normalized()


# ── Ateş dispatch ──────────────────────────────────────────────────────────────

func _fire(rs: Node, dir: Vector2) -> void:
	match _active_weapon:
		WeaponType.LASER:
			_fire_laser(rs, dir)
		WeaponType.BULLET:
			_fire_bullet(rs, dir)
		WeaponType.ROCKET:
			_fire_rocket(rs, dir)

	if _weapon_ring != null:
		_weapon_ring.notify_fired(dir)


func _fire_laser(rs: Node, dir: Vector2) -> void:
	_clean_live_laser()
	var damage  := UpgradeEffects.get_laser_damage(rs)
	var beam    := _LASER_SCRIPT.new()
	beam.name   = "LaserBeam"
	# Lazer player'ın parent sahnesine eklenir — dünya koordinatlarında
	var scene_root := _get_scene_root()
	if scene_root == null:
		return
	scene_root.add_child(beam)
	beam.setup(_player, dir, damage)
	_live_laser = beam
	_play_laser_sfx()


func _fire_bullet(rs: Node, dir: Vector2) -> void:
	var damage  := UpgradeEffects.get_bullet_damage(rs)
	var bounces := UpgradeEffects.get_bullet_bounce_count(rs)
	var scene_root := _get_scene_root()
	if scene_root == null:
		return
	var bullet: Node2D = BOUNCING_BULLET_SCENE.instantiate()
	scene_root.add_child(bullet)
	var spawn_pos := _player.global_position + dir * (32.0 + 6.0)
	bullet.global_position = spawn_pos
	# Dünya sınırları
	var bounds: Rect2 = Rect2()
	if _player.get("_has_movement_bounds") == true:
		bounds = _player.get("_movement_bounds")
	bullet.call("setup", dir, damage, bounces, bounds)


func _fire_rocket(rs: Node, dir: Vector2) -> void:
	var damage  := UpgradeEffects.get_rocket_damage(rs)
	var radius  := UpgradeEffects.get_rocket_explosion_radius(rs)
	var scene_root := _get_scene_root()
	if scene_root == null:
		return
	var rocket: Node2D = ROCKET_SCENE.instantiate()
	scene_root.add_child(rocket)
	var spawn_pos := _player.global_position + dir * (32.0 + 7.0)
	rocket.global_position = spawn_pos
	rocket.call("setup", dir, damage, radius)


# ── Yardımcılar ────────────────────────────────────────────────────────────────

func _get_scene_root() -> Node:
	# Player'ın parent sahnesi — world node'u
	if _player == null:
		return null
	return _player.get_parent()


func _play_laser_sfx() -> void:
	if _laser_sfx == null or _laser_sfx.stream == null:
		return
	_laser_sfx.stop()
	_laser_sfx.play()


func _clean_live_laser() -> void:
	if _live_laser != null and is_instance_valid(_live_laser):
		_live_laser.queue_free()
	_live_laser = null
