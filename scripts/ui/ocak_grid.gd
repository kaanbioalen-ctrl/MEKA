extends Node2D
## Polar sektör gridi — Ocak ekranının görsel iskeleti.
## Tasarım referansı: singularity-grid_-polar-slots/src/App.tsx
##
## Matematik (App.tsx ile birebir):
##   LAYERS = 5, R_START = 100, DR = 50, TARGET_ARC_LENGTH = 50
##   rMid     = R_START + layerIdx * DR + DR / 2
##   segCount = round(2π * rMid / TARGET_ARC_LENGTH)
##   → Layer 0: ~13 seg  (rMid=125)
##   → Layer 1: ~20 seg  (rMid=175)
##   → Layer 2: ~26 seg  (rMid=225)
##   → Layer 3: ~33 seg  (rMid=275)
##   → Layer 4: ~40 seg  (rMid=325)
##   Toplam: ~132 sektör

const LAYERS:             int   = 5
const R_START:            float = 100.0
const DR:                 float = 50.0
const TARGET_ARC_LENGTH:  float = 50.0
const ARC_STEPS:          int   = 10   # Sektör poligonu başına yay adımı

# Sektör verisi: her eleman { a_start, a_end, pts } sözlüğüdür
var _sectors: Array = []

var _time: float = 0.0


func _ready() -> void:
	_compute_grid()


# ── Grid Hesabı ────────────────────────────────────────────────────────────────

func _compute_grid() -> void:
	_sectors.clear()

	for l in range(LAYERS):
		var r_inner := R_START + l * DR
		var r_outer := r_inner + DR
		var r_mid   := r_inner + DR * 0.5
		var seg_count := int(round(TAU * r_mid / TARGET_ARC_LENGTH))
		if seg_count < 1:
			seg_count = 1
		var angle_step := TAU / float(seg_count)

		for i in range(seg_count):
			var a_start := float(i) * angle_step - PI * 0.5       # -90° offset: 0° yukarı
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
	# 1. Arka plan konsantrik çemberler (App.tsx: 6 çember, rgba(255,255,255,0.03), 1px)
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

	# 4. Event horizon glow — merkez silinmeden önce (App.tsx: 70%→100% morumsu)
	for i in range(12):
		var t  := float(i) / 12.0
		var r  := R_START * (0.70 + t * 0.30)
		var a  := t * t * 0.18
		draw_circle(Vector2.ZERO, r, Color(0.545, 0.361, 0.965, a))

	# 5. Merkez abyss — siyah disk (glow üstüne çizilir, gradient kenarı dışarıda kalır)
	draw_circle(Vector2.ZERO, R_START, Color(0.0, 0.0, 0.0, 1.0))

	# Nefes animasyonu: stroke opaklığı ve yarıçap pulse
	var pulse    := 1.0 + sin(_time * PI / 4.0) * 0.025
	var stroke_a := lerpf(0.1, 0.3, (sin(_time * PI / 4.0) + 1.0) * 0.5)
	draw_arc(Vector2.ZERO, R_START * pulse, 0.0, TAU, 64,
			Color(1.0, 1.0, 1.0, stroke_a), 2.0)

	# 6. Merkez dönen yay (App.tsx: CircleDot, 20s tam dönüş, opacity 0.10)
	var rot_angle := _time * (TAU / 20.0)
	draw_arc(Vector2.ZERO, 16.0, rot_angle, rot_angle + TAU * 0.75,
			24, Color(1.0, 1.0, 1.0, 0.10), 1.5)
