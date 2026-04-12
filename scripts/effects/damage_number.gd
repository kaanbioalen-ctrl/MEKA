extends Node2D

# ── Zaman sabitleri ────────────────────────────────────────────────────────────
const LIFETIME_NORMAL : float = 0.80
const LIFETIME_CRIT   : float = 1.05

const FLOAT_SPEED     : float = 52.0
const DRIFT_RANGE     : float = 18.0

# ── Crit bounce eğrisi (keyframe tabanlı) ─────────────────────────────────────
# t=0.00 → scale 1.55  (spawn punch)
# t=0.18 → scale 0.88  (overshoot aşağı)
# t=0.32 → scale 1.12  (bounce geri)
# t=0.45 → scale 1.00  (settle)
const BOUNCE_KEYS : Array = [
	[0.00, 1.22],
	[0.18, 0.92],
	[0.32, 1.06],
	[0.45, 1.00],
]

var _text      : String = ""
var _is_crit   : bool   = false
var _font_size : int    = 22
var _lifetime  : float  = LIFETIME_NORMAL
var _time_left : float  = LIFETIME_NORMAL
var _drift     : float  = 0.0

# Crit glow pulse: 0.0→1.0→0.0 kısa bir nabız
var _glow_pulse : float = 0.0


func setup(amount: float, is_crit: bool) -> void:
	_text    = str(int(amount))
	_is_crit = is_crit
	_drift   = randf_range(-DRIFT_RANGE, DRIFT_RANGE)

	if is_crit:
		_font_size  = 14
		_lifetime   = LIFETIME_CRIT
		_glow_pulse = 1.0
	else:
		_font_size = 11
		_lifetime  = LIFETIME_NORMAL

	_time_left = _lifetime


func _process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()
		return

	var t : float = 1.0 - (_time_left / _lifetime)  # 0→1 ilerliyor

	position.y -= FLOAT_SPEED * delta * _float_curve(t)
	position.x += _drift * delta * (1.0 - t)

	# Glow pulse çabuk söner (0.3s içinde)
	_glow_pulse = maxf(0.0, _glow_pulse - delta * 3.8)

	queue_redraw()


# Float hızı: başta hızlı çıkar, sonda yavaşlar
func _float_curve(t: float) -> float:
	return 1.0 - t * t * 0.6


func _draw() -> void:
	var font  : Font  = ThemeDB.fallback_font
	var t_age : float = 1.0 - (_time_left / _lifetime)  # 0→1

	# Alpha: son %30'da solar
	var fade_start : float = 0.70
	var alpha : float = 1.0
	if t_age > fade_start:
		alpha = 1.0 - ((t_age - fade_start) / (1.0 - fade_start))
	alpha = clampf(alpha, 0.0, 1.0)

	if _is_crit:
		_draw_crit(font, t_age, alpha)
	else:
		_draw_normal(font, alpha)


# ── Normal ─────────────────────────────────────────────────────────────────────
func _draw_normal(font: Font, alpha: float) -> void:
	var col := Color(1.0, 1.0, 1.0, alpha)
	draw_string(font, Vector2.ZERO, _text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, _font_size, col)


# ── Kritik ─────────────────────────────────────────────────────────────────────
func _draw_crit(font: Font, t_age: float, alpha: float) -> void:
	var bounce : float = _eval_bounce(t_age)
	var fs     : int   = int(float(_font_size) * bounce)
	fs = maxi(fs, 8)

	# ── 4 katmanlı glow (büyükten küçüğe, soluk → parlak) ──────────────────
	# Her katman biraz daha büyük font + düşük alpha → ucuz bloom efekti
	var glow_base : float = _glow_pulse * alpha

	# Glow: aynı font boyutunda, küçük offset'lerle çizilir.
	# Font büyümez → yazı kalınlaşmaz, sadece etrafı parlar.
	var offsets : Array[Vector2] = [
		Vector2( 2,  0), Vector2(-2,  0),
		Vector2( 0,  2), Vector2( 0, -2),
		Vector2( 1,  1), Vector2(-1,  1),
		Vector2( 1, -1), Vector2(-1, -1),
	]

	# Dış hale — hafif mavi-beyaz
	var outer_col : Color = Color(0.80, 0.92, 1.0, glow_base * 0.12)
	for o in offsets:
		draw_string(font, o * 2.0, _text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, fs, outer_col)

	# İç hale — saf beyaz
	var inner_col : Color = Color(1.0, 1.0, 1.0, glow_base * 0.22)
	for o in offsets:
		draw_string(font, o, _text,
			HORIZONTAL_ALIGNMENT_CENTER, -1, fs, inner_col)

	# Core — tam neon beyaz, net ve ince
	var core_col : Color = Color(1.0, 1.0, 1.0, alpha)
	draw_string(font, Vector2.ZERO, _text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, fs, core_col)


# ── Bounce eğrisi (keyframe lerp) ─────────────────────────────────────────────
func _eval_bounce(t: float) -> float:
	# t: 0→1 (hayat boyunca normalize)
	# Bounce sadece ilk yarıda aktif, sonrası 1.0 sabit
	var bounce_end : float = 0.45
	if t >= bounce_end:
		return 1.0

	var keys : Array = BOUNCE_KEYS
	for i in range(keys.size() - 1):
		var t0 : float = keys[i][0]
		var t1 : float = keys[i + 1][0]
		if t >= t0 and t < t1:
			var local_t : float = (t - t0) / (t1 - t0)
			# Smooth cubic interpolation
			local_t = local_t * local_t * (3.0 - 2.0 * local_t)
			return lerpf(keys[i][1], keys[i + 1][1], local_t)

	return 1.0
