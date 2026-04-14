extends Node2D
## Biyolojik hücre zarı — canlı silia sistemi.
## Metakronal dalga + asimetrik vuruş + nefes + piyano tepkisi + kümeleme + lazer.

const _CLUSTER_LASER_SCRIPT = preload("res://scripts/weapons/cluster_laser.gd")
const UpgradeEffects = preload("res://scripts/upgrades/upgrade_effects.gd")
const WORLD_TEST_SCENE_PATH: String = "res://scenes/world/world_test.tscn"

# ── Membran ────────────────────────────────────────────────────────────────────
const MEMBRANE_RADIUS:   float = 20.0
const MEMBRANE_SEGMENTS: int   = 80

# ── Diken ──────────────────────────────────────────────────────────────────────
const SPINE_COUNT:    int   = 60
const SPINE_LEN_BASE: float = 5.5
const SPINE_LEN_VAR:  float = 2.5
const SPINE_WIDTH:    float = 0.65

# ── Hareket — metakronal silia dinamiği ───────────────────────────────────────
const WAVE_FREQ:      float = 2.6    # temel vuruş frekansı (Hz)
const METACHRONAL_K:  float = 3.8    # seyahat eden dalga — faz / tam tur (radyan)
const WAVE_LAT:       float = 1.15   # yanal salınım genliği
const IDLE_RADIAL:    float = 0.45   # radyal nabız genliği
const BEND_SPEED:     float = 5.0    # hız yanıtı katsayısı
const FLUTTER_FREQ:   float = 16.0   # uç titremi frekansı
const FLUTTER_AMP:    float = 0.20   # uç titremi genliği
const CURVE_MID:      float = 0.38   # orta nokta yanal eğri katsayısı

# ── Global modülatörler ────────────────────────────────────────────────────────
const BREATHE_FREQ:   float = 0.30   # nefes frekansı (Hz)
const BREATHE_AMP:    float = 1.30   # membran nefes genliği (px)
const ENERGY_FREQ:    float = 0.09   # enerji ebb/flow (Hz)
# energy = 0.6 + 0.4 * sin(t * ENERGY_FREQ * TAU) → vuruş canlılığı kabarıp azalır

# ── Grup çekilmesi ─────────────────────────────────────────────────────────────
const RETRACT_GROUP_COUNT: int   = 3
const RETRACT_GROUP_SIZE:  int   = 5
const RETRACT_CYCLE:       float = 3.2
const RETRACT_DUR:         float = 0.55
const HIDDEN_DUR:          float = 0.25
const EXTEND_DUR:          float = 0.65

# ── Piyano tepkisi ─────────────────────────────────────────────────────────────
const REPULSE_RANGE:    int   = 9
const REPULSE_STRENGTH: float = 2.6

# ── Kümeleme ───────────────────────────────────────────────────────────────────
const CLUSTER_INTERVAL:    float = 5.0
const CLUSTER_SIZE_MIN:    int   = 5
const CLUSTER_SIZE_MAX:    int   = 6
const CLUSTER_FORM_DUR:    float = 6.60
const CLUSTER_HOLD_DUR:    float = 2.00
const CLUSTER_RELEASE_DUR: float = 2.40
const CLUSTER_TIP_REACH:   float = 1.20
const MAX_CLUSTERS:        int   = 3

# ── Renk ──────────────────────────────────────────────────────────────────────
const COLOR:         Color = Color(0.18, 0.06, 0.24, 0.86)
const COLOR_DARK:    Color = Color(0.03, 0.01, 0.07, 0.96)
const COLOR_HILITE:  Color = Color(0.34, 0.18, 0.42, 0.72)
const COLOR_CLUSTER: Color = Color(0.00, 1.00, 0.00, 0.92)

# ── Precomputed ────────────────────────────────────────────────────────────────
var _spine_len:    PackedFloat32Array
var _spine_phase:  PackedFloat32Array   # metakronal faz ofseti (her dikenin kendi renk/uzunluk tonu)
var _spine_lat_ph: PackedFloat32Array   # ikincil yanal faz
var _spine_angle:  PackedFloat32Array

