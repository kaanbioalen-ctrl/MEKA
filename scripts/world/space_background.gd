extends Node2D
## Multi-layer procedural star field with organic density variation.
##
## Density map per position:
##   void_factor   – several seeded empty regions near zero density
##   noise_factor  – smooth FBM noise, creates sparse vs. slightly denser patches
##   nebula_factor – milky-way band centre suppresses stars (gas cloud occlusion)
##
## Stars inside the nebula band are both fewer AND dimmer.
## Overall count is ~50% lower than a uniform fill of the same area.

const SCREEN_W  := 1920.0
const SCREEN_H  := 1080.0
const SEED_BASE := 55813

## Milky-way band direction (matches shader normalize(vec2(1,1)))
const BAND_NX := 0.70711
const BAND_NY := 0.70711

## Void regions: [center_u, center_v, radius_u, radius_v]
## Seeded so they are deterministic. Spread deliberately off-centre.
const VOID_DEFS: Array = [
	[0.18, 0.72, 0.11, 0.09],
	[0.78, 0.20, 0.10, 0.12],
	[0.55, 0.55, 0.09, 0.08],
	[0.08, 0.30, 0.08, 0.10],
	[0.88, 0.75, 0.12, 0.09],
]

## [count, parallax, r_min, r_max, a_min, a_max, warm_accent]
const LAYER_CFG := [
	[45,  0.025, 0.50, 1.10, 0.07, 0.22, false],  # A – micro, very far
	[28,  0.110, 1.0,  2.00, 0.18, 0.48, false],  # B – main field
	[13,  0.260, 1.5,  2.80, 0.34, 0.72, false],  # C – closer
	[6,   0.420, 2.2,  4.00, 0.55, 0.90, true ],  # D – warm accent, pulsing
]

## Per layer: PackedFloat32Array, 7 floats per star.
## [uv_x, uv_y, radius, col_r, col_g, col_b, pulse_phase]
var _layers: Array[PackedFloat32Array] = []
## Base alpha stored separately for pulse modulation.
var _alphas: Array[PackedFloat32Array] = []

var _player: Node2D = null
var _time:   float  = 0.0


func _ready() -> void:
	_generate_stars()


# ── Density helpers ────────────────────────────────────────────────────────────

## Integer hash → [0, 1)
func _ihash(ix: int, iy: int) -> float:
	var h: int = ix * 1619 + iy * 31337 + SEED_BASE
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return absf(float(h & 0x7FFFFFFF) / 2147483647.0)


## Smooth value noise at float coords.
func _vnoise(px: float, py: float) -> float:
	var ix := int(floor(px))
	var iy := int(floor(py))
	var fx := fposmod(px, 1.0)
	var fy := fposmod(py, 1.0)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := _ihash(ix,     iy    )
	var b := _ihash(ix + 1, iy    )
	var c := _ihash(ix,     iy + 1)
	var d := _ihash(ix + 1, iy + 1)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


## 3-octave FBM noise → roughly [0, 1].
func _fbm(px: float, py: float) -> float:
	return (
		_vnoise(px,        py       ) * 0.56 +
		_vnoise(px * 2.1,  py * 2.1 ) * 0.30 +
		_vnoise(px * 4.6,  py * 4.6 ) * 0.14
	)


## Smooth step remapping.
func _ss(edge0: float, edge1: float, x: float) -> float:
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Returns [density, nebula_weight] at (u, v) in [0,1]² space.
## density  – acceptance probability for placing a star (0 = empty, 1 = normal)
## nebula_w – how deep inside the nebula core this point is (used for alpha dim)
func _density_at(u: float, v: float) -> Vector2:
	# ── 1. Void regions ───────────────────────────────────────────────────────
	var void_f := 1.0
	for vd: Array in VOID_DEFS:
		var du := (u - float(vd[0])) / float(vd[2])
		var dv := (v - float(vd[1])) / float(vd[3])
		var dist := sqrt(du * du + dv * dv)   # ellipse distance
		# Soft edge: full void inside r=1, blends to open at r=1.6
		void_f *= _ss(1.0, 1.6, dist)
	if void_f < 0.01:
		return Vector2(0.0, 0.0)

	# ── 2. Smooth noise – organic sparse / denser patches ─────────────────────
	var noise_raw := _fbm(u * 3.8 + 1.3, v * 3.8 + 0.7)
	# Map [0,1] to [0.05, 1.3]: mostly sparse with rare peaks
	var noise_f   := clampf(noise_raw * 1.35 - 0.12, 0.05, 1.3)

	# ── 3. Nebula band suppression ─────────────────────────────────────────────
	# The milky-way gas cloud obscures stars at its core.
	var bt        := (u - 0.5) * BAND_NX + (v - 0.5) * BAND_NY
	var nebula_w  := exp(-bt * bt * 90.0)          # very tight core
	var nebula_f  := 1.0 - nebula_w * 0.88         # up to 88 % suppression at centre

	var density := void_f * noise_f * nebula_f
	return Vector2(density, nebula_w)


