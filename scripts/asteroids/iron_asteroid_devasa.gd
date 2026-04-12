extends IronAsteroid
class_name IronAsteroidDevasa

## Devasa demir asteroidi — IronAsteroid'i extend eder, boss-level görsel efektler ekler.
## Şader (iron_asteroid.gdshader) yüzey detaylarını işlemeye devam eder.
## Bu script: gezegensel halkalar, tehlike aurası ve kritik HP uyarısı çizer.

const DEVASA_DEATH_DURATION : float = 1.80


func _ready() -> void:
	super._ready()
	# Zaman aşımı devre dışı — devasa hiçbir zaman yakınlaşma sebebiyle silinmez.
	player_progress_timeout = 9999.0
	player_progress_epsilon = 0.0


func _start_death() -> void:
	super._start_death()
	# Üst sınıfın kısa süresini boss için uzat.
	_death_time_left = DEVASA_DEATH_DURATION


func _update_death_visuals() -> void:
	if _mat == null or _sprite == null:
		return
	var t := clampf(1.0 - (_death_time_left / DEVASA_DEATH_DURATION), 0.0, 1.0)

	if t < 0.10:
		var pt := t / 0.10
		_mat.set_shader_parameter("hp_ratio",  0.0)
		_mat.set_shader_parameter("hit_flash", 1.0 - pt * 0.7)
		var punch := 1.0 + sin(pt * PI) * 0.10
		_sprite.scale = Vector2.ONE * (_base_scale * _scale_var * punch)
		_sprite.modulate.a = 1.0
	elif t < 0.72:
		var pt := (t - 0.10) / 0.62
		_mat.set_shader_parameter("hp_ratio",  0.0)
		_mat.set_shader_parameter("hit_flash", 0.0)
		_sprite.scale = Vector2.ONE * (_base_scale * _scale_var * (1.0 - pt * 0.38))
		_sprite.modulate.a = clampf(1.0 - pt * 1.4, 0.0, 1.0)
	else:
		_mat.set_shader_parameter("hp_ratio",  0.0)
		_mat.set_shader_parameter("hit_flash", 0.0)
		_sprite.modulate.a = 0.0


# ── Çizim ──────────────────────────────────────────────────────────────────────

func _draw() -> void:
	if _is_dying:
		_draw_devasa_death()
		return
	if _is_dev_mode():
		_draw_dev_overlay()
	_draw_devasa_aura()


func _draw_devasa_aura() -> void:
	var pulse    := sin(_pulse_t) * 0.5 + 0.5
	var slow_p   := sin(_pulse_t * 0.32) * 0.5 + 0.5
	var hp_r     := clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 1.0

	# ── Derin uzay tehlike aurası (3 katman) ─────────────────────────────────
	draw_circle(Vector2.ZERO, radius * 2.30,
		Color(0.25, 0.30, 0.40, 0.035 + slow_p * 0.015))
	draw_circle(Vector2.ZERO, radius * 1.72,
		Color(0.30, 0.36, 0.46, 0.07 + slow_p * 0.03))
	draw_circle(Vector2.ZERO, radius * 1.30,
		Color(0.40, 0.46, 0.58, 0.12 + pulse * 0.05))

	# ── Gezegensel halkalar ──────────────────────────────────────────────────
	var ring_spin := _pulse_t * 0.13
	_draw_ring_segments(radius * 1.65, ring_spin, 16,
		Color(0.50, 0.56, 0.68, 0.30 + pulse * 0.12), 3.0)
	_draw_ring_segments(radius * 1.36, -ring_spin * 0.68, 11,
		Color(0.36, 0.42, 0.54, 0.20 + pulse * 0.08), 1.8)
	# İnce dış halka
	draw_arc(Vector2.ZERO, radius * 1.90, 0.0, TAU, 128,
		Color(0.35, 0.40, 0.52, 0.08 + slow_p * 0.05), 1.0, true)

	# ── Atmosferik sınır ─────────────────────────────────────────────────────
	draw_arc(Vector2.ZERO, radius * 1.06, 0.0, TAU, 128,
		Color(0.45, 0.52, 0.64, 0.20 + pulse * 0.08), 2.8, true)

	# ── Merkez çekirdek parıltısı ─────────────────────────────────────────────
	draw_circle(Vector2.ZERO, radius * 0.48,
		Color(0.52, 0.58, 0.70, 0.18 + pulse * 0.10))

	# ── Kritik HP — öfke halkası ──────────────────────────────────────────────
	if hp_r < 0.35:
		var warn_t   := (0.35 - hp_r) / 0.35
		var rage_p   := sin(_pulse_t * 5.8) * 0.5 + 0.5
		var warn_a   := warn_t * (0.28 + rage_p * 0.52)
		var ring_w   := 4.0 + rage_p * 3.5
		draw_arc(Vector2.ZERO, radius * 1.08, 0.0, TAU, 64,
			Color(1.0, 0.14, 0.04, warn_a), ring_w, true)
		draw_circle(Vector2.ZERO, radius * 2.50,
			Color(1.0, 0.10, 0.03, warn_t * 0.05))


