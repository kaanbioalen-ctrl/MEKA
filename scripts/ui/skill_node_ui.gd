extends Control
class_name SkillNodeUI
## Circular skill node — class-based, progression-aware, production-quality.
## MAX state: orbiting particles, dual halo, celebration ring, hover scale.
## Signals and setup API unchanged — drop-in replacement.

signal hover_entered(skill_id: String)
signal hover_exited
signal skill_pressed(skill_id: String)
signal skill_downgraded(skill_id: String)

# ── Class renk paletleri ───────────────────────────────────────────────────────
const CLASS_PALETTES: Dictionary = {
	"ENERGY": {
		"base": Color(0.349, 0.847, 1.000),   # #59D8FF  soğuk plazma
		"mid":  Color(0.541, 0.910, 1.000),   # #8AE8FF
		"max":  Color(0.839, 0.976, 1.000),   # #D6F9FF  vakum / alan hakimiyeti
		"bg":   Color(0.028, 0.092, 0.170),
	},
	"MINING": {
		"base": Color(0.894, 0.722, 0.290),   # #E4B84A  kaynak / verimlilik
		"mid":  Color(1.000, 0.824, 0.373),   # #FFD25F
		"max":  Color(1.000, 0.949, 0.651),   # #FFF2A6  zenginlik / ustalık
		"bg":   Color(0.130, 0.100, 0.032),
	},
	"COMBAT": {
		"base": Color(1.000, 0.369, 0.369),   # #FF5E5E  saldırı / patlama
		"mid":  Color(1.000, 0.541, 0.357),   # #FF8A5B
		"max":  Color(1.000, 0.761, 0.478),   # #FFC27A  solar enerji — max'te sıcak altın
		"bg":   Color(0.165, 0.048, 0.048),
	},
	"UTILITY": {
		"base": Color(0.690, 0.424, 1.000),   # #B06CFF  kozmik kontrol
		"mid":  Color(0.780, 0.573, 1.000),   # #C792FF
		"max":  Color(0.914, 0.824, 1.000),   # #E9D2FF  ustalaşma / mekanik hakimiyet
		"bg":   Color(0.110, 0.055, 0.175),
	},
	"DEFAULT": {
		"base": Color(0.440, 0.860, 1.000),
		"mid":  Color(0.600, 0.920, 1.000),
		"max":  Color(0.850, 0.970, 1.000),
		"bg":   Color(0.055, 0.115, 0.210),
	},
}

# Orbiting particles: [angle_offset_rad, orbit_r_factor, speed_mul, dot_radius]
# TAU/3 ≈ 2.094  TAU*2/3 ≈ 4.189
const ORBIT_PARTICLES: Array = [
	[0.000, 1.32, 1.00, 1.6],
	[2.094, 1.40, 0.72, 1.2],
	[4.189, 1.28, 1.31, 1.0],
]

const HIT_RADIUS_PADDING_LARGE: float = 18.0
const HIT_RADIUS_PADDING_SMALL: float = 12.0

# ── Config ──────────────────────────────────────────────────────────────────────
var skill_id:      String     = ""
var _short_key:    String     = ""
var _display_name: String     = ""
var _is_root:      bool       = false
var _is_large:     bool       = true
var _skill_class:  String     = "DEFAULT"
var _palette:      Dictionary = {}
var _is_player_core: bool     = false

# ── State ───────────────────────────────────────────────────────────────────────
var _locked:    bool   = true
var _level:     int    = 0
var _max_level: int    = 1
var _can_buy:   bool   = false
var _status:    String = ""

# ── Animation ───────────────────────────────────────────────────────────────────
var _hover:       bool  = false
var _hover_scale: float = 1.0   # Smooth lerp to 1.07 on hover
var _depth_scale: float = 1.0
var _depth_alpha: float = 1.0
var _depth_label_alpha: float = 1.0
var _time:        float = 0.0
var _flash:       float = 0.0   # Normal level-up inner flash
var _max_flash:   float = 0.0   # MAX unlock flash overlay
var _cel_ring:    float = 0.0   # Celebration ring radius factor (1.0 → 2.4)
var _cel_ring_a:  float = 0.0   # Celebration ring alpha