# ── Küme ──────────────────────────────────────────────────────────────────────
var _clusters:           Array = []
var _cluster_timer:      float = 2.5
var _spine_cluster_t:    PackedFloat32Array
var _spine_cluster_conv: Array

# ── Çekilme ───────────────────────────────────────────────────────────────────
var _retract_groups:  Array = []
var _spine_retract_t: PackedFloat32Array
var _spine_push:      PackedFloat32Array

var _time:       float   = 0.0
var _player_vel: Vector2 = Vector2.ZERO
var _speed:      float   = 0.0


func _ready() -> void:
	_spine_len          = PackedFloat32Array()
	_spine_phase        = PackedFloat32Array()
	_spine_lat_ph       = PackedFloat32Array()
	_spine_angle        = PackedFloat32Array()
	_spine_cluster_t    = PackedFloat32Array()
	_spine_cluster_conv = []
	_spine_retract_t    = PackedFloat32Array()
	_spine_push         = PackedFloat32Array()

	_spine_len.resize(SPINE_COUNT)
	_spine_phase.resize(SPINE_COUNT)
	_spine_lat_ph.resize(SPINE_COUNT)
	_spine_angle.resize(SPINE_COUNT)
	_spine_cluster_t.resize(SPINE_COUNT)
	# Array'i Vector2.ZERO ile doldur — null erişimi engeller
	for _si in SPINE_COUNT:
		_spine_cluster_conv.append(Vector2.ZERO)
	_spine_retract_t.resize(SPINE_COUNT)
	_spine_push.resize(SPINE_COUNT)

	for i in SPINE_COUNT:
		var smooth: float = (
			sin(float(i) * 0.37) * 0.5 +
			sin(float(i) * 0.91) * 0.3 +
			sin(float(i) * 2.13) * 0.2
		)
		_spine_len[i]       = SPINE_LEN_BASE + smooth * SPINE_LEN_VAR
		_spine_phase[i]     = randf() * TAU
		_spine_lat_ph[i]    = randf() * TAU
		var even: float     = (float(i) / float(SPINE_COUNT)) * TAU
		_spine_angle[i]     = even + randf_range(-0.3, 0.3) * (TAU / float(SPINE_COUNT))
		_spine_cluster_t[i]    = 0.0
		_spine_cluster_conv[i] = Vector2.ZERO
		_spine_retract_t[i]    = 0.0
		_spine_push[i]         = 0.0

	# Çekilme grupları — eşit aralıklı, kademeli faz
	var phase_step: float = RETRACT_CYCLE / float(RETRACT_GROUP_COUNT)
	for g in RETRACT_GROUP_COUNT:
		var start: int = int(float(g) / float(RETRACT_GROUP_COUNT) * float(SPINE_COUNT))
		var indices: Array = []
		for j in RETRACT_GROUP_SIZE:
			indices.append((start + j) % SPINE_COUNT)
		_retract_groups.append({ "indices": indices, "timer": float(g) * phase_step })

	var player := get_parent().get_parent()
	if player != null and player.has_signal("died"):
		player.died.connect(_on_player_died)


func _process(delta: float) -> void:
	_time += delta

	var player := get_parent().get_parent()
	if player != null and player.get("velocity") != null:
		_player_vel = player.velocity
		_speed      = clampf(_player_vel.length() / 420.0, 0.0, 1.0)

	_update_retract_groups(delta)
	_update_clusters(delta)
	queue_redraw()


func _on_player_died() -> void:
	visible = false


# ── Grup çekilme ──────────────────────────────────────────────────────────────

