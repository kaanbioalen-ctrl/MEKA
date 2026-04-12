extends Node2D
## Uzay-zaman bükülmesi dalgası.
## Dalga asteroid'e çarptığında onun arkasına geçmez — önünde durur, etrafından devam eder.
## Asteroid'in açısal gölgesi hesaplanır, o aralık atlanır. Yüzeyde temas flaşı oluşur.

# ── Sabitler ───────────────────────────────────────────────────────────────────

const WAVE_TRAVEL_TIME  : float = 0.52
const WAVE_START_RADIUS : float = 8.0
const WAVE_BASE_WIDTH   : float = 9.0
const WAVE_MIN_WIDTH    : float = 2.0
const WAVE_ALPHA_START  : float = 0.92
const WAVE_FADE_POWER   : float = 1.55
const PULSE_DURATION    : float = 0.22

# ── Durum ──────────────────────────────────────────────────────────────────────

var _waves  : Array = []
var _pulse_t: float = -1.0

# ── SFX ────────────────────────────────────────────────────────────────────────
# Her vuruş iki katmandan oluşur:
#   body    — düşük pitch, kalın darbe (asteroid kütlesi hissi)
#   shimmer — yüksek pitch, çok sessiz, metalik tını (uzay rezonansı)
# Pitch boyuta göre değişir: büyük asteroid → daha kalın ses
# Volume mesafeye göre ölçeklenir: uzak asteroid → daha sessiz
# Crit vuruşlar biraz daha parlak ve yüksek

const VOICE_COUNT    := 8
const BASE_VOLUME_DB := -10.0
const AST_R_MIN      := 12.0
const AST_R_MAX      := 54.0

var _voices     : Array = []   # [{player, busy, start_ms, tween}, ...]
var _sfx_stream : AudioStream = null


func _ready() -> void:
	_sfx_stream = load("res://assets/sfx/damage.mp3")
	var bus := _get_space_bus()
	for i in VOICE_COUNT:
		var p := _make_player(BASE_VOLUME_DB, bus)
		_voices.append({"player": p, "busy": false, "start_ms": 0, "tween": null})


func _make_player(vol: float, bus: StringName) -> AudioStreamPlayer2D:
	var p := AudioStreamPlayer2D.new()
	p.stream       = _sfx_stream
	p.volume_db    = vol
	p.max_distance = 2000.0
	p.bus          = bus
	add_child(p)
	return p


func _play_hit_sfx(falloff: float, ast_radius: float, is_crit: bool, fade_delay: float) -> void:
	# Boş voice ara
	var voice: Dictionary = {}
	for v in _voices:
		if not bool(v["busy"]):
			voice = v
			break

	# Tüm voice'lar doluysa en eskisini çal (voice stealing)
	if voice.is_empty():
		var oldest_ms := int(Time.get_ticks_msec()) + 1
		for v in _voices:
			if int(v["start_ms"]) < oldest_ms:
				oldest_ms = int(v["start_ms"])
				voice = v
		var old_tw: Tween = voice.get("tween")
		if old_tw != null and old_tw.is_valid():
			old_tw.kill()
		var ps: AudioStreamPlayer2D = voice["player"]
		ps.stop()
		ps.volume_db = BASE_VOLUME_DB

	voice["busy"]     = true
	voice["start_ms"] = Time.get_ticks_msec()
	var p : AudioStreamPlayer2D = voice["player"]

	# Boyut → pitch: büyük asteroid = kalın/tok, küçük = biraz daha ince
	var size_t := clampf(inverse_lerp(AST_R_MIN, AST_R_MAX, ast_radius), 0.0, 1.0)
	var pitch   := lerpf(0.54, 0.38, size_t) + randf_range(-0.03, 0.03)
	if is_crit:
		pitch *= 1.10

	# Falloff → volume: uzak vuruş daha sessiz
	var falloff_db := linear_to_db(maxf(0.05, falloff))
	p.pitch_scale  = pitch
	p.volume_db    = BASE_VOLUME_DB + falloff_db + (3.0 if is_crit else 0.0)
	p.play()

	# Dalga asteroidi geçtikten sonra ease-in ile organik sönüm
	var tw := create_tween()
	voice["tween"] = tw
	tw.tween_interval(fade_delay)
	tw.tween_property(p, "volume_db", -50.0, 0.22).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		p.stop()
		p.volume_db   = BASE_VOLUME_DB
		voice["busy"] = false
		voice["tween"] = null)


