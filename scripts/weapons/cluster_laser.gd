extends Node2D
const UpgradeEffects = preload("res://scripts/upgrades/upgrade_effects.gd")
## Küme lazeri — yeşil kıvılcım + buhar efekti, asteroid görseline dokunmaz.

const BASE_LIFETIME:  float = 2.0
const DAMAGE_PER_SEC: float = 115.0
const SFX_PATH:       String = "res://assets/sfx/cluster_lazer.mp3"
const SFX_BASE_PITCH_SCALE: float = 1.35
const SFX_VOLUME_DB: float = -4.0

# ── Zemin çizgi partikülleri ─────────────────────────────────────────────────
const P_COUNT:     int   = 18
const P_SPREAD:    float = 0.8
const P_WIDTH_MIN: float = 0.08
const P_WIDTH_MAX: float = 0.16
const P_LEN_MIN:   float = 0.50
const P_LEN_MAX:   float = 1.00

# ── Akan enerji noktaları ─────────────────────────────────────────────────────
const FLOW_COUNT: int   = 12
const FLOW_SPEED: float = 1.6
const FLOW_R_MIN: float = 0.9
const FLOW_R_MAX: float = 2.2

# ── Kıvılcım ─────────────────────────────────────────────────────────────────
const SPARK_RATE:     float = 42.0
const SPARK_LIFE_MIN: float = 0.10
const SPARK_LIFE_MAX: float = 0.26
const SPARK_SPD_MIN:  float = 40.0
const SPARK_SPD_MAX:  float = 115.0
const SPARK_LEN_MIN:  float = 1.2
const SPARK_LEN_MAX:  float = 5.0

# ── Duman ─────────────────────────────────────────────────────────────────────
const VAPOR_RATE:     float = 7.0
const VAPOR_LIFE_MIN: float = 0.55
const VAPOR_LIFE_MAX: float = 1.10
const VAPOR_SPD_MIN:  float = 5.0
const VAPOR_SPD_MAX:  float = 14.0
const VAPOR_R_START:  float = 2.0
const VAPOR_R_END:    float = 13.0

# ── Renkler ──────────────────────────────────────────────────────────────────
const COLOR_P:      Color = Color(0.22, 1.00, 0.42, 1.00)
const COLOR_BRIGHT: Color = Color(0.70, 1.00, 0.78, 1.00)
const COLOR_GLOW:   Color = Color(0.05, 0.78, 0.20, 0.10)

# ── State ────────────────────────────────────────────────────────────────────
var _barrier:     Node2D  = null
var _origin_dir:  Vector2 = Vector2.ZERO
var _origin_dist: float   = 0.0
var _target:      Node2D  = null
var _sfx_player:  AudioStreamPlayer = null
var _lifetime:    float   = BASE_LIFETIME
var _elapsed:     float   = 0.0
var _time:        float   = 0.0
var _dmg_acc:     float   = 0.0
var _spark_acc:   float   = 0.0
var _vapor_acc:   float   = 0.0

var _origin_w: Vector2 = Vector2.ZERO
var _end_w:    Vector2 = Vector2.ZERO
var _beam_len: float   = 0.0
var _hitting:  bool    = false   # hedef yüzeye değiyor mu

# {pos, vel, life, max_life, len}
var _sparks: Array = []
# {pos, vel, life, max_life, r_start, r_end}
var _vapors: Array = []

var _p_lat:      PackedFloat32Array
var _p_phase:    PackedFloat32Array
var _p_len:      PackedFloat32Array
var _p_width:    PackedFloat32Array
var _flow_offset: PackedFloat32Array
var _flow_r:      PackedFloat32Array
var _flow_lat:    PackedFloat32Array


func setup(barrier: Node2D, conv_local: Vector2) -> void:
	_barrier     = barrier
	global_position = Vector2.ZERO
	_origin_dir  = conv_local.normalized()
	_origin_dist = conv_local.length()
	_setup_fire_sfx()

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	_p_lat   = PackedFloat32Array(); _p_lat.resize(P_COUNT)
	_p_phase = PackedFloat32Array(); _p_phase.resize(P_COUNT)
	_p_len   = PackedFloat32Array(); _p_len.resize(P_COUNT)
	_p_width = PackedFloat32Array(); _p_width.resize(P_COUNT)
	for i in P_COUNT:
		var u: float = rng.randf_range(-1.0, 1.0)
		_p_lat[i]   = u * absf(u)
		_p_phase[i] = rng.randf() * TAU
		_p_len[i]   = rng.randf_range(P_LEN_MIN, P_LEN_MAX)
		_p_width[i] = rng.randf_range(P_WIDTH_MIN, P_WIDTH_MAX)

	_flow_offset = PackedFloat32Array(); _flow_offset.resize(FLOW_COUNT)
	_flow_r      = PackedFloat32Array(); _flow_r.resize(FLOW_COUNT)
	_flow_lat    = PackedFloat32Array(); _flow_lat.resize(FLOW_COUNT)
	for i in FLOW_COUNT:
		_flow_offset[i] = float(i) / float(FLOW_COUNT)
		_flow_r[i]      = rng.randf_range(FLOW_R_MIN, FLOW_R_MAX)
		_flow_lat[i]    = rng.randf_range(-P_SPREAD * 0.5, P_SPREAD * 0.5)

	var origin: Vector2 = barrier.global_position + _origin_dir * _origin_dist
	_target = _find_best_target(origin)


