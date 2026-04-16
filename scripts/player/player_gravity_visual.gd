extends Node2D
## Mistik enerji çekirdeği — uzay parçacıkları, vorteks kolları ve enerji arkları.
## Enerji oranı arttıkça parçacık sayısı, hızı ve kaotik yoğunluğu yükselir.
## player.gd tarafından set_visual_state() ile her frame güncellenir.

const ENERGY_RADIUS: float = 10.0   # parçacık alanı yarıçapı (local space)
const INNER_R:       float = 2.8    # merkez singularity yarıçapı

# ── Parçacık sistemi ──────────────────────────────────────────────────────────
const P_COUNT:    int = 42   # maksimum orbital parçacık
const WISP_COUNT: int = 10   # maksimum vorteks kol
const ARC_COUNT:  int = 6    # maksimum enerji arkı

# ── State ─────────────────────────────────────────────────────────────────────
var _time:    float = 0.0
var _ratio:   float = 1.0   # enerji oranı 0–1 — görsel yoğunluğu yönetir
var _boosted: float = 1.0
var _tint:    Color = Color(0.88, 0.80, 1.00)

# ── Parçacık state ────────────────────────────────────────────────────────────
var _p_angle:  PackedFloat32Array
var _p_radius: PackedFloat32Array
var _p_speed:  PackedFloat32Array   # temel açısal hız — _ratio ile çarpılır
var _p_phase:  PackedFloat32Array
var _p_ecc:    PackedFloat32Array   # elips eksantrikliği
var _p_size:   PackedFloat32Array

# ── Vorteks kol state ──────────────────────────────────────────────────────────
var _w_base:  PackedFloat32Array
var _w_speed: PackedFloat32Array
var _w_phase: PackedFloat32Array
var _w_reach: PackedFloat32Array

# ── Ark state ──────────────────────────────────────────────────────────────────
var _arc_a1:   PackedFloat32Array
var _arc_a2:   PackedFloat32Array
var _arc_r1:   PackedFloat32Array
var _arc_r2:   PackedFloat32Array
var _arc_spd1: PackedFloat32Array
var _arc_spd2: PackedFloat32Array
var _arc_ph:   PackedFloat32Array


func _ready() -> void:
	_p_angle  = PackedFloat32Array(); _p_angle.resize(P_COUNT)
	_p_radius = PackedFloat32Array(); _p_radius.resize(P_COUNT)
	_p_speed  = PackedFloat32Array(); _p_speed.resize(P_COUNT)
	_p_phase  = PackedFloat32Array(); _p_phase.resize(P_COUNT)
	_p_ecc    = PackedFloat32Array(); _p_ecc.resize(P_COUNT)
	_p_size   = PackedFloat32Array(); _p_size.resize(P_COUNT)

	for i in P_COUNT:
		_p_angle[i]  = randf() * TAU
		_p_radius[i] = randf_range(1.2, ENERGY_RADIUS * 0.94)
		var r_norm: float = _p_radius[i] / ENERGY_RADIUS
		var spd: float    = randf_range(2.2, 6.0) * (1.0 - r_norm * 0.48)
		_p_speed[i]  = spd * (1.0 if randf() > 0.22 else -1.0)
		_p_phase[i]  = randf() * TAU
		_p_ecc[i]    = randf_range(0.70, 0.98)
		_p_size[i]   = randf_range(0.45, 1.65)

	_w_base  = PackedFloat32Array(); _w_base.resize(WISP_COUNT)
	_w_speed = PackedFloat32Array(); _w_speed.resize(WISP_COUNT)
	_w_phase = PackedFloat32Array(); _w_phase.resize(WISP_COUNT)
	_w_reach = PackedFloat32Array(); _w_reach.resize(WISP_COUNT)

	for i in WISP_COUNT:
		_w_base[i]  = (float(i) / float(WISP_COUNT)) * TAU
		_w_speed[i] = randf_range(0.5, 1.4) * (1.0 if i % 2 == 0 else -1.0)
		_w_phase[i] = randf() * TAU
		_w_reach[i] = randf_range(ENERGY_RADIUS * 0.38, ENERGY_RADIUS * 0.90)

	_arc_a1   = PackedFloat32Array(); _arc_a1.resize(ARC_COUNT)
	_arc_a2   = PackedFloat32Array(); _arc_a2.resize(ARC_COUNT)
	_arc_r1   = PackedFloat32Array(); _arc_r1.resize(ARC_COUNT)
	_arc_r2   = PackedFloat32Array(); _arc_r2.resize(ARC_COUNT)
	_arc_spd1 = PackedFloat32Array(); _arc_spd1.resize(ARC_COUNT)
	_arc_spd2 = PackedFloat32Array(); _arc_spd2.resize(ARC_COUNT)
	_arc_ph   = PackedFloat32Array(); _arc_ph.resize(ARC_COUNT)

	for i in ARC_COUNT:
		_arc_a1[i]   = randf() * TAU
		_arc_a2[i]   = _arc_a1[i] + PI + randf_range(-0.7, 0.7)
		_arc_r1[i]   = randf_range(ENERGY_RADIUS * 0.22, ENERGY_RADIUS * 0.78)
		_arc_r2[i]   = randf_range(ENERGY_RADIUS * 0.18, ENERGY_RADIUS * 0.72)
		_arc_spd1[i] = randf_range(0.9, 2.6) * (1.0 if i % 2 == 0 else -1.0)
		_arc_spd2[i] = randf_range(0.7, 2.1) * (-1.0 if i % 2 == 0 else 1.0)
		_arc_ph[i]   = randf() * TAU


