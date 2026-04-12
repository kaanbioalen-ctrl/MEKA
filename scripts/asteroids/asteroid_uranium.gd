class_name AsteroidUranium
extends AsteroidBase

const UraniumRadiationCloud = preload("res://scripts/effects/uranium_radiation_cloud.gd")
const SHADER_RES := preload("res://shaders/uranium_asteroid.gdshader")
const TEX_SIZE   := 128
const SCALE_MIN  := 0.90
const SCALE_MAX  := 1.10

const URANIUM_DEATH_DURATION : float = 0.35
const DEATH_FLASH_END         : float = 0.14
const DEATH_BREAK_END         : float = 0.72
const EXPLOSION_RADIUS_MULT   : float = 4.6
const EXPLOSION_DAMAGE_MULT   : float = 6.0
const RADIATION_CLOUD_RADIUS_MULT: float = 6.2
const PLAYER_KILL_DELAY: float = 0.18

var _sprite:     Sprite2D       = null
var _mat:        ShaderMaterial = null
var _rand_seed:  float          = 0.0
var _scale_var:  float          = 1.0
var _base_scale: float          = 1.0

var _death_shards: PackedFloat32Array = PackedFloat32Array()
var _shard_count: int = 0


func _ready() -> void:
	super._ready()
	add_to_group("asteroid_uranium")
	_rand_seed = randf() * 100.0
	_scale_var = randf_range(SCALE_MIN, SCALE_MAX)
	_setup_sprite()


func _setup_sprite() -> void:
	_sprite = get_node_or_null("Sprite2D") as Sprite2D
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite2D"
		add_child(_sprite)

	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_sprite.texture = ImageTexture.create_from_image(img)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	_base_scale = (radius * 2.0) / float(TEX_SIZE)
	_sprite.scale = Vector2(_base_scale * _scale_var, _base_scale * _scale_var)
	_sprite.rotation = randf() * TAU

	_mat = ShaderMaterial.new()
	_mat.shader = SHADER_RES
	_mat.set_shader_parameter("rand_seed", _rand_seed)
	_mat.set_shader_parameter("hp_ratio", 1.0)
	_mat.set_shader_parameter("hit_flash", 0.0)
	var sf := clampf((radius - 8.0) / 42.0, 0.0, 1.0)
	_mat.set_shader_parameter("size_factor", sf)
	_sprite.material = _mat


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _is_dying:
		_update_death_visuals()
	else:
		_sync_shader()


func _sync_shader() -> void:
	if _mat == null:
		return
	var hp_r := clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 1.0
	var flash := _hit_flash_left / HIT_FLASH_DURATION
	_mat.set_shader_parameter("hp_ratio", hp_r)
	_mat.set_shader_parameter("hit_flash", flash)


func _update_death_visuals() -> void:
	if _mat == null or _sprite == null:
		return
	var t := clampf(1.0 - (_death_time_left / URANIUM_DEATH_DURATION), 0.0, 1.0)

	if t < DEATH_FLASH_END:
		var pt := t / DEATH_FLASH_END
		_mat.set_shader_parameter("hp_ratio", 0.0)
		_mat.set_shader_parameter("hit_flash", 1.0 - pt * 0.8)
		var punch := 1.0 + sin(pt * PI) * 0.09
		_sprite.scale = Vector2(
			_base_scale * _scale_var * punch,
			_base_scale * _scale_var * punch
		)
		_sprite.modulate.a = 1.0
	elif t < DEATH_BREAK_END:
		var pt := (t - DEATH_FLASH_END) / (DEATH_BREAK_END - DEATH_FLASH_END)
		_mat.set_shader_parameter("hp_ratio", 0.0)
		_mat.set_shader_parameter("hit_flash", 0.0)
		var body_s := 1.0 - pt * 0.40
		_sprite.scale = Vector2(
			_base_scale * _scale_var * body_s,
			_base_scale * _scale_var * body_s
		)
		_sprite.modulate.a = clampf(1.0 - pt * 1.3, 0.0, 1.0)
	else:
		_mat.set_shader_parameter("hp_ratio", 0.0)
		_mat.set_shader_parameter("hit_flash", 0.0)
		_sprite.modulate.a = 0.0


func _start_death() -> void:
	_trigger_explosion_blast()
	_spawn_radiation_cloud()
	super._start_death()
	_death_time_left = URANIUM_DEATH_DURATION
	_spawn_death_shards()
	queue_redraw()


func _trigger_explosion_blast() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var blast_radius := radius * EXPLOSION_RADIUS_MULT
	var blast_damage := maxf(max_hp, radius * EXPLOSION_DAMAGE_MULT)

	for node in tree.get_nodes_in_group("player"):
		if not (node is Node2D):
			continue
		var player_node := node as Node2D
		if not is_instance_valid(player_node):
			continue
		if global_position.distance_to(player_node.global_position) <= blast_radius:
			_schedule_player_death(player_node)

	for node in tree.get_nodes_in_group("enemy"):
		if not (node is Node2D):
			continue
		var enemy_node := node as Node2D
		if not is_instance_valid(enemy_node):
			continue
		if global_position.distance_to(enemy_node.global_position) > blast_radius:
			continue
		if enemy_node.has_method("take_damage"):
			enemy_node.call("take_damage", blast_damage)

	for node in tree.get_nodes_in_group("asteroid"):
		if node == self or not (node is Node2D):
			continue
		var asteroid_node := node as Node2D
		if not is_instance_valid(asteroid_node):
			continue
		if global_position.distance_to(asteroid_node.global_position) > blast_radius:
			continue
		if asteroid_node.has_method("take_mining_damage"):
			asteroid_node.call("take_mining_damage", blast_damage)


