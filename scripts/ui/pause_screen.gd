extends Node
## Pause menüsü — ESC ile açılır/kapanır, oyunu durdurur.
## PauseScreen CanvasLayer'a child olarak eklenir.

signal resume_pressed
signal main_menu_pressed
signal ocak_pressed

const BORDER_SCRIPT       = preload("res://scripts/ui/main_menu_border_glow.gd")
const PARTICLES_BG_SCRIPT = preload("res://scripts/ui/menu_particles_bg.gd")

const PANEL_W: float = 380.0
const PANEL_H: float = 320.0

var _overlay   : ColorRect = null
var _panel_root: Control   = null
var _animating : bool      = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var canvas := get_parent()
	_build_ui(canvas)


# ── Genel Arayüz ───────────────────────────────────────────────────────────────

func show_menu() -> void:
	if _animating:
		return
	_animating = true
	if _overlay    != null: _overlay.color.a    = 0.0
	if _panel_root != null: _panel_root.modulate.a = 0.0

	var tw := create_tween()
	tw.set_parallel(true)
	if _overlay != null:
		tw.tween_property(_overlay, "color:a", 0.72, 0.30).set_ease(Tween.EASE_IN)
	if _panel_root != null:
		tw.tween_property(_panel_root, "modulate:a", 1.0, 0.20).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func() -> void: _animating = false)


func hide_menu() -> void:
	if _animating:
		return
	_animating = true

	var tw := create_tween()
	tw.set_parallel(true)
	if _panel_root != null:
		tw.tween_property(_panel_root, "modulate:a", 0.0, 0.15).set_ease(Tween.EASE_OUT)
	if _overlay != null:
		tw.tween_property(_overlay, "color:a", 0.0, 0.20).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void: _animating = false)


# ── Input ──────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not get_parent().visible:
		return
	if event.is_action_pressed("ui_cancel"):
		resume_pressed.emit()
		get_viewport().set_input_as_handled()


# ── UI İnşası ─────────────────────────────────────────────────────────────────

func _build_ui(canvas: Node) -> void:
	# Oyunu tamamen örten solid arka plan — en alt katman
	var solid := ColorRect.new()
	solid.set_anchors_preset(Control.PRESET_FULL_RECT)
	solid.color = Color(0.00, 0.00, 0.04, 1.0)
	solid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(solid)

	# Parçacık arka planı — en alt katman
	var particles := PARTICLES_BG_SCRIPT.new()
	canvas.add_child(particles)

	# Arka plan overlay
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.00, 0.00, 0.03, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_overlay)

	# Tam ekran + ortalama
	var fullscreen := Control.new()
	fullscreen.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(fullscreen)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	fullscreen.add_child(center)

	# Panel
	_panel_root = Control.new()
	_panel_root.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	_panel_root.modulate.a = 0.0
	center.add_child(_panel_root)

	# Panel arka planı
	var panel_bg := ColorRect.new()
	panel_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_bg.color = Color(0.03, 0.00, 0.10, 0.88)
	panel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(panel_bg)

	# Kenar glow
	var border := BORDER_SCRIPT.new()
	_panel_root.add_child(border)

	# İçerik
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   32)
	margin.add_theme_constant_override("margin_right",  32)
	margin.add_theme_constant_override("margin_top",    0)
	margin.add_theme_constant_override("margin_bottom", 0)
	_panel_root.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	margin.add_child(vbox)

	vbox.add_child(_spacer(22))

	# Başlık
	var title := Label.new()
	title.text = "DURAKLATILDI"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.88, 0.90, 1.00, 0.95))
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	vbox.add_child(_spacer(10))
	vbox.add_child(_divider())
	vbox.add_child(_spacer(22))

	# Devam et butonu
	var resume_btn := _make_button("◉  DEVAM ET", Color(0.55, 0.75, 1.00))
	resume_btn.pressed.connect(func() -> void: resume_pressed.emit())
	vbox.add_child(resume_btn)

	vbox.add_child(_spacer(10))

	# Ana menü butonu
	var menu_btn := _make_button("ANA MENÜ", Color(0.42, 0.42, 0.58))
	menu_btn.pressed.connect(func() -> void: main_menu_pressed.emit())
	vbox.add_child(menu_btn)

	vbox.add_child(_spacer(10))

	# Ocak butonu
	var ocak_btn := _make_button("⬡  OCAK", Color(0.70, 0.55, 1.00))
	ocak_btn.pressed.connect(func() -> void: ocak_pressed.emit())
	vbox.add_child(ocak_btn)

	vbox.add_child(_spacer(22))


# ── Widget yardımcıları ───────────────────────────────────────────────────────

func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _divider() -> ColorRect:
	var c := ColorRect.new()
	c.custom_minimum_size = Vector2(0, 1)
	c.color = Color(0.55, 0.75, 1.00, 0.20)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _make_button(label: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(0, 46)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color",
		Color(accent.r, accent.g, accent.b, 0.90))
	btn.add_theme_color_override("font_hover_color",   Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color",
		Color(accent.r * 0.75, accent.g * 0.75, accent.b * 0.75, 1.0))

	var sn := StyleBoxFlat.new()
	sn.bg_color     = Color(0.04, 0.01, 0.12, 0.88)
	sn.border_color = Color(accent.r * 0.48, accent.g * 0.48, accent.b * 0.48, 0.50)
	sn.border_width_left = 1;  sn.border_width_right  = 1
	sn.border_width_top  = 1;  sn.border_width_bottom = 1
	sn.corner_radius_top_left     = 3; sn.corner_radius_top_right    = 3
	sn.corner_radius_bottom_right = 3; sn.corner_radius_bottom_left  = 3
	btn.add_theme_stylebox_override("normal",  sn)
	btn.add_theme_stylebox_override("pressed", sn)

	var sh := StyleBoxFlat.new()
	sh.bg_color     = Color(accent.r * 0.14, accent.g * 0.14, accent.b * 0.20, 0.92)
	sh.border_color = Color(accent.r * 0.75, accent.g * 0.75, accent.b * 0.75, 0.72)
	sh.border_width_left = 1;  sh.border_width_right  = 1
	sh.border_width_top  = 1;  sh.border_width_bottom = 1
	sh.corner_radius_top_left     = 3; sh.corner_radius_top_right    = 3
	sh.corner_radius_bottom_right = 3; sh.corner_radius_bottom_left  = 3
	btn.add_theme_stylebox_override("hover", sh)

	return btn
