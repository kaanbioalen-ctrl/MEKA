extends Node2D
## Gravitasyonel anomali görsel — dalga sistemiyle aynı dil.
## Void core + event horizon ring + distortion band + outer gravity well.
## Enerji düşünce event horizon titreşir; storm/overload'da tint rengi değişir.

var _time:    float = 0.0
var _ratio:   float = 1.0   # enerji oranı 0–1
var _boosted: float = 1.0   # player.gd'den gelen parlaklık çarpanı
var _tint:    Color = Color(0.97, 0.95, 1.00)  # beyaz/gümüş — state'e göre değişir


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Player'ın _update_energy_visual()'ı her frame bu metodu çağırır.
func set_visual_state(ratio: float, boosted: float, tint: Color) -> void:
	_ratio   = ratio
	_boosted = boosted
	_tint    = tint


func _draw() -> void:
	# Parlaklığı 0–1.8 aralığına normalize et
	var b := clampf(_boosted / 1.6, 0.05, 1.8)

	_draw_outer_gravity_well(b)
	_draw_distortion_band(b)
	_draw_event_horizon(b)
	_draw_void_core()


# ── Katmanlar ──────────────────────────────────────────────────────────────────

func _draw_outer_gravity_well(b: float) -> void:
	# Çok soluk, büyük karanlık alan — gravitasyonel etki alanı hissi
	var r := 24.0 + sin(_time * 0.72) * 1.6
	draw_circle(Vector2.ZERO, r, Color(0.02, 0.00, 0.08, b * 0.10))
	# Çok ince tint-renkli dış rim
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48,
		Color(_tint.r * 0.28, _tint.g * 0.22, _tint.b * 0.38, b * 0.20), 0.8, true)


func _draw_distortion_band(b: float) -> void:
	# Karanlık halka gövdesi + ince parlak dış kenar — dalgayla aynı dil
	var r    := 15.2 + sin(_time * 1.12) * 0.55
	var w    := 3.8
	var band_a := b * 0.84

	# Siyah/void gövde
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 80,
		Color(0.01, 0.00, 0.04, band_a * 0.88), w, true)

	# Dış bıçak kenarı — tint rengiyle (dalganın event horizon'ıyla uyumlu)
	draw_arc(Vector2.ZERO, r + w * 0.52, 0.0, TAU, 80,
		Color(_tint.r * 0.40, _tint.g * 0.34, _tint.b * 0.95, band_a * 0.50), 0.9, true)


func _draw_event_horizon(b: float) -> void:
	# Bıçak gibi ince parlak halka — anomalinin "yüzeyi"
	var r   := 10.6 + sin(_time * 2.05) * 0.65
	var eh_a := clampf(b * 0.96, 0.0, 1.0)

	# Düşük enerjide titreyerek solar — anomali dengesizleşiyor
	if _ratio < 0.30:
		var flicker := sin(_time * 17.0 + 1.4) * 0.5 + 0.5
		eh_a *= lerpf(0.12, 1.0, flicker * (_ratio / 0.30))

	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64,
		Color(_tint.r, _tint.g, _tint.b, eh_a), 1.4, true)

	# İç soluk gölge — event horizon'ın derinliği
	draw_arc(Vector2.ZERO, maxf(1.0, r - 2.0), 0.0, TAU, 48,
		Color(_tint.r * 0.18, _tint.g * 0.14, _tint.b * 0.32, eh_a * 0.35), 1.0, true)


func _draw_void_core() -> void:
	# Tam siyah merkez — gravitasyonel singularity
	var r := 8.2 + sin(_time * 1.82) * 0.38
	draw_circle(Vector2.ZERO, r, Color(0.00, 0.00, 0.02, 0.97))
