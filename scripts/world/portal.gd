extends Area2D
class_name Portal

## Bidirectional portal — renk ve etiket export ile özelleştirilebilir.

const DEFAULT_TARGET_SCENE: String = "res://scenes/world/world2.tscn"
const RADIUS: float = 55.0
const PULSE_SPEED: float = 2.2
const RING_COUNT: int = 4
const SPIN_SPEED: float = 0.8
const APPEAR_DURATION: float = 1.2

@export var player_group: StringName = &"player"
@export_file("*.tscn") var target_scene: String = DEFAULT_TARGET_SCENE
## Portalın ana rengi. Tüm çizim renkleri buradan türetilir.
@export var portal_color: Color = Color(0.18, 0.72, 1.0)
## Portalın altında görünen kısa etiket ("GATE", "TEST" vb.)
@export var label_text: String = "GATE"

var _visual_t: float = 0.0
var _appear_t: float = 0.0
var _spin_angle: float = 0.0
var _active: bool = false


func _ready() -> void:
	monitoring = true
	monitorable = false
	add_to_group("portal")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	queue_redraw()


func _process(delta: float) -> void:
	_visual_t += delta * PULSE_SPEED
	_spin_angle += delta * SPIN_SPEED
	if _appear_t < 1.0:
		_appear_t = minf(_appear_t + delta / APPEAR_DURATION, 1.0)
		if _appear_t >= 1.0:
			_active = true
	queue_redraw()


