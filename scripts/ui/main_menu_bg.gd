extends Control
## Ana menü arka plan — yıldız sahası + nebula glow.
## Overlay'in altında, oyun dünyasının üstünde render edilir.

var _stars : Array = []
var _blobs  : Array = []
var _time   : float = 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_generate(RandomNumberGenerator.new())


func _generate(rng: RandomNumberGenerator) -> void:
	rng.seed = 9182736455

	# Yıldızlar
	for i in range(220):
		_stars.append({
			"px"    : rng.randf(),
			"py"    : rng.randf(),
			"r"     : rng.randf_range(0.7, 2.1),
			"phase" : rng.randf() * TAU,
			"speed" : rng.randf_range(0.25, 1.1),
			"base"  : rng.randf_range(0.12, 0.50),
			"cold"  : rng.randf() > 0.75,   # bazıları sıcak beyaz, bazıları soğuk mavi
		})

	# Büyük nebula blob'ları
	for i in range(5):
		_blobs.append({
			"px"    : rng.randf(),
			"py"    : rng.randf(),
			"r"     : rng.randf_range(180.0, 380.0),
			"alpha" : rng.randf_range(0.025, 0.065),
			"hue"   : rng.randf(),  # 0=mavi/mor, 1=kırmızı
		})


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var sz := size

	# Nebula blob'ları — çok soluk, geniş
	for b in _blobs:
		var pos := Vector2(float(b["px"]) * sz.x, float(b["py"]) * sz.y)
		var hue  := float(b["hue"])
		var col  := Color(0.10 + hue * 0.25, 0.04, 0.30 - hue * 0.12, float(b["alpha"]))
		draw_circle(pos, float(b["r"]), col)

	# Merkez void glow — panelin arkasında soluk bir ışık
	var cx := sz.x * 0.5
	var cy := sz.y * 0.5
	draw_circle(Vector2(cx, cy), sz.length() * 0.38, Color(0.08, 0.02, 0.22, 0.10))
	draw_circle(Vector2(cx, cy), sz.length() * 0.18, Color(0.12, 0.04, 0.30, 0.08))

	# Yıldızlar
	for s in _stars:
		var pos   := Vector2(float(s["px"]) * sz.x, float(s["py"]) * sz.y)
		var alpha := float(s["base"]) * (0.55 + 0.45 * sin(_time * float(s["speed"]) + float(s["phase"])))
		var col   : Color
		if bool(s["cold"]):
			col = Color(0.70, 0.82, 1.00, alpha)
		else:
			col = Color(0.95, 0.95, 1.00, alpha)
		draw_circle(pos, float(s["r"]), col)

	# Köşe vignette — 4 kenarda koyu gradyan hissi (üst üste şeffaf dikdörtgenler)
	var vig_depth := 220.0
	var steps     := 12
	for i in range(steps):
		var t := float(i) / float(steps)
		var a := (1.0 - t) * (1.0 - t) * 0.28
		# Üst
		draw_rect(Rect2(0, 0, sz.x, vig_depth * (1.0 - t)),
			Color(0.00, 0.00, 0.02, a), true)
		# Alt
		draw_rect(Rect2(0, sz.y - vig_depth * (1.0 - t), sz.x, vig_depth * (1.0 - t)),
			Color(0.00, 0.00, 0.02, a), true)
		# Sol
		draw_rect(Rect2(0, 0, vig_depth * (1.0 - t), sz.y),
			Color(0.00, 0.00, 0.02, a * 0.6), true)
		# Sağ
		draw_rect(Rect2(sz.x - vig_depth * (1.0 - t), 0, vig_depth * (1.0 - t), sz.y),
			Color(0.00, 0.00, 0.02, a * 0.6), true)