func _get_space_bus() -> StringName:
	var bus_name := &"SpaceWaveSFX"
	if AudioServer.get_bus_index(bus_name) != -1:
		return bus_name

	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, &"Master")

	# Compressor — dinamikleri sıkıştırır, tutarlı punch verir
	var comp := AudioEffectCompressor.new()
	comp.threshold  = -18.0   # -18 dB'den sonra devreye girer
	comp.ratio      = 4.0     # 4:1 oranı — tok darbe karakteri
	comp.attack_us  = 5.0     # çok hızlı attack — transient'ı yakalar
	comp.release_ms = 120.0   # orta release — doğal nefes
	comp.gain       = 4.0     # sıkıştırma kayıplarını telafi
	AudioServer.add_bus_effect(idx, comp)

	# EQ — tok + buğuk profil (compressor'dan sonra şekillendir)
	var eq := AudioEffectEQ10.new()
	eq.set_band_gain_db(0,  2.0)   # 31 Hz  — sub zemin, fazla değil
	eq.set_band_gain_db(1,  5.0)   # 62 Hz  — punch kemiği
	eq.set_band_gain_db(2,  7.0)   # 125 Hz — buğuk gövde, ana zon
	eq.set_band_gain_db(3,  4.0)   # 250 Hz — sıcaklık ve dolgunluk
	eq.set_band_gain_db(4, -3.0)   # 500 Hz — mud'ı azalt, buğukluğu netleştir
	eq.set_band_gain_db(5, -9.0)   # 1 kHz  — presence tamamen kes
	eq.set_band_gain_db(6, -13.0)  # 2 kHz  — kapat
	eq.set_band_gain_db(7, -16.0)  # 4 kHz  — kapat
	eq.set_band_gain_db(8, -18.0)  # 8 kHz  — yok et
	eq.set_band_gain_db(9, -18.0)  # 16 kHz — yok et
	AudioServer.add_bus_effect(idx, eq)

	# Reverb — minimal, sadece uzay derinliği
	var reverb := AudioEffectReverb.new()
	reverb.room_size     = 0.85
	reverb.damping       = 0.85   # yüksek frekanslar anında söner
	reverb.spread        = 1.0
	reverb.dry           = 0.88
	reverb.wet           = 0.10
	reverb.predelay_msec = 12.0
	AudioServer.add_bus_effect(idx, reverb)

	return bus_name

# ── Genel ──────────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if _pulse_t >= 0.0:
		_pulse_t += delta
		if _pulse_t >= PULSE_DURATION:
			_pulse_t = -1.0

	if _waves.is_empty() and _pulse_t < 0.0:
		return

	var i := _waves.size() - 1
	while i >= 0:
		var w     := _waves[i] as Dictionary
		var r_now := float(w["r"]) + float(w["speed"]) * delta
		var max_r := float(w["max_r"])
		w["prev_r"] = w["r"]
		w["r"]      = minf(r_now, max_r)
		_check_wave_damage(w)
		if float(w["r"]) >= max_r:
			_waves.remove_at(i)
		i -= 1

	queue_redraw()


func emit_wave(damage: float, is_crit: bool) -> void:
	var max_r := _get_max_radius()
	if max_r <= WAVE_START_RADIUS:
		return
	var speed := (max_r - WAVE_START_RADIUS) / WAVE_TRAVEL_TIME
	_waves.append({
		"r"       : WAVE_START_RADIUS,
		"prev_r"  : 0.0,
		"max_r"   : max_r,
		"speed"   : speed,
		"damage"  : damage,
		"is_crit" : is_crit,
		"hit_ids" : {}
	})
	_pulse_t = 0.0
	queue_redraw()


# ── Hasar tespiti ──────────────────────────────────────────────────────────────

func _check_wave_damage(w: Dictionary) -> void:
	var prev    := float(w["prev_r"])
	var curr    := float(w["r"])
	var dmg     := float(w["damage"])
	var is_crit := bool(w["is_crit"])
	var hit_ids := w["hit_ids"] as Dictionary
	var my_pos  := global_position

	for node in get_tree().get_nodes_in_group("asteroid"):
		if not (node is Node2D):
			continue
		var inst_id := node.get_instance_id()
		if hit_ids.has(inst_id):
			continue
		var n_pos := (node as Node2D).global_position
		var dist  := my_pos.distance_to(n_pos)
		if dist >= prev and dist < curr:
			hit_ids[inst_id] = true
			# Önünde yakın asteroid varsa hasar gölgede kalır — atla
			if _is_in_damage_shadow(my_pos, n_pos, dist):
				continue
			# 2B dalga enerji düşüşü: yoğunluk ∝ 1/√r (çevre ∝ r, enerji korunumu)
			var falloff := sqrt(WAVE_START_RADIUS / maxf(WAVE_START_RADIUS, dist))
			if node.has_method("take_mining_damage"):
				node.call("take_mining_damage", dmg * falloff, is_crit)
				var ast_r := 28.0
				var raw_r: Variant = node.get("radius")
				if raw_r != null:
					ast_r = maxf(12.0, float(raw_r))
				var fade_delay := (ast_r * 2.0) / maxf(1.0, float(w["speed"]))
				_play_hit_sfx(falloff, ast_r, is_crit, fade_delay)