# ── Labels ──────────────────────────────────────────────────────────────────────
var _lbl_key:    Label = null
var _lbl_name:   Label = null
var _lbl_status: Label = null
var _lbl_level:  Label = null


func _ready() -> void:
	mouse_filter  = Control.MOUSE_FILTER_STOP
	pivot_offset  = size * 0.5
	mouse_entered.connect(func(): _set_hover(true))
	mouse_exited.connect(func():  _set_hover(false))
	set_process(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5


func setup(p_id: String, cfg: Dictionary) -> void:
	skill_id      = p_id
	_short_key    = cfg.get("short", "")
	_display_name = str(cfg.get("label", p_id)).replace("\n", " ")
	_is_root      = bool(cfg.get("is_root", false))
	_is_large     = bool(cfg.get("large",   true))
	_skill_class  = str(cfg.get("skill_class", "DEFAULT"))
	_palette      = CLASS_PALETTES.get(_skill_class, CLASS_PALETTES["DEFAULT"])
	_is_player_core = (skill_id == "energy_field")
	_build_level_label()
	if _is_large:
		_build_labels()


func update_state(st: Dictionary) -> void:
	_locked    = bool(st.get("locked",      true))
	_level     = int( st.get("level",       0))
	_max_level = int( st.get("max_level",   1))
	_can_buy   = bool(st.get("can_buy",     false))
	_status    = str( st.get("status_text", ""))
	_refresh_labels()
	queue_redraw()


func set_depth_visual(depth_t: float, depth_scale: float, front_boost: float) -> void:
	_depth_scale = maxf(0.72, depth_scale)
	_depth_alpha = clampf(lerpf(0.34, 1.0, depth_t) + front_boost * 0.08, 0.0, 1.0)
	_depth_label_alpha = clampf(lerpf(0.12, 1.0, depth_t) + front_boost * 0.10, 0.0, 1.0)
	modulate = Color(1.0, 1.0, 1.0, _depth_alpha)
	_apply_label_depth()
	queue_redraw()


# ── Hover & Input ───────────────────────────────────────────────────────────────

func _set_hover(entered: bool) -> void:
	_hover = entered
	if entered:
		hover_entered.emit(skill_id)
	else:
		hover_exited.emit()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not _is_pointer_in_hotzone(mb.position):
		return
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		if _can_buy and not _locked:
			var will_max := (_level + 1 >= _max_level and _max_level > 0)
			_flash     = 1.0
			if will_max:
				_max_flash  = 1.0
				_cel_ring   = 1.0   # Starts at node edge, expands outward
				_cel_ring_a = 1.0
			skill_pressed.emit(skill_id)
			accept_event()
	elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		if not _locked and _level > 0:
			_flash = 0.5
			skill_downgraded.emit(skill_id)
			accept_event()


func _process(delta: float) -> void:
	_time      += delta
	_flash      = maxf(0.0, _flash     - delta * 2.6)
	_max_flash  = maxf(0.0, _max_flash - delta * 1.2)

	# Celebration ring: expands outward while fading — fires once at MAX unlock
	if _cel_ring_a > 0.0:
		_cel_ring   = minf(_cel_ring + delta * 2.6, 2.4)
		_cel_ring_a = maxf(0.0, _cel_ring_a - delta * 1.6)

	# Smooth hover scale from center
	var target := 1.07 if _hover else 1.0
	_hover_scale = lerpf(_hover_scale, target, minf(delta * 12.0, 1.0))
	var final_scale := _hover_scale * _depth_scale
	scale = Vector2(final_scale, final_scale)

	queue_redraw()


func _is_pointer_in_hotzone(local_pos: Vector2) -> bool:
	var center     := size * 0.5
	var base_r     := minf(size.x, size.y) * 0.5
	var padding    := HIT_RADIUS_PADDING_LARGE if _is_large else HIT_RADIUS_PADDING_SMALL
	return local_pos.distance_to(center) <= base_r + padding


func _has_point(point: Vector2) -> bool:
	return _is_pointer_in_hotzone(point)


# ── Drawing ─────────────────────────────────────────────────────────────────────

func _draw() -> void:
	var c      := size * 0.5
	var base   := minf(size.x, size.y) * 0.5 - 2.0
	var is_max := (_level >= _max_level and _max_level > 0 and not _locked)
	var t      := 0.0
	if not _locked and _max_level > 0:
		t = clampf(float(_level) / float(_max_level), 0.0, 1.0)

	var col     := _progression_color(t)
	var max_col := _palette.get("max", col) as Color
	var bg_col  := _bg_color(t, is_max)
	if _is_player_core:
		col = col.lerp(Color(1.0, 1.0, 1.0), 0.52)
		max_col = max_col.lerp(Color(1.0, 1.0, 1.0), 0.72)

	# ~2-second breathing (PI rad/s), shimmer for mid-state flicker
	var breath  := sin(_time * PI) * 0.5 + 0.5        # 0..1, ~2s loop
	var shimmer := sin(_time * 2.8 + 1.0) * 0.5 + 0.5
	var pulse   := 0.0
	var hov     := 0.22 if _hover else 0.0

	if is_max:
		pulse = breath
	elif _can_buy and not _locked:
		pulse = (sin(_time * 4.2) * 0.5 + 0.5) * 0.85
	elif not _locked and _level > 0:
		pulse = shimmer * 0.18

	# ── L1: Outer soft ambient glow ─────────────────────────────────────────
	if not _locked:
		var g := (t * 0.26 + pulse * 0.22 + hov) if not is_max else (0.20 + pulse * 0.14)
		if g > 0.02:
			draw_circle(c, base * 1.75, Color(col.r, col.g, col.b, g * 0.11))
			draw_circle(c, base * 1.40, Color(col.r, col.g, col.b, g * 0.21))
	if _is_player_core:
		draw_circle(c, base * 1.95, Color(1.0, 1.0, 1.0, 0.045 + breath * 0.025))
		draw_circle(c, base * 1.58, Color(0.82, 0.96, 1.0, 0.10 + breath * 0.04))

	# ── L2: MAX — distant thin ring (very subtle, far out) ──────────────────
	if is_max:
		draw_arc(c, base * 1.52, 0.0, TAU, 48,
			Color(max_col.r, max_col.g, max_col.b, pulse * 0.10 + 0.04), 0.7, true)

	# ── L3: MAX — second halo ring ───────────────────────────────────────────
	if is_max:
		draw_arc(c, base * 1.28, 0.0, TAU, 96,
			Color(max_col.r, max_col.g, max_col.b, 0.16 + pulse * 0.10), 0.9, true)

	# ── L4: High-level inner halo (t >= 0.70) ───────────────────────────────
	if not _locked and t >= 0.70:
		var ht := clampf((t - 0.70) / 0.30, 0.0, 1.0)
		var ha := ht * (0.20 + (sin(_time * PI) * 0.06 if is_max else 0.0))
		draw_arc(c, base * 1.14, 0.0, TAU, 96,
			Color(col.r, col.g, col.b, ha), 1.2, true)

	# ── L5: MAX — primary pulsing outer ring (class color) ──────────────────
	if is_max:
		draw_arc(c, base * 1.09, 0.0, TAU, 96,
			Color(max_col.r, max_col.g, max_col.b, 0.44 + pulse * 0.28), 1.8, true)

	# ── L6: Background circle ────────────────────────────────────────────────
	draw_circle(c, base, bg_col)
	if _is_player_core:
		draw_circle(c, base * 0.88, Color(0.82, 0.96, 1.0, 0.16 + breath * 0.05))

	# ── L7: Inner core glow ──────────────────────────────────────────────────
	if is_max:
		# Layered: class-tinted warm core + white hot center
		draw_circle(c, base * 0.54,
			Color(max_col.r, max_col.g, max_col.b, 0.22 + pulse * 0.13))
		draw_circle(c, base * 0.28,
			Color(1.0, 1.0, 1.0, 0.10 + pulse * 0.08))
	elif not _locked and _level > 0:
		draw_circle(c, base * (0.30 + t * 0.22),
			Color(col.r, col.g, col.b, 0.06 + t * 0.13))
	if _is_player_core:
		draw_circle(c, base * 0.42, Color(0.92, 0.98, 1.0, 0.24 + breath * 0.08))
		draw_circle(c, base * 0.20, Color(1.0, 1.0, 1.0, 0.78))

	# ── L8: Main rim ring ────────────────────────────────────────────────────
	if _locked:
		draw_arc(c, base, 0.0, TAU, 72, Color(0.32, 0.38, 0.50, 0.18), 0.9, true)
	else:
		var rim_a: float
		var rim_w: float
		if _level == 0:
			rim_a = 0.42 + shimmer * 0.10 + pulse * 0.18
			rim_w = 1.4
		else:
			rim_a = 0.55 + t * 0.35 + pulse * 0.12
			rim_w = 1.6 + t * 0.9
		if is_max:
			rim_a = 0.90 + pulse * 0.06
			rim_w = 2.6
		var boost := 1.0 + pulse * 0.18 + shimmer * 0.07
		draw_arc(c, base, 0.0, TAU, 96,
			Color(col.r * boost, col.g * boost, col.b * boost, clampf(rim_a, 0.0, 1.0)),
			rim_w, true)
	if _is_player_core:
		draw_arc(c, base * 1.02, 0.0, TAU, 96, Color(1.0, 1.0, 1.0, 0.38 + breath * 0.08), 1.4, true)

	# ── L9: Inner depth accent ring ──────────────────────────────────────────
	var inner_a := 0.06 if not _locked else 0.03
	if is_max:
		inner_a = 0.14 + pulse * 0.07
	draw_arc(c, base * 0.62, 0.0, TAU, 48,
		Color(1.0, 1.0, 1.0, inner_a), 0.8, true)

	# ── L10: Orbiting energy particles (MAX only) ────────────────────────────
	if is_max:
		_draw_orbit_particles(c, base, pulse)

	# ── L11: Hover highlight ring ────────────────────────────────────────────
	if _hover and not _locked:
		var h_col := max_col if is_max else col
		draw_arc(c, base + 2.2, 0.0, TAU, 64,
			Color(h_col.r, h_col.g, h_col.b, 0.34 + pulse * 0.08), 1.1, true)

	# ── L12: Level-up flash ───────────────────────────────────────────────────
	if _flash > 0.01:
		if _max_flash > 0.01:
			# MAX flash: class color overlay + expanding ring
			draw_circle(c, base,
				Color(max_col.r, max_col.g, max_col.b, _max_flash * 0.36))
			draw_arc(c, base * (1.0 + _max_flash * 0.48), 0.0, TAU, 80,
				Color(max_col.r, max_col.g, max_col.b, _max_flash * 0.50), 1.2, true)
		else:
			# Normal flash: clean white inner pulse
			draw_circle(c, base * 0.78, Color(1.0, 1.0, 1.0, _flash * 0.26))

	# ── L13: Celebration ring — fires once at MAX unlock ─────────────────────
	if _cel_ring_a > 0.01:
		# Primary wave
		draw_arc(c, base * _cel_ring, 0.0, TAU, 64,
			Color(max_col.r, max_col.g, max_col.b, _cel_ring_a * 0.68), 1.3, true)
		# Secondary soft wave (slightly behind)
		var r2 := maxf(1.0, _cel_ring - 0.20)
		draw_arc(c, base * r2, 0.0, TAU, 48,
			Color(1.0, 1.0, 1.0, _cel_ring_a * 0.30), 0.7, true)

	# ── L14: Locked overlay ───────────────────────────────────────────────────
	if _locked:
		draw_circle(c, base - 1.0, Color(0.0, 0.0, 0.0, 0.52))


func _draw_orbit_particles(c: Vector2, base: float, pulse: float) -> void:
	var max_col := _palette.get("max", Color(1.0, 1.0, 1.0)) as Color
	for p in ORBIT_PARTICLES:
		var angle_off: float = p[0]
		var r_factor:  float = p[1]
		var speed:     float = p[2]
		var dot_r:     float = p[3]
		var angle := _time * speed + angle_off
		var pos   := c + Vector2(cos(angle), sin(angle)) * base * r_factor
		var alpha := 0.50 + pulse * 0.28
		# Soft halo
		draw_circle(pos, dot_r * 2.6, Color(max_col.r, max_col.g, max_col.b, alpha * 0.20))
		# Core dot
		draw_circle(pos, dot_r,       Color(max_col.r, max_col.g, max_col.b, alpha))


# ── Color helpers ───────────────────────────────────────────────────────────────

func _progression_color(t: float) -> Color:
	var base_col := _palette.get("base", Color(0.44, 0.86, 1.0)) as Color
	var mid_col  := _palette.get("mid",  base_col) as Color
	var max_col  := _palette.get("max",  mid_col)  as Color
	if _locked:
		return Color(base_col.r * 0.38, base_col.g * 0.38, base_col.b * 0.38)
	if _level == 0:
		return Color(base_col.r * 0.72, base_col.g * 0.72, base_col.b * 0.72)
	if t < 0.5:
		return base_col.lerp(mid_col, t * 2.0)
	else:
		return mid_col.lerp(max_col, (t - 0.5) * 2.0)


func _bg_color(t: float, is_max: bool) -> Color:
	var bg := _palette.get("bg", Color(0.055, 0.115, 0.210)) as Color
	if _is_player_core:
		bg = bg.lerp(Color(0.22, 0.30, 0.42, 1.0), 0.58)
	if _locked:
		return Color(bg.r * 0.55, bg.g * 0.55, bg.b * 0.55, 0.95)
	var brightness := t * 0.10
	if is_max:
		brightness = 0.18 + sin(_time * PI) * 0.04
	return Color(
		minf(1.0, bg.r + brightness),
		minf(1.0, bg.g + brightness),
		minf(1.0, bg.b + brightness),
		0.95
	)


# ── Labels ──────────────────────────────────────────────────────────────────────

func _build_level_label() -> void:
	if _lbl_level != null:
		return
	_lbl_level = _make_lbl(10, Color(0.88, 0.96, 1.0, 0.96))
	_lbl_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_level.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER


func _build_labels() -> void:
	_lbl_key    = _make_lbl(10, Color(0.65, 0.78, 0.92, 0.60))
	_lbl_name   = _make_lbl(11, Color(0.94, 0.97, 1.0,  1.00))
	_lbl_status = _make_lbl(10, Color(0.70, 0.88, 1.0,  0.80))
	if _is_player_core:
		_lbl_name.add_theme_font_size_override("font_size", 9)
		_lbl_name.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.98))
		_lbl_name.add_theme_constant_override("outline_size", 1)
		_lbl_name.add_theme_color_override("font_outline_color", Color(0.10, 0.18, 0.30, 0.85))
	_lbl_name.autowrap_mode          = TextServer.AUTOWRAP_WORD_SMART
	_lbl_name.horizontal_alignment   = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place_labels()