func _draw() -> void:
	var alpha_scale := _ease_out(_appear_t)
	var pulse       := sin(_visual_t) * 0.5 + 0.5
	var inner_pulse := sin(_visual_t * 1.7 + 1.0) * 0.5 + 0.5
	var drift_pulse := sin(_visual_t * 0.7 + 0.8) * 0.5 + 0.5

	# Portalın renk ailesi portal_color'ın tonu korunarak türetilir.
	var h := portal_color.h
	var s := portal_color.s
	var v := portal_color.v

	# ── Dış bloom ────────────────────────────────────────────────────────────
	var bloom_r := RADIUS * (1.72 + pulse * 0.28)
	draw_circle(Vector2.ZERO, bloom_r,
		Color.from_hsv(h, s * 0.85, v * 0.18, 0.11 * alpha_scale))
	draw_circle(Vector2.ZERO, RADIUS * (1.28 + drift_pulse * 0.10),
		Color.from_hsv(h, s * 0.88, v * 0.60, 0.08 * alpha_scale))

	# ── Halo halkaları ────────────────────────────────────────────────────────
	for i in range(3):
		var t := float(i) / 2.0
		var halo_r := RADIUS * lerpf(1.18, 1.52, t)
		var halo_a := lerpf(0.12, 0.02, t) * alpha_scale * (0.75 + pulse * 0.35)
		draw_arc(Vector2.ZERO, halo_r, 0.0, TAU, 72,
			Color.from_hsv(h, s, v, halo_a), lerpf(3.2, 1.1, t), true)

	# ── İç renkten dışa doğru soluk renk degradesi ───────────────────────────
	for i in range(RING_COUNT):
		var t     := float(i) / float(RING_COUNT)
		var r     := RADIUS * lerpf(0.58, 1.02, t)
		var width := lerpf(2.4, 0.8, t)
		var ring_alpha := lerpf(0.85, 0.18, t) * alpha_scale
		var col := Color.from_hsv(
			h,
			lerpf(clampf(s * 0.35, 0.0, 1.0), clampf(s * 0.90, 0.0, 1.0), t),
			lerpf(clampf(v * 0.92 + 0.08, 0.0, 1.0), clampf(v * 0.90, 0.0, 1.0), t),
			ring_alpha * lerpf(0.72, 0.34, pulse)
		)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 80, col, width, true)

	# ── Dönen dış segmentler ─────────────────────────────────────────────────
	var seg_count := 6
	for i in range(seg_count):
		var base_angle := _spin_angle + TAU * float(i) / float(seg_count)
		var arc_span   := PI * 0.22
		var seg_r      := RADIUS * 1.08
		var seg_alpha  := (0.34 + inner_pulse * 0.24) * alpha_scale
		draw_arc(Vector2.ZERO, seg_r, base_angle, base_angle + arc_span, 24,
			Color.from_hsv(h, clampf(s * 0.12, 0.0, 1.0), 0.95, seg_alpha), 1.8, true)

	# ── Ters dönen iç segmentler ──────────────────────────────────────────────
	for i in range(seg_count):
		var base_angle := -_spin_angle * 1.3 + TAU * float(i) / float(seg_count)
		var arc_span   := PI * 0.14
		var seg_r      := RADIUS * 0.80
		var seg_alpha  := (0.26 + pulse * 0.16) * alpha_scale
		draw_arc(Vector2.ZERO, seg_r, base_angle, base_angle + arc_span, 18,
			Color.from_hsv(h, clampf(s * 0.85, 0.0, 1.0), v, seg_alpha), 1.2, true)

	# ── Çekirdek ──────────────────────────────────────────────────────────────
	var core_r := RADIUS * 0.42 * (1.0 + inner_pulse * 0.12)
	draw_circle(Vector2.ZERO, core_r * 1.34,
		Color.from_hsv(h, s * 0.72, v * 0.12, (0.28 + inner_pulse * 0.10) * alpha_scale))
	draw_circle(Vector2.ZERO, core_r,
		Color.from_hsv(h, s * 0.78, v * 0.62, (0.24 + inner_pulse * 0.18) * alpha_scale))
	draw_circle(Vector2.ZERO, core_r * 0.48,
		Color.from_hsv(h, clampf(s * 0.10, 0.0, 1.0), 0.96, (0.55 + pulse * 0.25) * alpha_scale))

	# ── Flare ─────────────────────────────────────────────────────────────────
	var flare_alpha := (0.10 + pulse * 0.06) * alpha_scale
	draw_line(Vector2(-RADIUS * 0.62, 0.0), Vector2(RADIUS * 0.62, 0.0),
		Color.from_hsv(h, clampf(s * 0.28, 0.0, 1.0), 0.96, flare_alpha), 1.2, true)
	draw_line(Vector2(0.0, -RADIUS * 0.40), Vector2(0.0, RADIUS * 0.40),
		Color.from_hsv(h, clampf(s * 0.20, 0.0, 1.0), 0.92, flare_alpha * 0.72), 0.9, true)

	# ── Etiket ────────────────────────────────────────────────────────────────
	if alpha_scale > 0.6:
		var font      := ThemeDB.fallback_font
		var font_size := 16
		var text_w    := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var text_pos  := Vector2(-text_w * 0.5, RADIUS + 16.0)
		draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			Color.from_hsv(h, clampf(s * 0.20, 0.0, 1.0), 0.95, alpha_scale * 0.72))


func _on_body_entered(body: Node) -> void:
	if not _active:
		return
	if _resolve_player(body):
		_travel()


func _on_area_entered(area: Area2D) -> void:
	if not _active:
		return
	if _resolve_player(area):
		_travel()


func _resolve_player(n: Node) -> bool:
	var cur: Node = n
	var hops := 0
	while cur != null and hops < 8:
		if cur.is_in_group(player_group):
			return true
		cur = cur.get_parent()
		hops += 1
	return false


func _travel() -> void:
	var run_state := get_tree().get_root().get_node_or_null("RunState")
	if run_state != null:
		run_state.set("coming_from_portal", true)
	if target_scene.is_empty():
		target_scene = DEFAULT_TARGET_SCENE
	get_tree().change_scene_to_file(target_scene)


func respawn_at(world_pos: Vector2) -> void:
	global_position = world_pos
	_appear_t  = 0.0
	_active    = false
	queue_redraw()


func _ease_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)
