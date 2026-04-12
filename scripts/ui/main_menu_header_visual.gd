extends Control
## Ana menü başlık görseli — tam orbit halkaları + canlı void çekirdek.
## Ölüm ekranından farklı: halkalar kırık değil, yavaşça döner. Başlangıç hissi.

var _time: float = 0.0
var _fade: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	_fade = minf(_fade + delta / 0.7, 1.0)
	queue_redraw()


func _draw() -> void:
	var t  := _fade
	var cx := size.x * 0.5
	var cy := size.y * 0.5
	var c  := Vector2(cx, cy)

	# Dış gravity well — çok soluk
	draw_circle(c, 52.0, Color(0.02, 0.00, 0.08, t * 0.12))

	# Dış yavaş dönen halo
	var halo_r := 46.0 + sin(_time * 0.6) * 2.2
	draw_arc(c, halo_r, _time * 0.18, _time * 0.18 + TAU, 64,
		Color(0.38, 0.30, 0.88, t * 0.22), 0.9, true)

	# Dış orbit halkası — tam, yavaş döner
	var r_outer := 34.0 + sin(_time * 0.5) * 0.8
	draw_arc(c, r_outer, 0.0, TAU, 80,
		Color(0.01, 0.00, 0.04, t * 0.88), 5.0, true)
	draw_arc(c, r_outer + 2.8, 0.0, TAU, 80,
		Color(0.55, 0.72, 1.00, t * 0.75), 1.0, true)
	draw_arc(c, r_outer + 5.0, 0.0, TAU, 80,
		Color(0.88, 0.14, 0.62, t * 0.28), 0.65, true)

	# İç orbit halkası — biraz daha hızlı, ters yön
	var r_inner := 20.0 + sin(_time * 0.9 + 1.2) * 0.6
	draw_arc(c, r_inner, -_time * 0.25, -_time * 0.25 + TAU, 56,
		Color(0.01, 0.00, 0.04, t * 0.70), 3.2, true)
	draw_arc(c, r_inner + 1.8, -_time * 0.25, -_time * 0.25 + TAU, 56,
		Color(0.60, 0.75, 1.00, t * 0.60), 0.8, true)

	# Event horizon
	var r_eh := 11.0 + sin(_time * 2.1) * 0.55
	draw_arc(c, r_eh, 0.0, TAU, 48,
		Color(0.88, 0.90, 1.00, t * 0.88), 1.3, true)
	draw_arc(c, r_eh - 2.0, 0.0, TAU, 48,
		Color(0.20, 0.16, 0.40, t * 0.32), 1.0, true)

	# Void çekirdek
	draw_circle(c, 8.5 + sin(_time * 1.8) * 0.35, Color(0.00, 0.00, 0.02, 0.97))

	# Dönen partiküller — dış yörüngede
	for i in range(5):
		var angle := _time * 0.55 + float(i) * TAU / 5.0
		var pr    := 38.0 + sin(_time * 1.1 + float(i) * 1.3) * 3.5
		var pt    := c + Vector2(cos(angle), sin(angle)) * pr
		draw_circle(pt, 1.4, Color(0.60, 0.75, 1.00, t * 0.55))

	# İç yörünge partikülleri — ters yön
	for i in range(3):
		var angle := -_time * 0.80 + float(i) * TAU / 3.0
		var pr    := 24.0 + sin(_time * 1.6 + float(i) * 2.0) * 2.0
		var pt    := c + Vector2(cos(angle), sin(angle)) * pr
		draw_circle(pt, 1.0, Color(0.88, 0.14, 0.62, t * 0.40))