func _setup_fire_sfx() -> void:
	if _sfx_player != null:
		return
	var audio_bytes := FileAccess.get_file_as_bytes(SFX_PATH)
	if audio_bytes.is_empty():
		push_warning("ClusterLaser: ses dosyasi okunamadi: " + SFX_PATH)
		return
	var stream := AudioStreamMP3.new()
	stream.data = audio_bytes
	var run_state := get_node_or_null("/root/RunState")
	var duration_multiplier := UpgradeEffects.get_laser_duration_multiplier(run_state)
	var pitch_scale := SFX_BASE_PITCH_SCALE / maxf(0.01, duration_multiplier)
	var sound_len := stream.get_length()
	if sound_len > 0.01:
		_lifetime = sound_len / pitch_scale
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.stream = stream
	_sfx_player.volume_db = SFX_VOLUME_DB
	_sfx_player.pitch_scale = pitch_scale
	_sfx_player.bus = _get_cluster_laser_bus()
	_sfx_player.finished.connect(_on_sfx_finished)
	add_child(_sfx_player)
	_sfx_player.play()


func _get_cluster_laser_bus() -> StringName:
	var bus_name := &"ClusterLaserSFX"
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		return bus_name

	AudioServer.add_bus()
	bus_idx = AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus_idx, bus_name)
	AudioServer.set_bus_send(bus_idx, &"Master")

	var low_pass := AudioEffectLowPassFilter.new()
	low_pass.cutoff_hz = 2400.0
	low_pass.resonance = 0.8
	AudioServer.add_bus_effect(bus_idx, low_pass)

	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.92
	reverb.damping = 0.78
	reverb.spread = 1.0
	reverb.dry = 0.92
	reverb.wet = 0.08
	reverb.predelay_msec = 18.0
	AudioServer.add_bus_effect(bus_idx, reverb)

	return bus_name


