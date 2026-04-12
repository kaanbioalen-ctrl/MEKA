extends Control
## Ölüm ekranı başlık görseli — kırık orbit halkası + void çekirdek.
## Animasyonlu: draw_t 0→1 arası açılış animasyonu, sonra idle döngüsü.

var _time  : float = 0.0
var _draw_t: float = 0.0


func start() -> void:
	_draw_t = 0.0
	_time   = 0.0


func _process(delta: float) -> void:
	_time += delta
	if _draw_t < 1.0:
		_draw_t = minf(_draw_t + delta / 0.55, 1.0)
	queue_redraw()


func _draw() -> void:
	var t      := _draw_t
	var center := size * 0.5

	# Void çekirdek
	draw_circle(center, 8.0, Color(0.00, 0.00, 0.02, 0.97))
	draw_arc(center, 10.5, 0.0, TAU, 48,
		Color(0.60, 0.75, 1.00, t * 0.75), 1.3, true)

	# Kırık orbit halkası — 3 segment, aralarında boşluk
	var segments: Array = [
		[0.0,       PI * 0.62],
		[PI * 0.75, PI * 1.52],
		[PI * 1.64, TAU - 0.15]
	]
	for seg in segments:
		var from_a := float(seg[0])
		var to_a   := float(seg[1])
		var span   := to_a - from_a
		var drawn  := clampf(t * 1.8 - from_a / TAU * 0.6, 0.0, 1.0)
		if drawn <= 0.0:
			continue
		var a_to := from_a + span * drawn

		draw_arc(center, 28.0, from_a, a_to, 32,
			Color(0.01, 0.00, 0.04, 0.85), 5.5, true)
		draw_arc(center, 30.8, from_a, a_to, 32,
			Color(0.60, 0.75, 1.00, t * 0.92), 1.1, true)
		draw_arc(center, 33.2, from_a, a_to, 32,
			Color(0.88, 0.14, 0.62, t * 0.38), 0.65, true)

	# Soluk dış halo
	var halo_r := 42.0 + sin(_time * 0.85) * 1.8
	draw_arc(center, halo_r, 0.0, TAU, 64,
		Color(0.38, 0.30, 0.88, t * 0.22), 0.8, true)

	# Dökülen partiküller
	for i in range(6):
		var angle := _time * 0.38 + float(i) * TAU / 6.0
		var pr    := 40.0 + sin(_time * 1.4 + float(i)) * 4.5
		var pt    := center + Vector2(cos(angle), sin(angle)) * pr
		draw_circle(pt, 1.2, Color(0.60, 0.75, 1.00, t * 0.50))