## Hedef asteroitin daha yakın bir asteroid tarafından açısal olarak gölgelenip
## gölgelenmediğini kontrol eder. Görsel oklüzyonla tutarlı hasar fiziği.
func _is_in_damage_shadow(origin: Vector2, target_pos: Vector2, target_dist: float) -> bool:
	var target_angle := (target_pos - origin).angle()
	for blocker in get_tree().get_nodes_in_group("asteroid"):
		if not (blocker is Node2D):
			continue
		var b_rel  := (blocker as Node2D).global_position - origin
		var b_dist := b_rel.length()
		if b_dist >= target_dist or b_dist < 1.0:
			continue
		var raw_r: Variant = blocker.get("radius")
		var b_r := 28.0
		if raw_r != null:
			b_r = maxf(12.0, float(raw_r))
		var b_hb := asin(clampf(b_r / b_dist, 0.0, 0.999))
		var diff := target_angle - atan2(b_rel.y, b_rel.x)
		if diff >  PI: diff -= TAU
		if diff < -PI: diff += TAU
		if absf(diff) < b_hb:
			return true
	return false


# ── Oklüzyon ───────────────────────────────────────────────────────────────────

## Dalga halkasıyla kesişen asteroid'lerin açısal gölgelerini döndürür.
## Sonuç: [[merkez_açı, yarı_blok_açısı], ...]
func _get_occlusions(r: float, half_w: float) -> Array:
	var result := []
	var my_pos := global_position
	for node in get_tree().get_nodes_in_group("asteroid"):
		if not (node is Node2D):
			continue
		var rel  := (node as Node2D).global_position - my_pos
		var dist := rel.length()
		if dist < 1.0:
			continue
		# Asteroid'in görsel yarıçapını al
		var ast_r := 28.0
		var raw_r: Variant = node.get("radius")
		if raw_r != null:
			ast_r = maxf(12.0, float(raw_r))
		# Dalga halkasıyla kesişiyor mu?
		if dist + ast_r < r - half_w or dist - ast_r > r + half_w:
			continue
		var ca := atan2(rel.y, rel.x)
		var hb := asin(clampf(ast_r / dist, 0.0, 0.999)) + 0.05  # küçük margin
		result.append([ca, hb])
	return result


# ── Çizim ─────────────────────────────────────────────────────────────────────

func _draw() -> void:
	_draw_singularity_pulse()
	_draw_waves()


func _draw_singularity_pulse() -> void:
	if _pulse_t < 0.0 or _pulse_t >= PULSE_DURATION:
		return
	var pt := _pulse_t / PULSE_DURATION   # 0 → 1
	var pa := 1.0 - pt                    # fade out

	# ── 1. Merkezi void — uzay sıkışıyor, içe çöküyor ──────────────────────
	draw_circle(Vector2.ZERO,
		lerpf(1.0, 12.0, pt),
		Color(0.00, 0.00, 0.02, pa * pa * 0.96))

	# ── 2. Kromatik aberrasyon — ışık gravitasyonel alandan geçerken ayrışır ─
	# Gerçek lensing fiziği: kırmızı en az, mavi en çok kırılır
	# Kırmızı — en dışta, geride kalır
	draw_arc(Vector2.ZERO, lerpf(5.0, 30.0, pt), 0.0, TAU, 64,
		Color(1.00, 0.08, 0.18, pa * 0.72), lerpf(2.8, 0.5, pt), true)
	# Yeşil — ortada
	draw_arc(Vector2.ZERO, lerpf(7.0, 22.0, pt), 0.0, TAU, 64,
		Color(0.05, 0.95, 0.55, pa * 0.78), lerpf(3.2, 0.6, pt), true)
	# Mavi/mor — en içte, öne geçer
	draw_arc(Vector2.ZERO, lerpf(10.0, 15.0, pt), 0.0, TAU, 64,
		Color(0.25, 0.45, 1.00, pa * 0.90), lerpf(4.0, 1.0, pt), true)

	# ── 3. Plazma halkası — dalga cephesinin hemen arkasında yoğunlaşan enerji
	draw_arc(Vector2.ZERO, lerpf(14.0, 52.0, pt), 0.0, TAU, 48,
		Color(0.65, 0.15, 1.00, pa * pa * 0.50), lerpf(7.0, 1.2, pt), true)

	# ── 4. Temporal echo — zamansal yankı, çok soluk dış iz ─────────────────
	if pt < 0.55:
		var et := pt / 0.55
		draw_arc(Vector2.ZERO, lerpf(20.0, 65.0, et), 0.0, TAU, 32,
			Color(0.40, 0.75, 1.00, (1.0 - et) * 0.16), 1.0, true)


