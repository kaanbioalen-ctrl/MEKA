extends Node2D
## Polar sektör gridi — Ocak ekranının görsel iskeleti.
##
## Yapı:
##   CENTER_R = 20  → merkez kara delik yarıçapı
##   R_START  = 80  → ilk halka iç kenarı
##   DR       = 90  → halka genişliği
##   Katman 0: 4  simetrik segment
##   Katman 1: 8  segment
##   Katman 2: 16 segment

const CENTER_R:  float = 20.0          # merkez kara delik yarıçapı
const R_START:   float = 80.0          # ilk halkanın iç yarıçapı
const DR:        float = 90.0          # halka genişliği
const LAYERS:    int   = 3
const SEG_COUNTS: Array = [4, 8, 16]   # katman başına sabit segment sayısı
const ARC_STEPS:  int   = 10           # sektör poligonu başına yay adımı

# Sektör verisi: her eleman { a_start, a_end, pts } sözlüğüdür
var _sectors: Array = []

var _time: float = 0.0


func _ready() -> void:
	_compute_grid()


# ── Grid Hesabı ────────────────────────────────────────────────────────────────

func _compute_grid() -> void:
	_sectors.clear()

	for l in range(LAYERS):
		var r_inner    := R_START + l * DR
		var r_outer    := r_inner + DR
		var seg_count  := int(SEG_COUNTS[l])
		var angle_step := TAU / float(seg_count)

		for i in range(seg_count):
			var a_start := float(i) * angle_step - PI * 0.5   # -90° offset: 0° yukarı
			var a_end   := float(i + 1) * angle_step - PI * 0.5
			_sectors.append({
				"a_start": a_start,
				"a_end":   a_end,
				"pts":     _sector_pts(r_inner, r_outer, a_start, a_end),
			})


func _sector_pts(r_in: float, r_out: float, a_start: float, a_end: float) -> PackedVector2Array:
	var pts := PackedVector2Array()

	# Dış yay: a_start → a_end, r_out (saat yönü)
	for i in range(ARC_STEPS + 1):
		var t  := float(i) / float(ARC_STEPS)
		var a  := lerpf(a_start, a_end, t)
		pts.append(Vector2(cos(a) * r_out, sin(a) * r_out))

	# İç yay: a_end → a_start, r_in (saat yönü tersi)
	for i in range(ARC_STEPS + 1):
		var t  := float(i) / float(ARC_STEPS)
		var a  := lerpf(a_end, a_start, t)
		pts.append(Vector2(cos(a) * r_in, sin(a) * r_in))

	return pts


# ── Güncelleme ─────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


# ── Çizim ──────────────────────────────────────────────────────────────────────

func _draw() -> void:
	# 1. Arka plan konsantrik çemberler — halka kenarları + merkez çemberi
	draw_arc(Vector2.ZERO, CENTER_R, 0.0, TAU, 48,
			Color(1.0, 1.0, 1.0, 0.03), 1.0)
	for i in range(LAYERS + 1):
		draw_arc(Vector2.ZERO, R_START + i * DR, 0.0, TAU, 64,
				Color(1.0, 1.0, 1.0, 0.03), 1.0)

	# 2 & 3. Sektörler — fill (transparan) + stroke
	var stroke_color := Color(1.0, 1.0, 1.0, 0.05)
	for sector in _sectors:
		var pts: PackedVector2Array = sector["pts"]

		# Stroke: kapalı polyline
		var closed := PackedVector2Array(pts)
		closed.append(pts[0])
		draw_polyline(closed, stroke_color, 1.0, true)

	# 4. Event horizon glow — CENTER_R ile R_START arası morumsu hale
	for i in range(12):
		var t  := float(i) / 12.0
		var r  := CENTER_R + (R_START - CENTER_R) * t
		var a  := t * t * 0.22
		draw_circle(Vector2.ZERO, r, Color(0.545, 0.361, 0.965, a))

	# 5. Merkez abyss — siyah disk (r = CENTER_R)
	draw_circle(Vector2.ZERO, CENTER_R, Color(0.0, 0.0, 0.0, 1.0))

	# Nefes animasyonu: CENTER_R etrafında pulse
	var pulse    := 1.0 + sin(_time * PI / 4.0) * 0.025
	var stroke_a := lerpf(0.1, 0.3, (sin(_time * PI / 4.0) + 1.0) * 0.5)
	draw_arc(Vector2.ZERO, CENTER_R * pulse, 0.0, TAU, 48,
			Color(1.0, 1.0, 1.0, stroke_a), 2.0)

	# 6. Merkez dönen yay (CENTER_R içinde, 20s tam dönüş)
	var rot_angle := _time * (TAU / 20.0)
	draw_arc(Vector2.ZERO, CENTER_R * 0.70, rot_angle, rot_angle + TAU * 0.75,
			24, Color(1.0, 1.0, 1.0, 0.10), 1.5)
