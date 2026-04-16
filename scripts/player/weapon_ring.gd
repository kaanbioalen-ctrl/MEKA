extends Node2D
## Silah halkası — oyuncunun 5px dışında oturan, 3px genişliğinde sıvı/nano-biyoteknolojik halka.
## Aktif silah tipine göre morph eder.  player.gd tarafından visual_root'a eklenir.

# ── Sabitler ───────────────────────────────────────────────────────────────────
const RING_RADIUS: float = 32.0   # 12px çarpışma + 20px boşluk
const RING_WIDTH:  float = 10.0
const SEGMENTS:    int   = 64     # çember için örnekleme noktası sayısı

enum WeaponType { NONE = 0, LASER = 1, BULLET = 2, ROCKET = 3 }

# ── Durum ──────────────────────────────────────────────────────────────────────
var _time:           float = 0.0
var _weapon_type:    int   = WeaponType.NONE
var _prev_type:      int   = WeaponType.NONE
var _morph_t:        float = 1.0   # 0=eski form, 1=yeni form
var _cooldown_ratio: float = 0.0   # 0=hazır, 1=soğuyor — cooldown arc için
var _flash_t:        float = -1.0  # ateş flash geri sayımı (0.0 → -1.0 arası azalır)
var _flash_dir:      Vector2 = Vector2.RIGHT
var _aim_dir:        Vector2 = Vector2.RIGHT  # attack_controller her frame günceller
var _bullet_angle:   float   = 0.0  # bullet chamber bump'larının dönüş açısı


func _process(delta: float) -> void:
	_time += delta
	# Morph lerp
	if _morph_t < 1.0:
		_morph_t = minf(1.0, _morph_t + delta * 2.5)
	# Flash geri sayım
	if _flash_t >= 0.0:
		_flash_t = maxf(-1.0, _flash_t - delta * 4.0)
	# Bullet bump rotasyonu
	_bullet_angle += delta * 0.5
	queue_redraw()


# ── Public API ─────────────────────────────────────────────────────────────────

func set_weapon_type(new_type: int) -> void:
	if new_type == _weapon_type:
		return
	_prev_type   = _weapon_type
	_weapon_type = new_type
	_morph_t     = 0.0


func notify_fired(direction: Vector2) -> void:
	_flash_dir = direction.normalized()
	_flash_t   = 1.0


func set_cooldown_ratio(ratio: float) -> void:
	_cooldown_ratio = clampf(ratio, 0.0, 1.0)


func set_aim_direction(dir: Vector2) -> void:
	_aim_dir = dir.normalized() if dir.length_squared() > 0.001 else Vector2.RIGHT


# ── Draw ───────────────────────────────────────────────────────────────────────

func _draw() -> void:
	_draw_base_ring()
	_draw_weapon_overlay()
	if _flash_t >= 0.0:
		_draw_fire_flash()


func _draw_base_ring() -> void:
	# Sıvı wobble — 64 noktalı polygon olarak çiz
	var outer_pts: PackedVector2Array = PackedVector2Array()
	var inner_pts: PackedVector2Array = PackedVector2Array()
	outer_pts.resize(SEGMENTS)
	inner_pts.resize(SEGMENTS)

	var base_col := _get_base_color()
	var half_w   := RING_WIDTH * 0.5

	for i in SEGMENTS:
		var angle := (float(i) / float(SEGMENTS)) * TAU
		# İki sin terimi ile organik FBM benzeri dalga
		var wobble := sin(_time * 2.1 + angle * 3.0) * 0.5 + sin(_time * 3.7 + angle * 7.0) * 0.25
		wobble     *= 0.55  # toplam ±0.55px
		var r_out  := RING_RADIUS + half_w + wobble
		var r_in   := RING_RADIUS - half_w + wobble
		outer_pts[i] = Vector2(cos(angle) * r_out, sin(angle) * r_out)
		inner_pts[i] = Vector2(cos(angle) * r_in,  sin(angle) * r_in)

	# Halka polygonu (outer CCW + inner CW)
	var pts: PackedVector2Array = PackedVector2Array()
	pts.append_array(outer_pts)
	# inner'ı ters sırayla ekle → kapalı şerit
	for i in range(SEGMENTS - 1, -1, -1):
		pts.append(inner_pts[i])

	draw_colored_polygon(pts, base_col)

	# Cooldown arc: soğuma sırasında halkanın bir kısmı karanlık
	if _cooldown_ratio > 0.01:
		var arc_end := -PI * 0.5 + _cooldown_ratio * TAU  # saat 12'den başlar
		draw_arc(
			Vector2.ZERO,
			RING_RADIUS,
			-PI * 0.5,
			arc_end,
			max(4, int(_cooldown_ratio * SEGMENTS)),
			Color(0.05, 0.05, 0.1, 0.72),
			RING_WIDTH + 1.0,
			true
		)