func _update_retract_groups(delta: float) -> void:
	var total_action: float = RETRACT_DUR + HIDDEN_DUR + EXTEND_DUR
	for i in SPINE_COUNT:
		_spine_push[i] = 0.0

	for g in _retract_groups:
		g["timer"] = fmod(g["timer"] + delta, RETRACT_CYCLE)
		var t: float = g["timer"]

		var retract_t: float = 0.0
		if t < RETRACT_DUR:
			var p: float = t / RETRACT_DUR
			retract_t = p * p * (3.0 - 2.0 * p)
		elif t < RETRACT_DUR + HIDDEN_DUR:
			retract_t = 1.0
		elif t < total_action:
			var p: float = (t - RETRACT_DUR - HIDDEN_DUR) / EXTEND_DUR
			retract_t = 1.0 - p * p * (3.0 - 2.0 * p)

		for idx in g["indices"]:
			_spine_retract_t[idx] = retract_t

		# Piyano dalgası — grubun yanlarından yayılan gecikmeli zincirleme
		if retract_t > 0.001:
			var first: int = g["indices"][0]
			var last:  int = g["indices"][g["indices"].size() - 1]
			for d in REPULSE_RANGE:
				var delay: float      = float(d) * 0.065
				var wave_t: float     = t - delay
				var wave_push: float  = 0.0
				if wave_t > 0.0 and wave_t < 0.50:
					wave_push = sin(wave_t / 0.50 * PI)
				var amp: float = REPULSE_STRENGTH * (1.0 - float(d) / float(REPULSE_RANGE))
				amp = amp * amp
				_spine_push[(first - 1 - d + SPINE_COUNT) % SPINE_COUNT] -= wave_push * amp
				_spine_push[(last  + 1 + d) % SPINE_COUNT]               += wave_push * amp


# ── Küme güncelleme ────────────────────────────────────────────────────────────

func _update_clusters(delta: float) -> void:
	_cluster_timer -= delta
	if _cluster_timer <= 0.0 and _clusters.size() < MAX_CLUSTERS:
		_spawn_cluster()
		_cluster_timer = CLUSTER_INTERVAL + randf_range(-0.8, 0.8)

	for c in _clusters:
		c["timer"] += delta
		var t_form: float    = CLUSTER_FORM_DUR
		var t_hold: float    = t_form + CLUSTER_HOLD_DUR
		var t_release: float = t_hold + CLUSTER_RELEASE_DUR
		var lerp_t: float    = 0.0
		if c["timer"] < t_form:
			var p: float = c["timer"] / t_form
			lerp_t = p * p * (3.0 - 2.0 * p)
		elif c["timer"] < t_hold:
			lerp_t = 1.0
			if not c["fired"]:
				c["fired"] = true
				_fire_cluster_laser(c)
		elif c["timer"] < t_release:
			var p: float = (c["timer"] - t_hold) / CLUSTER_RELEASE_DUR
			lerp_t = 1.0 - p * p * (3.0 - 2.0 * p)
		for idx in c["indices"]:
			_spine_cluster_t[idx] = lerp_t

	var total: float = CLUSTER_FORM_DUR + CLUSTER_HOLD_DUR + CLUSTER_RELEASE_DUR
	_clusters = _clusters.filter(func(c): return c["timer"] < total)


func _spawn_cluster() -> bool:
	var size: int = randi_range(CLUSTER_SIZE_MIN, CLUSTER_SIZE_MAX)

	# En yakın asteroide bak — ona yönelen spine'ı merkez al (turret mantığı)
	var best_angle: float = randf() * TAU   # asteroid yoksa rastgele
	var best_dist:  float = INF
	for node in get_tree().get_nodes_in_group("asteroid"):
		if not is_instance_valid(node):
			continue
		var d: float = node.global_position.distance_to(global_position)
		if d < best_dist:
			best_dist  = d
			best_angle = (node.global_position - global_position).angle()

	# best_angle'a en yakın spine indeksini bul
	var best_idx: int   = 0
	var best_diff: float = INF
	for i in SPINE_COUNT:
		var diff: float = absf(angle_difference(float(_spine_angle[i]), best_angle))
		if diff < best_diff:
			best_diff = diff
			best_idx  = i
	# Grubu merkeze al: merkez idx → start = merkez - size/2
	var start: int    = (best_idx - size / 2 + SPINE_COUNT) % SPINE_COUNT
	var attempts: int = 0

	while attempts < 20:
		var free: bool = true
		for j in size:
			if _spine_cluster_t[(start + j) % SPINE_COUNT] > 0.05:
				free = false; break
		if free: break
		# Meşgulse komşu slota kaydır
		start    = (start + 1) % SPINE_COUNT
		attempts += 1
	if attempts >= 20:
		return false

	var center_idx: int     = (start + size / 2) % SPINE_COUNT
	var center_angle: float = _spine_angle[center_idx]
	var max_len: float      = 0.0
	for j in size:
		max_len = maxf(max_len, _spine_len[(start + j) % SPINE_COUNT])
	var conv_pt: Vector2 = Vector2(cos(center_angle), sin(center_angle)) * \
						   (MEMBRANE_RADIUS + max_len * CLUSTER_TIP_REACH)

	var indices: Array = []
	for j in size:
		var idx: int = (start + j) % SPINE_COUNT
		indices.append(idx)
		_spine_cluster_conv[idx] = conv_pt
	_clusters.append({ "indices": indices, "timer": 0.0, "fired": false })
	return true