func _make_lbl(sz: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _refresh_labels() -> void:
	_update_level_label()
	_place_labels()
	if not _is_large:
		_apply_label_depth()
		return
	if _lbl_key    != null: _lbl_key.text    = _short_key
	if _lbl_name   != null:
		_lbl_name.text = "" if _is_player_core else _display_name
	if _lbl_status != null:
		_lbl_status.text = "" if (_is_player_core or _status.begins_with("Lv ")) else _status
	_apply_label_depth()


func _update_level_label() -> void:
	if _lbl_level == null:
		return
	var is_max := (_level >= _max_level and _max_level > 0 and not _locked)
	if _locked:
		_lbl_level.text = ""
		return
	if is_max:
		_lbl_level.text = "MAX"
		# Class max color — slightly softened for readability
		var mc := _palette.get("max", Color(1.0, 1.0, 1.0)) as Color
		_lbl_level.add_theme_color_override("font_color",
			Color(mc.r * 0.94 + 0.06, mc.g * 0.94 + 0.06, mc.b * 0.94 + 0.06, 1.0))
		_lbl_level.add_theme_font_size_override("font_size", 11)
	elif _max_level <= 1:
		_lbl_level.text = "AÇIK" if _level > 0 else ""
		_lbl_level.add_theme_color_override("font_color", Color(0.88, 0.96, 1.0, 0.96))
		_lbl_level.add_theme_font_size_override("font_size", 10)
	else:
		_lbl_level.text = "Lv %d/%d" % [_level, _max_level]
		var lv_t       := clampf(float(_level) / float(_max_level), 0.0, 1.0)
		var base_label := Color(0.88, 0.96, 1.0, 0.96)
		var mid_col    := _palette.get("mid", base_label) as Color
		_lbl_level.add_theme_color_override("font_color",
			base_label.lerp(mid_col, lv_t * 0.50))
		_lbl_level.add_theme_font_size_override("font_size", 10)


func _place_labels() -> void:
	if _lbl_level == null:
		return
	var w := size.x
	var h := size.y
	_lbl_level.position = Vector2(0.0, h * 0.5 - 8.0)
	_lbl_level.size     = Vector2(w, 16.0)
	if _is_large:
		if _lbl_key    != null:
			_lbl_key.position = Vector2(6.0, 4.0)
			_lbl_key.size     = Vector2(18.0, 14.0)
		if _lbl_name   != null:
			if _is_player_core:
				_lbl_name.position = Vector2(4.0, h * 0.39)
				_lbl_name.size     = Vector2(w - 8.0, h * 0.12)
			else:
				_lbl_name.position = Vector2(4.0, h * 0.22)
				_lbl_name.size     = Vector2(w - 8.0, h * 0.32)
		if _lbl_status != null:
			_lbl_status.position = Vector2(4.0, h * 0.56)
			_lbl_status.size     = Vector2(w - 8.0, h * 0.24)
	_apply_label_depth()


func _apply_label_depth() -> void:
	if _lbl_level != null:
		var level_col: Color = _lbl_level.get_theme_color("font_color")
		_lbl_level.add_theme_color_override("font_color", Color(level_col.r, level_col.g, level_col.b, _depth_label_alpha))
	if _lbl_key != null:
		_lbl_key.visible = (not _is_player_core) and _depth_label_alpha > 0.30
		_lbl_key.add_theme_color_override("font_color", Color(0.65, 0.78, 0.92, 0.60 * _depth_label_alpha))
	if _lbl_name != null:
		_lbl_name.visible = (not _is_player_core) and _depth_label_alpha > 0.42
		_lbl_name.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0, _depth_label_alpha))
	if _lbl_status != null:
		_lbl_status.visible = _depth_label_alpha > 0.55
		_lbl_status.add_theme_color_override("font_color", Color(0.70, 0.88, 1.0, 0.80 * _depth_label_alpha))