func _draw_weapon_overlay() -> void:
	if _morph_t < 1.0:
		_draw_form(_prev_type, 1.0 - _morph_t)
	_draw_form(_weapon_type, _morph_t)


func _draw_form(wtype: int, alpha: float) -> void:
	match wtype:
		WeaponType.LASER:
			_draw_laser_form(alpha)
		WeaponType.BULLET:
			_draw_bullet_form(alpha)
		WeaponType.ROCKET:
			_draw_rocket_form(alpha)


# ── Lazer formu — 6 radyal spike + hafif glow ─────────────────────────────────

func _draw_laser_form(alpha: float) -> void:
	var aim_angle := _aim_dir.angle()
	var spike_col := Color(0.48, 0.68, 1.00, alpha * 0.9)
	var glow_col  := Color(0.48, 0.68, 1.00, alpha * 0.12)

	# Glow layer
	draw_arc(Vector2.ZERO, RING_RADIUS + 2.0, 0.0, TAU, 48, glow_col, 7.0, true)

	# 6 radyal spike — 60°'de bir, mouse tarafındaki daha uzun
	for i in 6:
		var angle    := aim_angle + (float(i) / 6.0) * TAU
		var is_front := i == 0
		var length   := 7.0 if is_front else 4.0
		var width    := 1.0 if is_front else 0.7
		var r_start  := RING_RADIUS + RING_WIDTH * 0.5
		var start    := Vector2(cos(angle), sin(angle)) * r_start
		var end_pt   := Vector2(cos(angle), sin(angle)) * (r_start + length)
		# İnce üçgen
		var perp  := Vector2(-sin(angle), cos(angle)) * width
		var tri   := PackedVector2Array([start - perp, end_pt, start + perp])
		draw_colored_polygon(tri, spike_col)


# ── Bullet formu — 3 chamber bump + revolver arc ──────────────────────────────

func _draw_bullet_form(alpha: float) -> void:
	var amber := Color(1.00, 0.82, 0.18, alpha * 0.9)
	var dim   := Color(0.30, 0.22, 0.04, alpha * 0.7)

	# 3 arc segment aralarında küçük boşlukla
	for i in 3:
		var seg_start := _bullet_angle + (float(i) / 3.0) * TAU
		var seg_end   := seg_start + (TAU / 3.0) - 0.25  # 0.25 rad boşluk
		draw_arc(Vector2.ZERO, RING_RADIUS, seg_start, seg_end, 20, amber, RING_WIDTH + 0.5, true)
		draw_arc(Vector2.ZERO, RING_RADIUS, seg_end,   seg_end + 0.25, 3, dim, RING_WIDTH * 0.6, true)

	# Chamber bump'lar — 120°'de küçük dolu circle
	for i in 3:
		var angle   := _bullet_angle + (float(i) / 3.0) * TAU + (TAU / 6.0)
		var bump_r  := RING_RADIUS + RING_WIDTH + 1.5
		var bump_pt := Vector2(cos(angle), sin(angle)) * bump_r
		draw_circle(bump_pt, 2.5, amber)
		draw_circle(bump_pt, 4.0, Color(amber.r, amber.g, amber.b, alpha * 0.25))