func _fire_cluster_laser(c: Dictionary) -> void:
	var conv_local: Vector2 = _spine_cluster_conv[c["indices"][0]]
	# Üçgenin apex noktası: conv_local'dan dışa doğru tri_h * 0.6 kadar ileri
	# tri_h = 6.5 * cl_t=1 → 6.5, apex offset = outward * 6.5 * 0.6 = outward * 3.9
	var apex_local: Vector2 = conv_local + conv_local.normalized() * 3.9
	_spawn_cluster_laser_from_local(apex_local)


func _spawn_cluster_laser_from_local(apex_local: Vector2) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	if String(scene_root.scene_file_path) == WORLD_TEST_SCENE_PATH:
		return
	var laser := _CLUSTER_LASER_SCRIPT.new()
	laser.name = "ClusterLaser"
	scene_root.add_child(laser)
	laser.setup(self, apex_local)


# ── Küme üçgeni çizimi ────────────────────────────────────────────────────────

func _draw_cluster_triangles() -> void:
	for c in _clusters:
		if c["indices"].is_empty():
			continue
		var cl_t: float = _spine_cluster_t[c["indices"][0]]
		if cl_t < 0.04:
			continue

		var conv_pt: Vector2  = _spine_cluster_conv[c["indices"][0]]
		var outward: Vector2  = conv_pt.normalized()
		var tangent: Vector2  = Vector2(-outward.y, outward.x)
		var pulse: float = sin(_time * 9.0) * 0.12 + 0.88
		# 4. kuvvet eğrisi — üçgen de aynı şekilde
		var op: float = cl_t * cl_t * cl_t * cl_t

		var tri_h: float = 6.5 * cl_t
		var tri_w: float = 5.0 * cl_t

		var apex:   Vector2 = conv_pt + outward * tri_h * 0.6
		var base_l: Vector2 = conv_pt - outward * tri_h * 0.4 - tangent * tri_w * 0.5
		var base_r: Vector2 = conv_pt - outward * tri_h * 0.4 + tangent * tri_w * 0.5
		var tri: PackedVector2Array = PackedVector2Array([apex, base_l, base_r])

		# Dolgu
		draw_colored_polygon(tri,
			Color(COLOR_CLUSTER.r, COLOR_CLUSTER.g, COLOR_CLUSTER.b, op * 0.22 * pulse))

		# Kenar çizgileri
		var ea: float = op * 0.92 * pulse
		draw_line(apex, base_l, Color(COLOR_CLUSTER.r, COLOR_CLUSTER.g, COLOR_CLUSTER.b, ea), 0.7, true)
		draw_line(apex, base_r, Color(COLOR_CLUSTER.r, COLOR_CLUSTER.g, COLOR_CLUSTER.b, ea), 0.7, true)
		draw_line(base_l, base_r, Color(COLOR_CLUSTER.r, COLOR_CLUSTER.g, COLOR_CLUSTER.b, ea * 0.55), 0.5, true)

		# Parlak iç kenar
		draw_line(apex, base_l, Color(0.80, 1.0, 0.84, op * 0.58 * pulse), 0.25, true)
		draw_line(apex, base_r, Color(0.80, 1.0, 0.84, op * 0.58 * pulse), 0.25, true)



