extends AsteroidBase
class_name AsteroidGold

## Gold asteroid — gradually reveals gold appearance as damage is taken.
## Iron shader fades out, gold shader fades in based on hp loss.
## At full hp: looks identical to iron asteroid.
## As hp drops: gold veins emerge progressively, fully gold near death.

const GOLD_SHADER_RES := preload("res://shaders/gold_asteroid.gdshader")
const IRON_SHADER_RES := preload("res://shaders/iron_asteroid.gdshader")
const TEX_SIZE   := 128

const SCALE_MIN  := 0.90
const SCALE_MAX  := 1.10

const GOLD_DEATH_DURATION : float = 0.38
const DEATH_FLASH_END     : float = 0.065

# Reveal curve exponent — higher = slower start, faster finish
# 1.4 feels natural: first hits barely hint gold, last hits strongly reveal
const REVEAL_CURVE : float = 1.4

var _sprite_iron : Sprite2D       = null
var _sprite_gold : Sprite2D       = null
var _mat_iron    : ShaderMaterial = null
var _mat_gold    : ShaderMaterial = null
var _rand_seed   : float          = 0.0
var _scale_var   : float          = 1.0
var _base_scale  : float          = 1.0
var _gold_reveal : float          = 0.0   # 0.0 = iron, 1.0 = gold


func _ready() -> void:
	super._ready()
	add_to_group("asteroid_gold")
	_rand_seed = randf() * 100.0
	_scale_var = randf_range(SCALE_MIN, SCALE_MAX)
	_setup_sprite()


func _setup_sprite() -> void:
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex        := ImageTexture.create_from_image(img)
	_base_scale    = (radius * 2.0) / float(TEX_SIZE)
	var sc         := Vector2(_base_scale * _scale_var, _base_scale * _scale_var)
	var rot        := randf() * TAU
	var sf         := clampf((radius - 8.0) / 42.0, 0.0, 1.0)

	# ── Iron layer — fully visible at start, fades out as gold reveals ────────
	_sprite_iron = _make_sprite("SpriteIron", tex, sc, rot)
	_mat_iron    = ShaderMaterial.new()
	_mat_iron.shader = IRON_SHADER_RES
	_mat_iron.set_shader_parameter("rand_seed",   _rand_seed)
	_mat_iron.set_shader_parameter("hp_ratio",    1.0)
	_mat_iron.set_shader_parameter("hit_flash",   0.0)
	_mat_iron.set_shader_parameter("size_factor", sf)
	_sprite_iron.material = _mat_iron

	# ── Gold layer — starts invisible, fades in as damage accumulates ─────────
	_sprite_gold = _make_sprite("SpriteGold", tex, sc, rot)
	_mat_gold    = ShaderMaterial.new()
	_mat_gold.shader = GOLD_SHADER_RES
	_mat_gold.set_shader_parameter("rand_seed",   _rand_seed)
	_mat_gold.set_shader_parameter("hp_ratio",    1.0)
	_mat_gold.set_shader_parameter("hit_flash",   0.0)
	_mat_gold.set_shader_parameter("size_factor", sf)
	_sprite_gold.material = _mat_gold
	_sprite_gold.modulate = Color(1.0, 1.0, 1.0, 0.0)   # invisible at start


func _make_sprite(node_name: String, tex: ImageTexture, sc: Vector2, rot: float) -> Sprite2D:
	var existing := get_node_or_null(node_name)
	if existing != null:
		existing.queue_free()
	var s := Sprite2D.new()
	s.name           = node_name
	s.texture        = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.scale          = sc
	s.rotation       = rot
	add_child(s)
	return s


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _is_dying:
		_update_death_sprite()
	else:
		_sync_shader()


