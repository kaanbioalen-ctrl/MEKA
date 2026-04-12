extends Control
## Panel kenar glow — çok ince, void temasıyla uyumlu.
## Panel root'un tam üstüne yerleşir, tıklamaları geçirir.

var _time: float = 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var r   := Rect2(Vector2.ZERO, size)
	var pulse := 0.85 + 0.15 * sin(_time * 0.9)

	# Dış glow katmanları — soldan sağa azalan alpha
	var glow_col := Color(0.38, 0.44, 0.90)
	for i in range(6):
		var m := float(i) * 2.8
		var a := (0.14 - float(i) * 0.022) * pulse
		if a <= 0.0:
			break
		draw_rect(
			Rect2(r.position - Vector2(m, m), r.size + Vector2(m * 2.0, m * 2.0)),
			Color(glow_col.r, glow_col.g, glow_col.b, a), false, 1.0)

	# İç parlak çizgi
	draw_rect(r, Color(0.55, 0.65, 1.00, 0.28 * pulse), false, 1.0)

	# Köşe accent — aberration rengi
	var corner := 18.0
	var ca     := Color(0.88, 0.14, 0.62, 0.30 * pulse)
	# Üst-sol
	draw_line(r.position,                         r.position + Vector2(corner, 0),  ca, 1.2)
	draw_line(r.position,                         r.position + Vector2(0, corner),  ca, 1.2)
	# Üst-sağ
	draw_line(r.position + Vector2(r.size.x, 0),  r.position + Vector2(r.size.x - corner, 0), ca, 1.2)
	draw_line(r.position + Vector2(r.size.x, 0),  r.position + Vector2(r.size.x, corner),      ca, 1.2)
	# Alt-sol
	draw_line(r.position + Vector2(0, r.size.y),  r.position + Vector2(corner, r.size.y),       ca, 1.2)
	draw_line(r.position + Vector2(0, r.size.y),  r.position + Vector2(0, r.size.y - corner),   ca, 1.2)
	# Alt-sağ
	draw_line(r.end,                              r.end - Vector2(corner, 0),  ca, 1.2)
	draw_line(r.end,                              r.end - Vector2(0, corner),  ca, 1.2)