# ── Draw ───────────────────────────────────────────────────────────────────────

func _draw() -> void:
	_draw_spines()
	_draw_membrane()


func _draw_membrane() -> void:
	# Nefes: tüm halka yavaşça genişleyip daralır
	var breathe: float = sin(_time * BREATHE_FREQ * TAU) * BREATHE_AMP
	var pts: PackedVector2Array = PackedVector2Array()
	pts.resize(MEMBRANE_SEGMENTS + 1)
	for i in MEMBRANE_SEGMENTS + 1:
		var a: float = (float(i) / float(MEMBRANE_SEGMENTS)) * TAU
		var w: float = sin(_time * 1.1 + a * 2.0) * 0.22 + sin(_time * 2.7 + a * 5.0) * 0.10
		pts[i] = Vector2(cos(a), sin(a)) * (MEMBRANE_RADIUS + breathe + w)
	draw_polyline(pts, Color(COLOR_DARK.r, COLOR_DARK.g, COLOR_DARK.b, 0.50), 2.2, true)
	draw_polyline(pts, Color(COLOR.r, COLOR.g, COLOR.b, 0.82), 1.35, true)
	draw_polyline(pts, Color(COLOR_HILITE.r, COLOR_HILITE.g, COLOR_HILITE.b, 0.28), 0.55, true)