# ── Roket formu — kanat arc'ları + V-çentik + exhaust ────────────────────────

func _draw_rocket_form(alpha: float) -> void:
	var aim_angle  := _aim_dir.angle()
	var hot_col    := Color(1.00, 0.28, 0.12, alpha * 0.9)
	var fin_col    := Color(1.00, 0.50, 0.20, alpha * 0.8)
	var exhaust_a  := (sin(_time * 22.0) * 0.5 + 0.5) * alpha * 0.25

	# Ana halka (roket renginde)
	draw_arc(Vector2.ZERO, RING_RADIUS, aim_angle + deg_to_rad(12), aim_angle + TAU - deg_to_rad(12),
		SEGMENTS - 4, hot_col, RING_WIDTH, true)

	# Mouse yönünde V-çentik (3px boşluk yerine koyu arc)
	draw_arc(Vector2.ZERO, RING_RADIUS, aim_angle - deg_to_rad(10), aim_angle + deg_to_rad(10),
		4, Color(0.05, 0.02, 0.01, alpha * 0.9), RING_WIDTH + 1.0, true)

	# Kanat arc'ları — ±70°
	for side in [-1, 1]:
		var fin_angle := aim_angle + deg_to_rad(70.0 * side)
		var fa_start  := fin_angle - deg_to_rad(12)
		var fa_end    := fin_angle + deg_to_rad(12)
		draw_arc(Vector2.ZERO, RING_RADIUS + 4.0, fa_start, fa_end, 6, fin_col, 2.5, true)

	# Motor exhaust — arka kutupta titrişim
	var exhaust_pt := Vector2(cos(aim_angle + PI), sin(aim_angle + PI)) * (RING_RADIUS + 3.0)
	draw_circle(exhaust_pt, 3.5, Color(1.0, 0.6, 0.1, exhaust_a))

	# Ateş öncesi nabız (cooldown_ratio yüksekken daha parlak)
	if _cooldown_ratio > 0.6:
		var pulse_a := (_cooldown_ratio - 0.6) / 0.4
		pulse_a    *= (sin(_time * 16.0) * 0.5 + 0.5)
		draw_arc(Vector2.ZERO, RING_RADIUS + 1.0, 0.0, TAU, 32,
			Color(1.0, 0.4, 0.1, alpha * pulse_a * 0.5), 2.0, true)


# ── Fire flash ─────────────────────────────────────────────────────────────────

func _draw_fire_flash() -> void:
	var a         := _flash_t  # 1.0 → 0.0
	var flash_col := _get_flash_color().lightened(0.3)
	flash_col.a   = a * 0.8
	var angle     := _flash_dir.angle()
	draw_arc(Vector2.ZERO, RING_RADIUS + 6.0,
		angle - 0.4, angle + 0.4,
		8, flash_col, 4.0, true)
	# Dış glow
	flash_col.a = a * 0.3
	draw_arc(Vector2.ZERO, RING_RADIUS + 10.0,
		angle - 0.6, angle + 0.6,
		6, flash_col, 3.0, true)


# ── Renk yardımcıları ──────────────────────────────────────────────────────────

func _get_base_color() -> Color:
	match _weapon_type:
		WeaponType.LASER:
			return Color(0.48, 0.68, 1.00, 0.85)
		WeaponType.BULLET:
			return Color(1.00, 0.82, 0.18, 0.85)
		WeaponType.ROCKET:
			return Color(1.00, 0.28, 0.12, 0.85)
		_:
			return Color(0.62, 0.46, 1.00, 0.55)


func _get_flash_color() -> Color:
	match _weapon_type:
		WeaponType.LASER:
			return Color(0.48, 0.68, 1.00)
		WeaponType.BULLET:
			return Color(1.00, 0.82, 0.18)
		WeaponType.ROCKET:
			return Color(1.00, 0.40, 0.10)
		_:
			return Color(0.8, 0.8, 1.0)