func _process(delta: float) -> void:
	_time += delta

	# Enerji arttıkça parçacıklar hızlanır — 0.28x (boş) → 2.0x (dolu)
	var energy_mult: float = lerpf(0.28, 2.0, _ratio)

	for i in P_COUNT:
		_p_angle[i] = fmod(_p_angle[i] + _p_speed[i] * delta * energy_mult, TAU)

	# Ark fazları da enerjiyle hızlanır
	var arc_mult: float = lerpf(0.4, 1.8, _ratio)
	for i in ARC_COUNT:
		_arc_a1[i] = fmod(_arc_a1[i] + _arc_spd1[i] * delta * arc_mult, TAU)
		_arc_a2[i] = fmod(_arc_a2[i] + _arc_spd2[i] * delta * arc_mult, TAU)
		_arc_ph[i] = fmod(_arc_ph[i] + delta * (3.0 + _ratio * 4.0), TAU)

	queue_redraw()


## player.gd her frame çağırır.
func set_visual_state(ratio: float, boosted: float, tint: Color) -> void:
	_ratio   = ratio
	_boosted = boosted
	_tint    = tint


func _draw() -> void:
	var b: float = clampf(_boosted / 1.6, 0.15, 1.8)

	# Enerji oranına göre aktif parçacık/kol/ark sayısı
	var active_p:    int = int(lerpf(P_COUNT * 0.14, P_COUNT,    _ratio))
	var active_w:    int = int(lerpf(1.0,             WISP_COUNT, _ratio))
	var active_arc:  int = int(lerpf(0.0,             ARC_COUNT,  clampf(_ratio * 1.4, 0.0, 1.0)))

	_draw_energy_bg(b)
	_draw_vortex_wisps(b, active_w)
	_draw_orbital_particles(b, active_p)
	_draw_energy_arcs(b, active_arc)
	_draw_singularity(b)


# ── Katmanlar ──────────────────────────────────────────────────────────────────

func _draw_energy_bg(b: float) -> void:
	var breathe: float = sin(_time * 1.1) * 0.5
	# Void küre — enerji arttıkça hafif büyür ve daha parlak
	var bg_scale: float = 1.0 + _ratio * 0.15
	draw_circle(Vector2.ZERO, (ENERGY_RADIUS + breathe) * bg_scale,
		Color(0.04, 0.00, 0.12, b * 0.88))
	# Tint-renkli dış rim — enerji yoğunluğuyla birlikte parlar
	draw_arc(Vector2.ZERO, (ENERGY_RADIUS + breathe * 0.5) * bg_scale, 0.0, TAU, 64,
		Color(_tint.r * 0.45, _tint.g * 0.35, _tint.b * 0.65, b * (0.18 + _ratio * 0.22)), 1.4, true)


func _draw_vortex_wisps(b: float, count: int) -> void:
	# Enerji arttıkça vorteks kolları çoğalır ve daha uzun olur
	var reach_boost: float = 1.0 + _ratio * 0.30
	for i in count:
		var base_angle: float = _w_base[i] + _time * float(_w_speed[i]) * lerpf(0.5, 1.6, _ratio)
		var ph:    float = float(_w_phase[i])
		var reach: float = float(_w_reach[i]) * reach_boost

		var len_mod: float = 1.0 + sin(_time * 1.6 + ph) * 0.18
		var seg_count: int = 10
		var prev_pt: Vector2 = Vector2.ZERO

		for s in seg_count + 1:
			var t: float  = float(s) / float(seg_count)
			var curl: float = base_angle + t * 2.1 + sin(t * PI * 1.3 + ph) * 0.45
			var r: float    = t * reach * len_mod * (0.88 + sin(_time * 3.0 + ph + t * 2.5) * 0.12)
			var pt: Vector2 = Vector2(cos(curl), sin(curl)) * r

			if s > 0:
				var brightness: float = sin(t * PI) * b
				var col: Color = _tint.lerp(Color(1.0, 0.95, 1.0), t * 0.4)
				col.a = brightness * (0.10 + _ratio * 0.10 + (1.0 - t) * 0.06)
				draw_line(prev_pt, pt, col, (0.8 + (1.0 - t) * 0.5) * (1.0 - t * 0.3), true)
			prev_pt = pt