func _draw_spines() -> void:
	var vel_dir: Vector2 = _player_vel.normalized() if _speed > 0.05 else Vector2.ZERO

	# Global modülatörler — her frame tek hesap
	var breathe: float = sin(_time * BREATHE_FREQ * TAU) * BREATHE_AMP
	var energy: float  = 0.60 + 0.40 * sin(_time * ENERGY_FREQ * TAU)   # 0.2 .. 1.0

	var pts3: PackedVector2Array = PackedVector2Array()
	pts3.resize(3)

	for i in SPINE_COUNT:
		var base_angle: float = float(_spine_angle[i])
		var outward: Vector2  = Vector2(cos(base_angle), sin(base_angle))
		var tangent: Vector2  = Vector2(-sin(base_angle), cos(base_angle))

		var mem_w:   float   = sin(_time * 1.1 + base_angle * 2.0) * 0.22
		var base_r:  float   = MEMBRANE_RADIUS + breathe + mem_w
		var base_pt: Vector2 = outward * base_r

		# ── Metakronal vuruş ───────────────────────────────────────────────────
		# Dalga halkayı dolaşıyor: faz = t*FREQ + angle*K + kişisel ofset
		var meta_phase: float = _time * WAVE_FREQ + base_angle * METACHRONAL_K + float(_spine_phase[i])
		# Asimetrik vuruş: hızlı güç, yavaş geri dönüş
		var stroke: float = sin(meta_phase) - sin(meta_phase * 2.0) * 0.16
		# Radyal nabız (uzunluk)
		var radial_w: float = stroke * IDLE_RADIAL
		# Yanal salınım (kıvrım)
		var lat: float = stroke * WAVE_LAT * energy

		# İkincil yanal titreşim — daha yavaş, farklı faz
		var lat2: float = sin(_time * WAVE_FREQ * 0.61 + float(_spine_lat_ph[i])) * 0.28 * energy
		lat += lat2

		# Hız rüzgarı — hareket yönüne göre bükülme
		if _speed > 0.04:
			var drag: float = tangent.dot(vel_dir) * _speed * BEND_SPEED
			lat += drag * energy

		# Çekilme ölçeği
		var retract_scale: float = 1.0 - float(_spine_retract_t[i])

		# Piyano itmesi
		lat += float(_spine_push[i])

		# Küme spines hafif uzun — cl_t ile %25'e kadar uzar
		var cl_t_pre: float = _spine_cluster_t[i]
		var length: float   = (_spine_len[i] + radial_w) * (1.0 + cl_t_pre * 0.25) * retract_scale
		lat *= retract_scale

		# Uç titremi — yalnızca uca eklenir, gövde sabit
		var flutter: float = sin(_time * FLUTTER_FREQ + float(_spine_phase[i]) * 4.1) * \
							 FLUTTER_AMP * energy * retract_scale

		# ── Silia ────────────────────────────────────────────────────────────
		var mid_pt: Vector2 = base_pt + outward * length * 0.58 + tangent * (lat * CURVE_MID)
		var tip_pt: Vector2 = base_pt + outward * length + tangent * lat + tangent * flutter

		var ph:  float = float(_spine_phase[i])
		var lph: float = float(_spine_lat_ph[i])
		var dark_t: float = (sin(_time * 0.52 + ph * 1.7) * 0.5 + 0.5) * \
							(sin(_time * 0.21 + lph) * 0.5 + 0.5)
		dark_t = dark_t * dark_t * 0.55
		var bright_t: float = maxf(0.0, stroke) * 0.20 * energy
		var col: Color = COLOR.lerp(COLOR_DARK, dark_t)
		col.a = clampf(col.a + bright_t, 0.0, 1.0)

		# Küme geometrisi
		var cl_t: float = _spine_cluster_t[i]
		if cl_t > 0.001:
			var conv: Vector2 = _spine_cluster_conv[i]
			tip_pt = tip_pt.lerp(conv, cl_t)
			mid_pt = base_pt.lerp(tip_pt, 0.55)

		pts3[0] = base_pt
		pts3[1] = mid_pt
		pts3[2] = tip_pt

		# Glow aura — arka plan yumuşak hale (gövde tam, uç yarı glow)
		var glow_col: Color = Color(col.r, col.g, col.b, col.a * 0.22)
		draw_line(base_pt, mid_pt, glow_col, SPINE_WIDTH * 2.8, true)
		draw_line(mid_pt, tip_pt, glow_col, SPINE_WIDTH * 1.0, true)
		# Ana silia — gövde tam genişlik, uç ince (keskin)
		draw_line(base_pt, mid_pt, col, SPINE_WIDTH, true)
		draw_line(mid_pt, tip_pt, col, SPINE_WIDTH * 0.30, true)
		# İnce parlak çekirdek — uçta daha da ince
		var core_mix: Color = col.lerp(COLOR_HILITE, 0.55)
		var core_col: Color = Color(core_mix.r, core_mix.g, core_mix.b,
								   clampf(col.a * 0.42 + bright_t, 0.0, 1.0))
		draw_line(base_pt, mid_pt, core_col, SPINE_WIDTH * 0.25, true)
		draw_line(mid_pt, tip_pt, core_col, SPINE_WIDTH * 0.10, true)

		# ── Enerji damarı ─────────────────────────────────────────────────────
		if cl_t > 0.001:
			var sd: Vector2   = (tip_pt - base_pt).normalized()
			var slen: float   = base_pt.distance_to(tip_pt)
			var perp: Vector2 = Vector2(-sd.y, sd.x)
			var vend: Vector2 = base_pt + sd * slen * cl_t

			# 4. kuvvet eğrisi: uzun süre görünmez, son anda ani parlama
			var op: float = cl_t * cl_t * cl_t * cl_t

			# Dış damar glow
			draw_line(base_pt, vend,
				Color(COLOR_CLUSTER.r, COLOR_CLUSTER.g, COLOR_CLUSTER.b, op * 0.40),
				0.9, true)
			# Ana damar
			draw_line(base_pt, vend,
				Color(COLOR_CLUSTER.r, COLOR_CLUSTER.g, COLOR_CLUSTER.b, op * 0.95),
				0.38, true)
			# Parlak çekirdek
			draw_line(base_pt, vend,
				Color(0.82, 1.00, 0.86, op * 0.70),
				0.15, true)
			# Yan damar
			draw_line(base_pt + perp * 0.5, vend + perp * 0.5,
				Color(COLOR_CLUSTER.r, COLOR_CLUSTER.g, COLOR_CLUSTER.b, op * 0.30),
				0.20, true)