func _schedule_player_death(player_node: Node2D) -> void:
	if player_node == null or not is_instance_valid(player_node):
		return
	var tree := get_tree()
	if tree == null:
		return
	var timer := tree.create_timer(PLAYER_KILL_DELAY)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(player_node) and player_node.has_method("die"):
			player_node.call("die")
	, CONNECT_ONE_SHOT)


func _spawn_radiation_cloud() -> void:
	if UraniumRadiationCloud == null:
		return
	var tree := get_tree()
	if tree == null:
		return
	var parent := tree.current_scene
	if parent == null:
		parent = tree.root
	var cloud := UraniumRadiationCloud.new()
	if cloud == null:
		return
	parent.add_child(cloud)
	var player_node := tree.get_first_node_in_group("player") as Node2D
	cloud.setup(global_position, radius * RADIATION_CLOUD_RADIUS_MULT, player_node)


func _spawn_death_shards() -> void:
	_shard_count = randi_range(5, 7)
	_death_shards.resize(_shard_count * 6)
	var base_speed := radius * 3.2
	for i in range(_shard_count):
		var angle := TAU * float(i) / float(_shard_count) + randf_range(-0.3, 0.3)
		var spd := base_speed * randf_range(0.65, 1.45)
		var b := i * 6
		_death_shards[b + 0] = 0.0
		_death_shards[b + 1] = 0.0
		_death_shards[b + 2] = cos(angle) * spd
		_death_shards[b + 3] = sin(angle) * spd
		_death_shards[b + 4] = randf_range(3.2, 7.0)
		_death_shards[b + 5] = angle


func _draw() -> void:
	if _is_dying:
		_draw_death_burst()
		return
	if _is_dev_mode():
		_draw_dev_overlay()


func _draw_death_burst() -> void:
	if URANIUM_DEATH_DURATION <= 0.0:
		return
	var t := clampf(1.0 - (_death_time_left / URANIUM_DEATH_DURATION), 0.0, 1.0)
	var radiation_fade := clampf(1.0 - t * 0.9, 0.0, 1.0)
	var radiation_ring_r := radius * lerpf(1.4, 5.2, t)
	var haze_r := radius * lerpf(1.8, 6.2, t)

	draw_circle(Vector2.ZERO, haze_r, Color(0.08, 0.62, 0.04, 0.11 * radiation_fade))
	draw_circle(Vector2.ZERO, haze_r * 0.72, Color(0.32, 1.0, 0.18, 0.08 * radiation_fade))
	draw_arc(Vector2.ZERO, radiation_ring_r, 0.0, TAU, 96, Color(0.12, 1.0, 0.0, 0.34 * radiation_fade), 3.8, true)
	draw_arc(Vector2.ZERO, radiation_ring_r * 0.78, 0.0, TAU, 88, Color(0.62, 1.0, 0.40, 0.22 * radiation_fade), 1.8, true)

	if t < DEATH_FLASH_END:
		var pt := t / DEATH_FLASH_END
		var ring_r := radius * lerpf(0.9, 2.8, pt)
		var ring_a := lerpf(0.95, 0.0, pt * pt)
		draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 64, Color(0.12, 1.0, 0.0, ring_a), 4.8, true)
		draw_circle(Vector2.ZERO, radius * lerpf(0.55, 0.20, pt), Color(0.45, 1.0, 0.32, ring_a * 0.65))

	if t >= DEATH_FLASH_END and t < DEATH_BREAK_END:
		var pt := (t - DEATH_FLASH_END) / (DEATH_BREAK_END - DEATH_FLASH_END)
		var ring_r := radius * lerpf(1.05, 2.4, pt)
		var ring_a := lerpf(0.45, 0.0, pt)
		draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 48, Color(0.12, 0.88, 0.18, ring_a), 1.6, true)
		var toxic_tail_r := radius * lerpf(1.6, 3.0, pt)
		draw_arc(Vector2.ZERO, toxic_tail_r, -PI * 0.24, PI * 0.38, 28, Color(0.55, 1.0, 0.22, ring_a * 0.7), 2.0, true)
		draw_arc(Vector2.ZERO, toxic_tail_r * 0.88, PI * 0.72, PI * 1.42, 24, Color(0.18, 0.84, 0.10, ring_a * 0.58), 1.3, true)

	if t >= DEATH_FLASH_END and _shard_count > 0:
		var elapsed := (t - DEATH_FLASH_END) * URANIUM_DEATH_DURATION
		var shard_t := (t - DEATH_FLASH_END) / (1.0 - DEATH_FLASH_END)
		var shard_a := clampf(1.0 - shard_t * 1.15, 0.0, 1.0)
		var drag := sqrt(clampf(shard_t, 0.0, 1.0))
		for i in range(_shard_count):
			var b := i * 6
			var vx := _death_shards[b + 2]
			var vy := _death_shards[b + 3]
			var sz := _death_shards[b + 4]
			var ang := _death_shards[b + 5]
			var scale_fac := elapsed * (1.0 - drag * 0.45)
			var pos := Vector2(vx * scale_fac, vy * scale_fac)
			var arc_r := sz * (1.0 + shard_t * 0.5)
			draw_arc(pos, arc_r, ang - PI * 0.20, ang + PI * 0.20, 8, Color(0.20, 1.0, 0.08, shard_a), 1.8, true)
			if shard_a > 0.25:
				draw_circle(pos + Vector2(cos(ang), sin(ang)) * arc_r, 1.4, Color(0.72, 1.0, 0.55, shard_a * 0.7))
