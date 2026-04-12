class_name BlackHoleVortexLayer
extends Node2D

# ─── Sabitler ────────────────────────────────────────────────────────────────
const DISK_RINGS:     int = 5
const DISK_SEGMENTS:  int = 64
const PARTICLE_COUNT: int = 80

## Akkresyon diski renk paleti (iç → dış)
const DISK_COLORS: Array[Color] = [
	Color(1.00, 0.97, 0.80, 0.80),  ## Beyaz-sarı (en sıcak, iç)
	Color(1.00, 0.85, 0.40, 0.70),  ## Sarı
	Color(1.00, 0.55, 0.10, 0.60),  ## Turuncu
	Color(0.90, 0.25, 0.05, 0.45),  ## Kırmızı-turuncu
	Color(0.60, 0.05, 0.02, 0.25),  ## Koyu kırmızı (en soğuk, dış)
]

const PARTICLE_COLORS: Array[Color] = [
	Color(1.00, 0.95, 0.60),
	Color(1.00, 0.60, 0.15),
	Color(0.95, 0.25, 0.05),
]

# ─── Durum ───────────────────────────────────────────────────────────────────
var _radius:   float = 46.0
var _level_t:  float = 0.0
var _bar_t:    float = 0.0
var _time:     float = 0.0
var _particles: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

# ─── Yaşam Döngüsü ───────────────────────────────────────────────────────────
func _ready() -> void:
	_rng.randomize()
	_init_particles()


func _draw() -> void:
	_draw_outer_purple_rings()
	_draw_accretion_disk()
	_draw_particles()
	_draw_photon_ring()
	_draw_event_horizon()
	_draw_interaction_hint()

# ─── Public API ──────────────────────────────────────────────────────────────
func set_radius(r: float) -> void:
	_radius = r
	_init_particles()
	queue_redraw()


func tick(delta: float, radius: float, level_t: float, bar_t: float) -> void:
	_time   += delta
	_level_t = level_t
	_bar_t   = bar_t
	if absf(radius - _radius) > 0.5:
		_radius = radius
		_init_particles()
	_update_particles(delta)
	queue_redraw()

# ─── Parçacıklar ─────────────────────────────────────────────────────────────
func _init_particles() -> void:
	_particles.clear()
	for _i in PARTICLE_COUNT:
		_particles.append(_make_particle())


func _make_particle() -> Dictionary:
	var inner := _radius * 0.50
	var outer := _radius * 1.30
	var dist  := sqrt(_rng.randf()) * (outer - inner) + inner
	var prox  := 1.0 - clampf((dist - inner) / (outer - inner), 0.0, 1.0)
	return {
		"angle":    _rng.randf_range(0.0, TAU),
		"dist":     dist,
		"speed":    _rng.randf_range(0.5, 1.4) * (1.0 + 2.5 * prox),
		"size":     _rng.randf_range(1.0, 3.2),
		"alpha_t":  _rng.randf_range(0.0, TAU),
		"alpha_sp": _rng.randf_range(1.5, 4.5),
		"color_i":  _rng.randi() % PARTICLE_COLORS.size(),
	}


func _update_particles(delta: float) -> void:
	for p in _particles:
		p["angle"]   = fmod(p["angle"] + p["speed"] * delta * 1.9, TAU)
		p["alpha_t"] += p["alpha_sp"] * delta

# ─── Çizim ───────────────────────────────────────────────────────────────────
func _draw_event_horizon() -> void:
	## Olay ufku: gerçek siyah daire
	draw_circle(Vector2.ZERO, _radius * 0.38, Color(0.0, 0.0, 0.0, 1.0))


func _draw_photon_ring() -> void:
	## Foton halkası: beyaz-mavi, nefes gibi titreyen
	var r    := _radius * 0.40
	var glow := 0.85 + 0.15 * sin(_time * 3.2)
	for i in 4:
		var t     := float(i) / 4.0
		var width := lerpf(6.0, 1.0, t)
		var alpha := lerpf(0.90, 0.12, t) * glow
		draw_arc(Vector2.ZERO, r + t * 7.0, 0.0, TAU, 64,
			Color(1.0, 0.95, 0.85, alpha), width)


func _draw_accretion_disk() -> void:
	## Dönen renkli disk halkaları
	var inner := _radius * 0.42
	var outer := _radius * 1.08
	var step  := (outer - inner) / float(DISK_RINGS)
	for i in DISK_RINGS:
		var t      := float(i) / float(DISK_RINGS - 1)
		var r      := inner + i * step
		var rot    := _time * lerpf(1.8, 0.6, t)
		var col    := DISK_COLORS[i]
		col.a     *= lerpf(1.0, 0.5, t)
		var width  := lerpf(7.0, 2.0, t)
		draw_arc(Vector2.ZERO, r, rot, rot + TAU * 0.94, DISK_SEGMENTS, col, width)


func _draw_particles() -> void:
	for p in _particles:
		var pos   := Vector2(cos(p["angle"]), sin(p["angle"])) * float(p["dist"])
		var alpha := 0.45 + 0.40 * sin(float(p["alpha_t"]))
		var fade  := clampf((float(p["dist"]) - _radius * 0.40) / (_radius * 0.28), 0.0, 1.0)
		alpha    *= fade
		var col: Color = PARTICLE_COLORS[int(p["color_i"])]
		col       = Color(col.r, col.g, col.b, alpha)
		draw_circle(pos, float(p["size"]), col)


func _draw_outer_purple_rings() -> void:
	## Dış mor/eflatun ışıma halkası
	var base_alpha := 0.05 + 0.025 * _level_t + 0.01 * sin(_time * 0.8)
	for i in 4:
		var t      := float(i) / 3.0
		var r      := _radius * (1.22 + t * 0.26)
		var alpha  := base_alpha * (1.0 - t * 0.65)
		var pulse  := 0.012 * sin(_time * 1.1 + i * 0.8)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 64,
			Color(0.60, 0.05, 1.0, alpha + pulse), lerpf(4.5, 1.5, t))


func _draw_interaction_hint() -> void:
	## Oyuncu etkileşim alanında olduğunda titreyen halka göster
	var parent := get_parent()
	if parent == null or not parent.has_method("is_player_in_interaction_zone"):
		return
	if not bool(parent.call("is_player_in_interaction_zone")):
		return
	var r     := maxf(_radius * 0.18, 55.0)
	var alpha := 0.18 + 0.10 * sin(_time * 7.0)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.4, 1.0, 1.0, alpha), 2.0)
	draw_circle(Vector2.ZERO, 5.0,
		Color(0.4, 1.0, 1.0, 0.55 + 0.35 * sin(_time * 9.0)))
