class_name AsteroidCrystal
extends AsteroidBase

## Crystal asteroid — iron ile aynı kaya gövdesi.
## Tek fark: çatlak çizgileri, iç ışıma ve hit flash mavi kristal rengi.
## Ekstra _draw() katmanı yok — shader her şeyi halleder.

const SHADER_RES := preload("res://shaders/crystal_asteroid.gdshader")
const TEX_SIZE   := 128
const SCALE_MIN  := 0.90
const SCALE_MAX  := 1.10

const CRYSTAL_DEATH_DURATION : float = 0.35
const DEATH_FLASH_END         : float = 0.14
const DEATH_BREAK_END         : float = 0.72

var _sprite:     Sprite2D       = null
var _mat:        ShaderMaterial = null
var _rand_seed:  float          = 0.0
var _scale_var:  float          = 1.0
var _base_scale: float          = 1.0

var _death_shards: PackedFloat32Array = PackedFloat32Array()
var _shard_count:  int = 0


func _ready() -> void:
	super._ready()
	add_to_group("asteroid_crystal")
	_rand_seed = randf() * 100.0
	_scale_var = randf_range(SCALE_MIN, SCALE_MAX)
	_setup_sprite()


func _setup_sprite() -> void:
	_sprite = get_node_or_null("Sprite2D") as Sprite2D
	if _sprite == null:
		_sprite      = Sprite2D.new()
		_sprite.name = "Sprite2D"
		add_child(_sprite)

	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_sprite.texture        = ImageTexture.create_from_image(img)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	_base_scale   = (radius * 2.0) / float(TEX_SIZE)
	_sprite.scale = Vector2(_base_scale * _scale_var, _base_scale * _scale_var)
	_sprite.rotation = randf() * TAU

	_mat        = ShaderMaterial.new()
	_mat.shader = SHADER_RES
	_mat.set_shader_parameter("rand_seed",   _rand_seed)
	_mat.set_shader_parameter("hp_ratio",    1.0)
	_mat.set_shader_parameter("hit_flash",   0.0)
	var sf := clampf((radius - 8.0) / 42.0, 0.0, 1.0)
	_mat.set_shader_parameter("size_factor", sf)
	_sprite.material = _mat


# ── Per-frame ──────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _is_dying:
		_update_death_visuals()
	else:
		_sync_shader()


func _sync_shader() -> void:
	if _mat == null:
		return
	var hp_r  := clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 1.0
	var flash := _hit_flash_left / HIT_FLASH_DURATION
	_mat.set_shader_parameter("hp_ratio",  hp_r)
	_mat.set_shader_parameter("hit_flash", flash)


func _update_death_visuals() -> void:
	if _mat == null or _sprite == null:
		return
	var t := clampf(1.0 - (_death_time_left / CRYSTAL_DEATH_DURATION), 0.0, 1.0)

	if t < DEATH_FLASH_END:
		var pt := t / DEATH_FLASH_END
		_mat.set_shader_parameter("hp_ratio",  0.0)
		_mat.set_shader_parameter("hit_flash", 1.0 - pt * 0.8)
		var punch := 1.0 + sin(pt * PI) * 0.09
		_sprite.scale = Vector2(
			_base_scale * _scale_var * punch,
			_base_scale * _scale_var * punch
		)
		_sprite.modulate.a = 1.0

	elif t < DEATH_BREAK_END:
		var pt := (t - DEATH_FLASH_END) / (DEATH_BREAK_END - DEATH_FLASH_END)
		_mat.set_shader_parameter("hp_ratio",  0.0)
		_mat.set_shader_parameter("hit_flash", 0.0)
		var body_s := 1.0 - pt * 0.40
		_sprite.scale = Vector2(
			_base_scale * _scale_var * body_s,
			_base_scale * _scale_var * body_s
		)
		_sprite.modulate.a = clampf(1.0 - pt * 1.3, 0.0, 1.0)

	else:
		_mat.set_shader_parameter("hp_ratio",  0.0)
		_mat.set_shader_parameter("hit_flash", 0.0)
		_sprite.modulate.a = 0.0