func _process(delta: float) -> void:
	_elapsed += delta
	_time    += delta

	if _sfx_player == null and _elapsed >= _lifetime:
		queue_free()
		return
	if _sfx_player != null and not _sfx_player.playing and _elapsed > 0.05:
		queue_free()
		return
	if _barrier == null or not is_instance_valid(_barrier):
		if _sfx_player != null:
			_sfx_player.stop()
		queue_free()
		return

	_origin_w = _barrier.global_position + _origin_dir * _origin_dist

	if _target == null or not is_instance_valid(_target) or not _in_cone(_target):
		_target = _find_best_target(_origin_w)
		if _target == null:
			queue_free()
			return

	var to_tgt:  Vector2 = _target.global_position - _origin_w
	var tgt_dir: Vector2 = to_tgt.normalized()
	var surf_r:  float   = float(_target.get("radius")) if _target.get("radius") != null else 20.0
	_beam_len = maxf(0.0, to_tgt.length() - surf_r)
	_end_w    = _origin_w + tgt_dir * _beam_len
	_hitting  = _beam_len > 2.0

	# Hasar
	_dmg_acc += DAMAGE_PER_SEC * delta
	if _dmg_acc >= 1.0:
		var dmg: float = floorf(_dmg_acc)
		_dmg_acc -= dmg
		_apply_damage(dmg)

	if _hitting:
		var beam_dir:  Vector2 = tgt_dir
		var beam_perp: Vector2 = Vector2(-beam_dir.y, beam_dir.x)

		# ── Kıvılcım spawn ───────────────────────────────────────────────────
		_spark_acc += SPARK_RATE * delta
		var sc: int = int(_spark_acc)
		_spark_acc -= float(sc)
		for _si in sc:
			var angle: float = randf_range(0.0, TAU)
			var spd:   float = randf_range(SPARK_SPD_MIN, SPARK_SPD_MAX)
			# Çoğunlukla ışına dik yönde, biraz geri sıçrama da olsun
			var base_angle: float = PI * 0.5 + randf_range(-PI * 0.65, PI * 0.65)
			var vdir: Vector2 = beam_dir.rotated(base_angle)
			var life: float = randf_range(SPARK_LIFE_MIN, SPARK_LIFE_MAX)
			_sparks.append({
				"pos":      _end_w + beam_perp * randf_range(-1.5, 1.5),
				"vel":      vdir * spd,
				"life":     life,
				"max_life": life,
				"len":      randf_range(SPARK_LEN_MIN, SPARK_LEN_MAX),
			})

		# ── Buhar spawn ───────────────────────────────────────────────────────
		_vapor_acc += VAPOR_RATE * delta
		var vc: int = int(_vapor_acc)
		_vapor_acc -= float(vc)
		for _vi in vc:
			# Duman: yavaş, yukarı ağırlıklı, hafif yayılma
			var vspd:   float   = randf_range(VAPOR_SPD_MIN, VAPOR_SPD_MAX)
			var vangle: float   = randf_range(-PI * 0.45, PI * 0.45)
			var vdir:   Vector2 = (beam_perp.rotated(vangle) + Vector2(randf_range(-0.3, 0.3), -1.2)).normalized()
			var vlife:  float   = randf_range(VAPOR_LIFE_MIN, VAPOR_LIFE_MAX)
			_vapors.append({
				"pos":      _end_w + beam_perp * randf_range(-3.0, 3.0),
				"vel":      vdir * vspd,
				"life":     vlife,
				"max_life": vlife,
			})

	# ── Kıvılcım güncelleme ──────────────────────────────────────────────────
	var i := 0
	while i < _sparks.size():
		var sp = _sparks[i]
		sp["life"] -= delta
		if sp["life"] <= 0.0:
			_sparks.remove_at(i)
			continue
		sp["vel"] += Vector2(0.0, 35.0) * delta   # hafif yerçekimi
		sp["vel"] *= (1.0 - delta * 4.0)
		sp["pos"] += sp["vel"] * delta
		_sparks[i] = sp
		i += 1

	# ── Buhar güncelleme ─────────────────────────────────────────────────────
	var j := 0
	while j < _vapors.size():
		var vp = _vapors[j]
		vp["life"] -= delta
		if vp["life"] <= 0.0:
			_vapors.remove_at(j)
			continue
		vp["vel"] *= (1.0 - delta * 1.8)   # yavaşla
		vp["pos"] += vp["vel"] * delta
		_vapors[j] = vp
		j += 1

	queue_redraw()


func _in_cone(node: Node2D) -> bool:
	var dir: Vector2 = (node.global_position - _origin_w).normalized()
	return _origin_dir.dot(dir) > 0.0


func _find_best_target(from: Vector2) -> Node2D:
	var best_dist: float = INF
	var best: Node2D = null
	for node in get_tree().get_nodes_in_group("asteroid"):
		if not is_instance_valid(node): continue
		var dir: Vector2 = (node.global_position - from).normalized()
		if _origin_dir.dot(dir) <= 0.0: continue
		var d: float = node.global_position.distance_to(from)
		if d < best_dist:
			best_dist = d
			best      = node
	return best


func _apply_damage(amount: float) -> void:
	if _target == null or not is_instance_valid(_target): return
	if _target.has_method("take_mining_damage"):
		_target.call("take_mining_damage", amount, false)
	elif _target.has_method("take_damage"):
		_target.call("take_damage", amount)


func _on_sfx_finished() -> void:
	queue_free()