func _sync_shader() -> void:
	if _mat_iron == null or _mat_gold == null:
		return
	var hp_r  := clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 1.0
	var flash := _hit_flash_left / HIT_FLASH_DURATION

	var dmg := 1.0 - hp_r   # 0.0 = tam can, 1.0 = ölüm

	# ── Gold alpha: %25 hasara kadar sıfır, sonra kademeli quadratic artış ──
	var raw      := clampf((dmg - 0.25) / 0.75, 0.0, 1.0)
	_gold_reveal  = raw * raw   # yavaş başlar, sona doğru hızlanır

	# ── Iron: %8'den itibaren ısınan metal tonu — gold gelmeden önce hazırlar ──
	var warm_t := _smoothstep(0.08, 0.78, dmg)
	_sprite_iron.modulate = Color(
		1.0,
		lerpf(1.0, 0.80, warm_t),   # yeşil azalır → sıcak ton
		lerpf(1.0, 0.52, warm_t),   # mavi azalır → altınsı ısı
		1.0 - _gold_reveal
	)

	# ── Gold rengi: düşük reveal'da desature (iron tonuna yakın), yükseldikçe tam altın ──
	# Böylece gold ilk belirdiğinde "ani parlak turuncu" değil, "ısınan kaya" gibi görünür
	var color_t := _smoothstep(0.0, 0.45, _gold_reveal)
	_sprite_gold.modulate = Color(
		1.0,
		lerpf(0.72, 1.0, color_t),   # düşükte gri-sıcak, yüksekte tam gold yeşili
		lerpf(0.50, 1.0, color_t),   # düşükte koyu, yüksekte tam gold mavisi
		_gold_reveal
	)

	# Both shaders know the real hp state (cracks, glow, flash)
	_mat_iron.set_shader_parameter("hp_ratio",  hp_r)
	_mat_iron.set_shader_parameter("hit_flash", flash)
	_mat_gold.set_shader_parameter("hp_ratio",  hp_r)
	_mat_gold.set_shader_parameter("hit_flash", flash)


func _update_death_sprite() -> void:
	if _sprite_iron == null or _sprite_gold == null:
		return
	var t := clampf(1.0 - (_death_time_left / GOLD_DEATH_DURATION), 0.0, 1.0)

	if t < DEATH_FLASH_END:
		var pt := t / DEATH_FLASH_END
		# Death: hide iron, show gold at full blast
		_sprite_iron.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_sprite_gold.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_mat_gold.set_shader_parameter("hp_ratio",  0.0)
		_mat_gold.set_shader_parameter("hit_flash", lerpf(1.0, 0.0, pt * pt))
		var punch := 1.0 + sin(pt * PI) * 0.13
		var sc    := Vector2(_base_scale * _scale_var * punch,
		                     _base_scale * _scale_var * punch)
		_sprite_gold.scale = sc
	else:
		_sprite_iron.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_sprite_gold.modulate = Color(1.0, 1.0, 1.0, 0.0)


func _start_death() -> void:
	super._start_death()
	_death_time_left = GOLD_DEATH_DURATION
	queue_redraw()


func _draw() -> void:
	if _is_dying:
		_draw_death_flash()
		return
	if _is_dev_mode():
		_draw_dev_overlay()


func _draw_death_flash() -> void:
	if GOLD_DEATH_DURATION <= 0.0:
		return
	var t := clampf(1.0 - (_death_time_left / GOLD_DEATH_DURATION), 0.0, 1.0)
	if t >= DEATH_FLASH_END:
		return
	var pt     := t / DEATH_FLASH_END
	var ease_t := pt * pt
	var ring_a := lerpf(0.88, 0.0, ease_t)
	draw_arc(Vector2.ZERO, radius * lerpf(0.48, 1.85, ease_t),
		0.0, TAU, 64, Color(0.98, 0.80, 0.20, ring_a), 4.0, true)
	draw_circle(Vector2.ZERO, radius * lerpf(0.42, 0.05, ease_t),
		Color(1.00, 0.90, 0.55, ring_a * 0.82))
	draw_arc(Vector2.ZERO, radius * lerpf(0.72, 2.15, ease_t),
		0.0, TAU, 48, Color(0.90, 0.58, 0.04, ring_a * 0.32), 1.4, true)


static func _smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _spawn_energy_orbs() -> void:
	if energy_orb_scene == null:
		return
	var tree := get_tree()
	if tree == null:
		return
	var parent: Node = tree.current_scene
	if parent == null:
		parent = tree.root

	var player_node := _find_player()

	# Gold orbs: random count [energy_drop_count .. energy_drop_count+2]
	var gold_count := randi_range(energy_drop_count, energy_drop_count + 2)
	for _i in range(gold_count):
		var orb := energy_orb_scene.instantiate()
		if orb == null:
			continue
		if orb is Node2D:
			(orb as Node2D).global_position = global_position
		parent.add_child(orb)
		if orb.has_method("setup"):
			orb.call("setup", player_node, radius, &"gold")

	# Energy orbs: same as iron map 1 (energy_orb_drop_count × multiplier)
	var energy_count := energy_orb_drop_count * ENERGY_ORB_DROP_MULTIPLIER
	for _i in range(energy_count):
		var orb := energy_orb_scene.instantiate()
		if orb == null:
			continue
		if orb is Node2D:
			(orb as Node2D).global_position = global_position
		parent.add_child(orb)
		if orb.has_method("setup"):
			orb.call("setup", player_node, radius, &"energy")