func _draw_waves() -> void:
	for w in _waves:
		var r     := float(w["r"])
		var max_r := float(w["max_r"])
		var t     := (r - WAVE_START_RADIUS) / maxf(1.0, max_r - WAVE_START_RADIUS)
		var alpha := pow(clampf(1.0 - t, 0.0, 1.0), WAVE_FADE_POWER) * WAVE_ALPHA_START
		if alpha < 0.008:
			continue

		var width := lerpf(WAVE_BASE_WIDTH, WAVE_MIN_WIDTH, t)
		var half  := width * 0.5
		var is_c  := bool(w["is_crit"])

		# Void fill — tam daire, oklüzyon gerekmez (çok ince, fark edilmez)
		draw_circle(Vector2.ZERO,
			maxf(2.0, r + half), Color(0.00, 0.00, 0.02, alpha * 0.55))

		# İkincil iç iz — tam daire, çok soluk
		if t < 0.52:
			var cf := 1.0 - (t / 0.52)
			draw_arc(Vector2.ZERO, maxf(1.0, r * 0.80), 0.0, TAU, 48,
				Color(0.04, 0.02, 0.10, alpha * 0.14 * cf), width * 0.22, true)

		# Asteroid oklüzyonlarını hesapla
		var occs := _get_occlusions(r, half)

		# Dalga halkasını asteroitleri atlayarak çiz
		_draw_wave_occluded(r, width, half, alpha, is_c, occs)

		# Asteroid yüzeyinde temas flaşı + gölge kenarında kırınım hornları
		for occ in occs:
			_draw_contact_flash(r, float(occ[0]), float(occ[1]), width, alpha, is_c)
			_draw_diffraction_horns(r, float(occ[0]), float(occ[1]), width, alpha, is_c)


## Dalga halkasını kesin açısal aralıklarla çizer — örnekleme yok, piksel mükemmel.
## Her asteroitin [ca-hb, ca+hb] aralığı engelli; araları çizer.
func _draw_wave_occluded(r: float, width: float, half: float, alpha: float, is_c: bool, occlusions: Array) -> void:
	if occlusions.is_empty():
		_draw_arc_seg(r, 0.0, TAU, width, half, alpha, is_c)
		return

	# Her oklüzyon için [0, TAU) uzayında kapalı aralıkları oluştur
	var intervals: Array = []
	for occ in occlusions:
		var ca := fmod(float(occ[0]) + TAU * 16.0, TAU)   # [-PI,PI] → [0,TAU)
		var hb := float(occ[1])
		var a0 := ca - hb
		var a1 := ca + hb
		if a0 < 0.0:
			# Sıfırın altına sarıyor — ikiye böl
			intervals.append([a0 + TAU, TAU])
			intervals.append([0.0,      a1 ])
		elif a1 > TAU:
			# TAU'nun üstüne sarıyor — ikiye böl
			intervals.append([a0,       TAU     ])
			intervals.append([0.0,      a1 - TAU])
		else:
			intervals.append([a0, a1])

	# Başlangıç açısına göre sırala
	intervals.sort_custom(func(a: Array, b: Array) -> bool:
		return float(a[0]) < float(b[0]))

	# Çakışan aralıkları birleştir
	var merged: Array = []
	for iv in intervals:
		if merged.is_empty():
			merged.append([float(iv[0]), float(iv[1])])
		else:
			var last: Array = merged[merged.size() - 1]
			if float(iv[0]) <= float(last[1]):
				last[1] = maxf(float(last[1]), float(iv[1]))
			else:
				merged.append([float(iv[0]), float(iv[1])])

	# Boşlukları (görünür arları) çiz
	var cursor := 0.0
	for iv in merged:
		if float(iv[0]) > cursor + 0.005:
			_draw_arc_seg(r, cursor, float(iv[0]), width, half, alpha, is_c)
		cursor = float(iv[1])
	if cursor < TAU - 0.005:
		_draw_arc_seg(r, cursor, TAU, width, half, alpha, is_c)