func _draw_orbital_particles(b: float, count: int) -> void:
	for i in count:
		var angle:  float = float(_p_angle[i])
		var radius: float = float(_p_radius[i])
		var ph:     float = float(_p_phase[i])
		var ecc:    float = float(_p_ecc[i])
		var sz:     float = float(_p_size[i])

		var pt: Vector2 = Vector2(cos(angle) * radius, sin(angle) * radius * ecc)

		var flicker: float = (sin(_time * 18.0 + ph) * 0.35 + 0.65) * \
							 (sin(_time * 6.7  + ph * 1.4) * 0.20 + 0.80)

		var r_norm: float = radius / ENERGY_RADIUS
		var col: Color    = Color(1.0, 0.95, 1.0).lerp(_tint, r_norm * 0.80)

		# Yüksek enerjide parçacıklar daha büyük ve kaotik
		var size_boost: float = 1.0 + _ratio * 0.45
		var final_alpha: float = flicker * b * lerpf(0.40, 1.0, _ratio)

		draw_circle(pt, sz * 2.0 * size_boost, Color(col.r, col.g, col.b, final_alpha * 0.18))
		draw_circle(pt, sz * size_boost,       Color(col.r, col.g, col.b, final_alpha * 0.88))
		if sz > 0.9:
			draw_circle(pt, sz * 0.35, Color(1.0, 1.0, 1.0, final_alpha * 0.70))


func _draw_energy_arcs(b: float, count: int) -> void:
	for i in count:
		var a1: float = float(_arc_a1[i])
		var a2: float = float(_arc_a2[i])
		var r1: float = float(_arc_r1[i])
		var r2: float = float(_arc_r2[i])
		var ph: float = float(_arc_ph[i])

		var p1: Vector2 = Vector2(cos(a1), sin(a1)) * r1
		var p2: Vector2 = Vector2(cos(a2), sin(a2)) * r2

		# Yüksek enerjide arklar daha sık çakıyor
		var flash_freq: float = 1.0 + _ratio * 3.0
		var flash: float = pow(maxf(0.0, sin(ph * flash_freq)), 4.5)
		if flash < 0.05:
			continue

		var arc_col: Color = _tint.lerp(Color(1.0, 0.95, 1.0), 0.55 + _ratio * 0.20)
		var mid: Vector2   = (p1 + p2) * 0.5
		var perp: Vector2  = (p2 - p1).orthogonal().normalized()
		var bend: float    = sin(ph * 2.1) * (1.0 + _ratio * 0.8)
		mid = mid + perp * bend

		var intensity: float = flash * b * lerpf(0.6, 1.0, _ratio)
		draw_line(p1, mid, Color(arc_col.r, arc_col.g, arc_col.b, intensity * 0.28), 1.8, true)
		draw_line(mid, p2, Color(arc_col.r, arc_col.g, arc_col.b, intensity * 0.28), 1.8, true)
		draw_line(p1, mid, Color(arc_col.r, arc_col.g, arc_col.b, intensity * 0.72), 0.5, true)
		draw_line(mid, p2, Color(arc_col.r, arc_col.g, arc_col.b, intensity * 0.72), 0.5, true)
		draw_line(p1, mid, Color(1.0, 1.0, 1.0, intensity * 0.45), 0.15, true)
		draw_line(mid, p2, Color(1.0, 1.0, 1.0, intensity * 0.45), 0.15, true)


func _draw_singularity(b: float) -> void:
	# Enerji arttıkça singularity büyür ve titreşimi artar
	var fast_pulse: float = sin(_time * (9.0 + _ratio * 6.0)) * 0.5 + 0.5
	var slow_pulse: float = sin(_time * 2.8 + 0.7) * 0.4 + 0.6
	var size_mult:  float = 1.0 + _ratio * 0.55

	if _ratio < 0.30:
		var flicker: float = sin(_time * 21.0) * 0.5 + 0.5
		fast_pulse *= lerpf(0.15, 1.0, flicker * (_ratio / 0.30))

	draw_circle(Vector2.ZERO, (INNER_R * 2.6 + fast_pulse * 0.6) * size_mult,
		Color(_tint.r * 0.7, _tint.g * 0.5, _tint.b, b * (0.22 + _ratio * 0.18) * slow_pulse))
	draw_circle(Vector2.ZERO, (INNER_R + fast_pulse * 0.35) * size_mult,
		Color(_tint.r, _tint.g * 0.85, _tint.b, b * (0.55 + _ratio * 0.25) * slow_pulse))
	draw_circle(Vector2.ZERO, (INNER_R * 0.42 + fast_pulse * 0.15) * size_mult,
		Color(1.00, 1.00, 1.00, 0.92 * b))