func _draw_ring_segments(r: float, angle_offset: float, seg: int, col: Color, w: float) -> void:
	var gap      := PI * 0.09
	var arc_span := (TAU / float(seg)) - gap
	for i in range(seg):
		var a := angle_offset + TAU * float(i) / float(seg)
		draw_arc(Vector2.ZERO, r, a, a + arc_span, 22, col, w, true)


# ── Ölüm animasyonu ────────────────────────────────────────────────────────────

func _draw_devasa_death() -> void:
	if DEVASA_DEATH_DURATION <= 0.0:
		return
	var t := clampf(1.0 - (_death_time_left / DEVASA_DEATH_DURATION), 0.0, 1.0)

	# Faz 1: Şok dalgası (t 0 → 0.12)
	if t < 0.12:
		var pt    := t / 0.12
		var ring_r := radius * lerpf(0.85, 4.20, pt)
		var alpha  := lerpf(0.95, 0.0, pt * pt)
		draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 128,
			Color(0.88, 0.85, 0.80, alpha), lerpf(9.0, 2.0, pt), true)
		draw_circle(Vector2.ZERO, radius * lerpf(0.55, 0.10, pt),
			Color(0.96, 0.92, 0.88, alpha * 0.90))
		# İkincil şok
		draw_arc(Vector2.ZERO, ring_r * 0.62, 0.0, TAU, 64,
			Color(0.75, 0.72, 0.68, alpha * 0.55), 4.0, true)

	# Faz 2: Üç yayılan debris halkası (t 0.10 → 0.82)
	if t >= 0.10 and t < 0.82:
		var pt := (t - 0.10) / 0.72
		for ri in range(3):
			var ring_r := radius * lerpf(1.1 + ri * 0.35, 5.5 + ri * 1.0, pt)
			var alpha  := lerpf(0.55, 0.0, pt) * (1.0 - ri * 0.18)
			draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 64,
				Color(0.58, 0.56, 0.52, alpha), lerpf(2.5, 0.8, pt), true)

	# Faz 3: Yayılan kıymık parçaları (t 0.10 → son)
	if _shard_count > 0 and t >= 0.10:
		var shard_t := (t - 0.10) / 0.90
		var shard_a := clampf(1.0 - shard_t * 1.08, 0.0, 1.0)
		var elapsed := shard_t * DEVASA_DEATH_DURATION * 1.6

		for i in range(_shard_count):
			var b     := i * 6
			var vx    := _death_shards[b + 2] * 2.4
			var vy    := _death_shards[b + 3] * 2.4
			var sz    := _death_shards[b + 4] * 3.0
			var ang   := _death_shards[b + 5]
			var pos   := Vector2(vx * elapsed, vy * elapsed)
			draw_arc(pos, sz, ang - PI * 0.28, ang + PI * 0.28, 12,
				Color(0.70, 0.68, 0.62, shard_a), 3.0, true)
			if shard_a > 0.30:
				draw_circle(pos + Vector2(cos(ang), sin(ang)) * sz, 2.5,
					Color(0.90, 0.88, 0.84, shard_a * 0.65))