## Tek bir ark segmentini tüm görsel katmanlarıyla çizer.
func _draw_arc_seg(r: float, a_from: float, a_to: float, width: float, half: float, alpha: float, is_c: bool) -> void:
	var span := a_to - a_from
	if span < 0.025:
		return
	var pts := maxi(4, int(span / TAU * 128.0))

	# Siyah/void gövde
	draw_arc(Vector2.ZERO, r, a_from, a_to, pts,
		Color(0.01, 0.00, 0.04, alpha * 0.82), width, true)
	# İç kenar
	draw_arc(Vector2.ZERO, maxf(1.0, r - half), a_from, a_to, pts,
		Color(0.55, 0.72, 1.00, alpha * 0.52) if is_c else Color(0.38, 0.30, 0.88, alpha * 0.48),
		1.0, true)
	# Dış parlak bıçak kenarı
	draw_arc(Vector2.ZERO, r + half, a_from, a_to, pts,
		Color(1.00, 0.94, 0.55, alpha * 0.98) if is_c else Color(0.62, 0.46, 1.00, alpha * 0.96),
		1.3, true)
	# Dış aberration çizgisi
	draw_arc(Vector2.ZERO, r + half + 3.0, a_from, a_to, pts,
		Color(1.00, 0.32, 0.08, alpha * 0.42) if is_c else Color(0.54, 0.22, 0.94, alpha * 0.40),
		0.7, true)


## Dalganın asteroid yüzeyine çarptığı noktada parlak temas flaşı.
func _draw_contact_flash(r: float, ca: float, hb: float, width: float, alpha: float, is_c: bool) -> void:
	var span := minf(hb * 0.55, 0.28)
	draw_arc(Vector2.ZERO, r, ca - span, ca + span, 8,
		Color(1.00, 0.94, 0.55, alpha * 0.92) if is_c else Color(0.70, 0.56, 1.00, alpha * 0.92),
		width * 1.5, true)


## Huygens kırınımı — dalga her gölge kenarından biraz gölgeye bükülür.
## Gerçek dalga fiziği: engel köşesinde yeni dalga kaynağı oluşur, etki azalarak devam eder.
func _draw_diffraction_horns(r: float, ca: float, hb: float, width: float, alpha: float, is_c: bool) -> void:
	# Kırınım derinliği: asteroitin açısal yarıçapıyla orantılı, max ~10°
	var horn := minf(0.175, hb * 0.38)
	if horn < 0.015:
		return
	var col_bright := Color(0.70, 0.56, 1.00) if not is_c else Color(1.00, 0.94, 0.55)
	var col_abrr   := Color(0.54, 0.22, 0.94) if not is_c else Color(1.00, 0.32, 0.08)

	# Sol kenar — ca - hb'den gölgeye doğru (azalan parlaklık)
	for step in range(4):
		var t_step := float(step) / 3.0
		var a0 := ca - hb - horn * (1.0 - t_step)
		var a1 := ca - hb - horn * (t_step * 0.5)
		var h_alpha := alpha * (1.0 - t_step) * 0.62
		if a1 > a0 + 0.005:
			draw_arc(Vector2.ZERO, r, a0, a1, 4,
				Color(col_bright.r, col_bright.g, col_bright.b, h_alpha), width * 0.45, true)
			draw_arc(Vector2.ZERO, r + width * 0.5 + 2.5, a0, a1, 4,
				Color(col_abrr.r, col_abrr.g, col_abrr.b, h_alpha * 0.5), 0.6, true)

	# Sağ kenar — ca + hb'den gölgeye doğru
	for step in range(4):
		var t_step := float(step) / 3.0
		var a0 := ca + hb + horn * (t_step * 0.5)
		var a1 := ca + hb + horn * (1.0 - t_step)
		var h_alpha := alpha * (1.0 - t_step) * 0.62
		if a1 > a0 + 0.005:
			draw_arc(Vector2.ZERO, r, a0, a1, 4,
				Color(col_bright.r, col_bright.g, col_bright.b, h_alpha), width * 0.45, true)
			draw_arc(Vector2.ZERO, r + width * 0.5 + 2.5, a0, a1, 4,
				Color(col_abrr.r, col_abrr.g, col_abrr.b, h_alpha * 0.5), 0.6, true)


# ── Yardımcı ──────────────────────────────────────────────────────────────────

func _get_max_radius() -> float:
	var p := get_parent()
	if p != null and p.has_method("get_damage_aura_radius"):
		return float(p.call("get_damage_aura_radius"))
	return 100.0