func _draw() -> void:
	if _beam_len < 2.0: return
	if _target == null or not is_instance_valid(_target): return

	var s:    Vector2 = _origin_w
	var e:    Vector2 = _end_w
	var dir:  Vector2 = (e - s).normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x)

	var life_t: float
	if _sfx_player != null and _sfx_player.stream != null and _lifetime > 0.001:
		life_t = clampf(_sfx_player.get_playback_position() / _lifetime, 0.0, 1.0)
	else:
		life_t = _elapsed / maxf(0.001, _lifetime)
	var fade_in:    float = clampf(life_t * 6.0, 0.0, 1.0)
	var fade_out:   float = clampf((1.0 - life_t) * 4.0, 0.0, 1.0)
	var global_alpha: float = fade_in * fade_out

	# ── Duman (lazer arkasında çizilsin) ─────────────────────────────────────
	for vp in _vapors:
		var t: float  = vp["life"] / vp["max_life"]   # 1→0
		var r: float  = lerp(VAPOR_R_END, VAPOR_R_START, t)
		# Uzayda dağılan duman: hızlı solar, çok ince alfa
		var va: float = t * t * 0.18
		# Lazer rengiyle birebir — dış halka
		draw_circle(vp["pos"], r,
			Color(COLOR_P.r, COLOR_P.g, COLOR_P.b, va))
		# İç parlak çekirdek — biraz daha yoğun, küçük
		draw_circle(vp["pos"], r * 0.38,
			Color(COLOR_BRIGHT.r, COLOR_BRIGHT.g, COLOR_BRIGHT.b, va * 0.55))

	# ── Dış sis ──────────────────────────────────────────────────────────────
	draw_line(s, e,
		Color(COLOR_GLOW.r, COLOR_GLOW.g, COLOR_GLOW.b, COLOR_GLOW.a * global_alpha),
		2.0, true)

	# ── Zemin çizgi partikülleri ─────────────────────────────────────────────
	for i in P_COUNT:
		var lat:   float = float(_p_lat[i]) * P_SPREAD
		var ph:    float = float(_p_phase[i])
		var p_len: float = float(_p_len[i]) * _beam_len
		var p_w:   float = float(_p_width[i])
		var flicker: float = sin(_time * 26.0 + ph) * 0.20 + \
							 sin(_time * 49.0 + ph * 1.8) * 0.08 + 0.72
		var alpha: float = flicker * global_alpha
		var center_boost: float = 1.0 - absf(float(_p_lat[i])) * 0.55
		var p_s: Vector2 = s + perp * lat * 0.12
		var p_e: Vector2 = s + dir * p_len + perp * lat
		draw_line(p_s, p_e,
			Color(COLOR_P.r, COLOR_P.g, COLOR_P.b, alpha * center_boost),
			p_w, true)

	# ── Akan enerji noktaları ─────────────────────────────────────────────────
	for i in FLOW_COUNT:
		var t: float = fmod(float(_flow_offset[i]) + _time * FLOW_SPEED, 1.0)
		var pos: Vector2 = s.lerp(e, t) + perp * float(_flow_lat[i])
		var size_t: float = sin(t * PI)
		var r: float = float(_flow_r[i]) * size_t
		if r < 0.15: continue
		var flow_alpha: float = size_t * global_alpha
		draw_circle(pos, r * 2.2,
			Color(COLOR_P.r, COLOR_P.g, COLOR_P.b, flow_alpha * 0.20))
		draw_circle(pos, r,
			Color(COLOR_P.r, COLOR_P.g, COLOR_P.b, flow_alpha * 0.85))
		draw_circle(pos, r * 0.38,
			Color(COLOR_BRIGHT.r, COLOR_BRIGHT.g, COLOR_BRIGHT.b, flow_alpha * 0.95))

	# ── Kaynak nokta ─────────────────────────────────────────────────────────
	draw_circle(s, 1.6, Color(COLOR_P.r, COLOR_P.g, COLOR_P.b, 0.60 * global_alpha))
	draw_circle(s, 0.7, Color(1.0, 1.0, 1.0, 0.85 * global_alpha))

	# ── Hedef parlaması ───────────────────────────────────────────────────────
	var hit_pulse: float = sin(_time * 18.0) * 0.25 + 0.75
	draw_circle(e, 4.5 * hit_pulse,
		Color(COLOR_P.r, COLOR_P.g, COLOR_P.b, 0.20 * global_alpha))
	draw_circle(e, 2.0,
		Color(COLOR_BRIGHT.r, COLOR_BRIGHT.g, COLOR_BRIGHT.b, 0.70 * global_alpha))

	# ── Yeşil kıvılcımlar ─────────────────────────────────────────────────────
	for sp in _sparks:
		var t: float      = sp["life"] / sp["max_life"]
		var sp_alpha: float = t * t
		var sp_len: float   = sp["len"] * t
		var sp_vel: Vector2 = sp["vel"]
		var sp_dir: Vector2 = sp_vel.normalized() if sp_vel.length_squared() > 0.5 else dir
		var sp_pos: Vector2 = sp["pos"]
		var sp_end: Vector2 = sp_pos + sp_dir * sp_len

		# Dış glow çizgisi
		draw_line(sp_pos, sp_end,
			Color(COLOR_P.r, COLOR_P.g, COLOR_P.b, sp_alpha * 0.55), 1.2, true)
		# Parlak çekirdek
		draw_line(sp_pos, sp_end,
			Color(COLOR_BRIGHT.r, COLOR_BRIGHT.g, COLOR_BRIGHT.b, sp_alpha * 0.90), 0.4, true)
		# Başlangıç noktası parıltısı
		if t > 0.55:
			draw_circle(sp_pos, 1.0 * t,
				Color(COLOR_BRIGHT.r, COLOR_BRIGHT.g, COLOR_BRIGHT.b, sp_alpha * 0.70))