# ── Death ──────────────────────────────────────────────────────────────────────

func _start_death() -> void:
	super._start_death()
	_death_time_left = CRYSTAL_DEATH_DURATION
	_spawn_death_shards()
	queue_redraw()


func _spawn_death_shards() -> void:
	_shard_count = randi_range(5, 7)
	_death_shards.resize(_shard_count * 6)
	var base_speed := radius * 3.2
	for i in range(_shard_count):
		var angle := TAU * float(i) / float(_shard_count) + randf_range(-0.3, 0.3)
		var spd   := base_speed * randf_range(0.65, 1.45)
		var b     := i * 6
		_death_shards[b + 0] = 0.0
		_death_shards[b + 1] = 0.0
		_death_shards[b + 2] = cos(angle) * spd
		_death_shards[b + 3] = sin(angle) * spd
		_death_shards[b + 4] = randf_range(3.2, 7.0)
		_death_shards[b + 5] = angle


# ── Drawing — sadece ölüm efekti, gövde shader'dan geliyor ───────────────────

func _draw() -> void:
	if _is_dying:
		_draw_death_burst()
		return
	if _is_dev_mode():
		_draw_dev_overlay()


func _draw_death_burst() -> void:
	if CRYSTAL_DEATH_DURATION <= 0.0:
		return
	var t := clampf(1.0 - (_death_time_left / CRYSTAL_DEATH_DURATION), 0.0, 1.0)

	# Faz 1: mavi kristal patlama halkası
	if t < DEATH_FLASH_END:
		var pt    := t / DEATH_FLASH_END
		var ring_r := radius * lerpf(0.7, 1.55, pt)
		var ring_a := lerpf(0.95, 0.0, pt * pt)
		draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 64,
			Color(0.35, 0.75, 1.0, ring_a), 3.5, true)
		draw_circle(Vector2.ZERO, radius * lerpf(0.55, 0.20, pt),
			Color(0.55, 0.88, 1.0, ring_a * 0.65))

	# Faz 2: mavi döküntü halkası genişliyor
	if t >= DEATH_FLASH_END and t < DEATH_BREAK_END:
		var pt    := (t - DEATH_FLASH_END) / (DEATH_BREAK_END - DEATH_FLASH_END)
		var ring_r := radius * lerpf(1.05, 2.4, pt)
		var ring_a := lerpf(0.45, 0.0, pt)
		draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 48,
			Color(0.20, 0.55, 0.90, ring_a), 1.6, true)

	# Kırıklar (faz 2 ve 3) — mavi kristal parçacıklar
	if t >= DEATH_FLASH_END and _shard_count > 0:
		var elapsed := (t - DEATH_FLASH_END) * CRYSTAL_DEATH_DURATION
		var shard_t := (t - DEATH_FLASH_END) / (1.0 - DEATH_FLASH_END)
		var shard_a := clampf(1.0 - shard_t * 1.15, 0.0, 1.0)
		var drag    := sqrt(clampf(shard_t, 0.0, 1.0))

		for i in range(_shard_count):
			var b         := i * 6
			var vx        := _death_shards[b + 2]
			var vy        := _death_shards[b + 3]
			var sz        := _death_shards[b + 4]
			var ang       := _death_shards[b + 5]
			var scale_fac := elapsed * (1.0 - drag * 0.45)
			var pos       := Vector2(vx * scale_fac, vy * scale_fac)
			var arc_r     := sz * (1.0 + shard_t * 0.5)
			# Mavi kristal parça yayları
			draw_arc(pos, arc_r, ang - PI * 0.20, ang + PI * 0.20, 8,
				Color(0.30, 0.70, 1.0, shard_a), 1.8, true)
			if shard_a > 0.25:
				draw_circle(pos + Vector2(cos(ang), sin(ang)) * arc_r, 1.4,
					Color(0.60, 0.92, 1.0, shard_a * 0.7))