# ── Star generation ────────────────────────────────────────────────────────────

func _generate_stars() -> void:
	var rng := RandomNumberGenerator.new()
	_layers.resize(LAYER_CFG.size())
	_alphas.resize(LAYER_CFG.size())

	for li in range(LAYER_CFG.size()):
		var cfg  : Array = LAYER_CFG[li]
		rng.seed = SEED_BASE + li * 7919

		var n     : int   = cfg[0]
		var r_min : float = cfg[2]
		var r_max : float = cfg[3]
		var a_min : float = cfg[4]
		var a_max : float = cfg[5]
		var warm  : bool  = cfg[6]

		var data      := PackedFloat32Array()
		var alpha_arr := PackedFloat32Array()
		data.resize(n * 7)
		alpha_arr.resize(n)

		for i in range(n):
			# ── Density-weighted placement ─────────────────────────────────────
			var u        := 0.0
			var v        := 0.0
			var nebula_w := 0.0
			for _try in range(80):
				u = rng.randf()
				v = rng.randf()
				var dv := _density_at(u, v)
				nebula_w = dv.y
				if rng.randf() < dv.x:
					break

			var b := i * 7
			data[b + 0] = u
			data[b + 1] = v
			data[b + 2] = rng.randf_range(r_min, r_max)

			# Stars inside nebula are dimmer (gas occlusion)
			var nebula_dim := 1.0 - nebula_w * 0.60
			var base_a     := rng.randf_range(a_min, a_max) * nebula_dim
			alpha_arr[i]   = base_a

			var col: Color
			if warm:
				col = Color.from_hsv(
					rng.randf_range(0.08, 0.17),
					rng.randf_range(0.10, 0.28),
					rng.randf_range(0.92, 1.00),
					base_a)
			else:
				col = Color.from_hsv(
					rng.randf_range(0.57, 0.67),
					rng.randf_range(0.04, 0.14),
					rng.randf_range(0.80, 1.00),
					base_a)

			data[b + 3] = col.r
			data[b + 4] = col.g
			data[b + 5] = col.b
			data[b + 6] = rng.randf() * TAU   # pulse phase

		_layers[li] = data
		_alphas[li]  = alpha_arr


# ── Runtime ────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_time += delta
	_resolve_player()
	queue_redraw()


func _resolve_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	var tree := get_tree()
	if tree == null:
		return
	var p := tree.get_first_node_in_group("player")
	if p is Node2D:
		_player = p as Node2D


func _draw() -> void:
	var cam := Vector2.ZERO
	if _player != null and is_instance_valid(_player):
		# accumulated_position: wrap olmayan sürekli koordinat.
		# global_position wrap anında zıplar ve parallax'ın da zıplamasına yol açar.
		if _player.get("accumulated_position") != null:
			cam = _player.accumulated_position
		else:
			cam = _player.global_position

	for li in range(_layers.size()):
		var cfg      : Array             = LAYER_CFG[li]
		var parallax : float             = cfg[1]
		var is_warm  : bool              = cfg[6]
		var data     : PackedFloat32Array = _layers[li]
		var alpha_arr: PackedFloat32Array = _alphas[li]
		var n        : int               = cfg[0]

		var su := fposmod(cam.x * parallax / SCREEN_W, 1.0)
		var sv := fposmod(cam.y * parallax / SCREEN_H, 1.0)

		for i in range(n):
			var b  := i * 7
			var sx := fposmod(data[b + 0] - su, 1.0) * SCREEN_W
			var sy := fposmod(data[b + 1] - sv, 1.0) * SCREEN_H

			var alpha := alpha_arr[i]
			if is_warm:
				alpha *= 0.72 + 0.28 * sin(_time * 1.75 + data[b + 6])

			draw_circle(Vector2(sx, sy), data[b + 2],
				Color(data[b + 3], data[b + 4], data[b + 5], alpha))
