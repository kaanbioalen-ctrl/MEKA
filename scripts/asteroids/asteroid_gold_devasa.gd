extends AsteroidGold
class_name AsteroidGoldDevasa

## Devasa altın asteroidi — AsteroidGold'u extend eder.
## Güneş benzeri korona, yörüngeli ışık noktaları, prizmatik halo ve altın bloom.
## İron→Gold shader geçişi tam HP düşerken açılır — boss mekaniği gibi çalışır.

const DEVASA_DEATH_DURATION : float = 2.20


func _ready() -> void:
	super._ready()
	player_progress_timeout = 9999.0
	player_progress_epsilon = 0.0


func _start_death() -> void:
	super._start_death()
	_death_time_left = DEVASA_DEATH_DURATION


func _update_death_sprite() -> void:
	if _sprite_iron == null or _sprite_gold == null:
		return
	var t := clampf(1.0 - (_death_time_left / DEVASA_DEATH_DURATION), 0.0, 1.0)

	if t < 0.06:
		var pt := t / 0.06
		_sprite_iron.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_sprite_gold.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_mat_gold.set_shader_parameter("hp_ratio",  0.0)
		_mat_gold.set_shader_parameter("hit_flash", lerpf(1.0, 0.0, pt * pt))
		var punch := 1.0 + sin(pt * PI) * 0.15
		_sprite_gold.scale = Vector2.ONE * (_base_scale * _scale_var * punch)
	else:
		_sprite_iron.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_sprite_gold.modulate = Color(1.0, 1.0, 1.0, 0.0)


# ── Çizim ──────────────────────────────────────────────────────────────────────

func _draw() -> void:
	if _is_dying:
		_draw_devasa_gold_death()
		return
	if _is_dev_mode():
		_draw_dev_overlay()
	_draw_devasa_corona()


func _draw_devasa_corona() -> void:
	var pulse    := sin(_pulse_t) * 0.5 + 0.5
	var slow_p   := sin(_pulse_t * 0.28) * 0.5 + 0.5
	var beat_p   := sin(_pulse_t * 1.80) * 0.5 + 0.5    # hafif kalp atışı ritmi
	var hp_r     := clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 1.0

	# ── Güneş benzeri mega korona (4 katman) ─────────────────────────────────
	draw_circle(Vector2.ZERO, radius * 3.20,
		Color(1.0, 0.40, 0.02, 0.030 + slow_p * 0.015))
	draw_circle(Vector2.ZERO, radius * 2.40,
		Color(1.0, 0.52, 0.04, 0.055 + slow_p * 0.025))
	draw_circle(Vector2.ZERO, radius * 1.80,
		Color(1.0, 0.65, 0.06, 0.10 + pulse * 0.05))
	draw_circle(Vector2.ZERO, radius * 1.35,
		Color(1.0, 0.78, 0.14, 0.18 + beat_p * 0.08))

	# ── Atmosferik ışıltı ────────────────────────────────────────────────────
	draw_arc(Vector2.ZERO, radius * 1.08, 0.0, TAU, 128,
		Color(1.0, 0.85, 0.28, 0.28 + pulse * 0.10), 3.5, true)

	# ── Üç yörüngeli ışık halkası (her birinde dönen parlak nokta) ───────────
	var orbit_radii     : Array[float] = [radius * 1.85, radius * 2.38, radius * 2.95]
	var orbit_speeds    : Array[float] = [0.55, 0.36, 0.22]
	var orbit_colors    : Array[Color] = [
		Color(1.0, 0.92, 0.50, 0.90),
		Color(1.0, 0.82, 0.30, 0.80),
		Color(1.0, 0.68, 0.12, 0.65),
	]
	var orbit_ring_alphas : Array[float] = [0.10, 0.07, 0.05]

	for i in range(3):
		var orb_r   : float = orbit_radii[i]
		var dot_a   : float = _pulse_t * orbit_speeds[i] + i * (TAU / 3.0)
		var dot_pos : Vector2 = Vector2(cos(dot_a), sin(dot_a)) * orb_r
		var dot_r   : float = 5.0 + i * 1.5
		var orb_col : Color = orbit_colors[i]

		# Yörünge halkası
		draw_arc(Vector2.ZERO, orb_r, 0.0, TAU, 128,
			Color(1.0, 0.80, 0.22, orbit_ring_alphas[i] + pulse * 0.03), 1.2, true)

		# Parlak nokta + halo
		draw_circle(dot_pos, dot_r * 2.2,
			Color(1.0, 0.82, 0.32, 0.22 + pulse * 0.12))
		draw_circle(dot_pos, dot_r, orb_col)
		# İz (yarım yörünge arka tarafı)
		var trail_start : float = dot_a - PI * 0.55
		draw_arc(Vector2.ZERO, orb_r, trail_start, dot_a, 32,
			Color(orb_col.r, orb_col.g, orb_col.b,
				orb_col.a * (0.20 + pulse * 0.08)), 1.4, true)

	# ── Prizmatik dış halo (renk açıya göre kayar) ───────────────────────────
	var prism_seg := 36
	for i in range(prism_seg):
		var a0  := TAU * float(i)       / float(prism_seg)
		var a1  := TAU * float(i + 1)   / float(prism_seg)
		var hue := fmod(float(i) / float(prism_seg) + _pulse_t * 0.04, 1.0)
		draw_arc(Vector2.ZERO, radius * 2.88, a0, a1, 4,
			Color.from_hsv(hue, 0.70, 1.0, 0.06 + slow_p * 0.03), 2.0, true)

	# ── Parlayan altın çekirdek ───────────────────────────────────────────────
	draw_circle(Vector2.ZERO, radius * 0.40,
		Color(1.0, 0.96, 0.70, 0.55 + beat_p * 0.22))
	draw_circle(Vector2.ZERO, radius * 0.22,
		Color(1.0, 0.99, 0.92, 0.80 + beat_p * 0.18))

	# ── Kritik HP — karmaşık dönüşüm sinyali ─────────────────────────────────
	if hp_r < 0.30:
		var crit_t  := (0.30 - hp_r) / 0.30
		var crit_p  := sin(_pulse_t * 6.5) * 0.5 + 0.5
		# Turuncu kriz halkası
		draw_arc(Vector2.ZERO, radius * 1.10, 0.0, TAU, 64,
			Color(1.0, 0.35, 0.02, crit_t * (0.35 + crit_p * 0.50)),
			5.0 + crit_p * 4.0, true)
		# Genişleyen tehlike dairesel dalgası
		draw_circle(Vector2.ZERO, radius * 3.50,
			Color(1.0, 0.28, 0.02, crit_t * 0.06))


# ── Ölüm animasyonu ────────────────────────────────────────────────────────────

func _draw_devasa_gold_death() -> void:
	if DEVASA_DEATH_DURATION <= 0.0:
		return
	var t := clampf(1.0 - (_death_time_left / DEVASA_DEATH_DURATION), 0.0, 1.0)

	# Faz 1: Altın nükleer flaş (t 0 → 0.08)
	if t < 0.08:
		var pt    := t / 0.08
		var ease  := pt * pt
		var ring_r := radius * lerpf(0.5, 5.0, pt)
		var alpha  := lerpf(0.98, 0.0, ease)
		draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 128,
			Color(1.0, 0.85, 0.25, alpha), lerpf(12.0, 2.5, pt), true)
		draw_circle(Vector2.ZERO, radius * lerpf(0.60, 0.05, pt),
			Color(1.0, 0.96, 0.65, alpha))
		# İkincil altın halka
		draw_arc(Vector2.ZERO, ring_r * 0.58, 0.0, TAU, 64,
			Color(1.0, 0.60, 0.04, alpha * 0.55), 6.0, true)

	# Faz 2: Üç altın shockwave halkası (t 0.06 → 0.85)
	if t >= 0.06 and t < 0.85:
		var pt := (t - 0.06) / 0.79
		for ri in range(3):
			var ring_r := radius * lerpf(1.2 + ri * 0.4, 6.5 + ri * 1.2, pt)
			var alpha  := lerpf(0.70, 0.0, pt) * (1.0 - ri * 0.20)
			var hue    := 0.12 - ri * 0.025   # altın sarısından turuncuya
			draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 64,
				Color.from_hsv(hue, 0.88, 1.0, alpha), lerpf(3.0, 0.8, pt), true)

	# Faz 3: Yayılan altın kıvılcımları (t 0.06 → son)
	if t >= 0.06:
		var spark_t := (t - 0.06) / 0.94
		var spark_a := clampf(1.0 - spark_t * 1.05, 0.0, 1.0)
		var elapsed := spark_t * DEVASA_DEATH_DURATION * 1.5

		# 12 altın kıvılcım yayılır
		var spark_count := 12
		for i in range(spark_count):
			var angle := TAU * float(i) / float(spark_count) + spark_t * 0.5
			var spd   := radius * 2.8 + sin(float(i) * 1.7) * radius * 0.8
			var pos   := Vector2(cos(angle), sin(angle)) * spd * elapsed
			var sz    := (4.0 + sin(float(i) * 2.3) * 2.5) * (1.0 + spark_t * 0.4)
			draw_circle(pos, sz * 1.6, Color(1.0, 0.75, 0.20, spark_a * 0.35))
			draw_circle(pos, sz,       Color(1.0, 0.92, 0.50, spark_a))

	# Faz 4: Büyük altın enerji dalgaları (t 0.10 → son)
	if t >= 0.10:
		var wave_t := (t - 0.10) / 0.90
		for wi in range(2):
			var wt    := clampf(wave_t - wi * 0.15, 0.0, 1.0)
			var wave_r := radius * lerpf(0.8, 8.0 + wi, wt)
			var alpha  := lerpf(0.40, 0.0, wt * wt) * (1.0 - wi * 0.3)
			if alpha > 0.01:
				draw_arc(Vector2.ZERO, wave_r, 0.0, TAU, 64,
					Color(1.0, 0.88, 0.35, alpha), lerpf(4.0, 0.6, wt), true)
