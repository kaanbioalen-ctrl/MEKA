extends Node
## Ocak ekranı — pause menüsünden açılır, polar grid görüntüler.
## Gelecekte: kaynak→enerji dönüşüm fiziği buraya eklenecek.

signal close_pressed

const PARTICLES_BG_SCRIPT = preload("res://scripts/ui/menu_particles_bg.gd")
const OCAK_GRID_SCRIPT    = preload("res://scripts/ui/ocak_grid.gd")
const BORDER_SCRIPT       = preload("res://scripts/ui/main_menu_border_glow.gd")

var _overlay   : ColorRect = null
var _content   : Control   = null
var _animating : bool      = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui(get_parent())


# ── Arayüz inşası ──────────────────────────────────────────────────────────────

func _build_ui(canvas: Node) -> void:
	var vp := get_viewport().get_visible_rect().size

	# 1. Solid arka plan (App.tsx: #050505)
	var solid := ColorRect.new()
	solid.set_anchors_preset(Control.PRESET_FULL_RECT)
	solid.color = Color(0.02, 0.01, 0.05, 1.0)
	solid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(solid)

	# 2. Parçacık arka planı
	var particles := PARTICLES_BG_SCRIPT.new()
	canvas.add_child(particles)

	# 3. Atmosfer glow (App.tsx radial gradient: #1e1b4b, #312e81, #4c1d95)
	var atmo := _AtmosNode.new()
	canvas.add_child(atmo)

	# 4. Içerik grubu (grid + HUD + buton) — birlikte fade edilecek
	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.modulate.a = 0.0
	canvas.add_child(_content)

	# Grid — viewport merkezinde, ölçek 1.15
	var grid := OCAK_GRID_SCRIPT.new()
	grid.position = vp * 0.5
	grid.scale = Vector2(1.15, 1.15)
	_content.add_child(grid)

	# Overlay (karartma katmanı — animasyonda kullanılır)
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.0, 0.0, 0.03, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_overlay)

	# HUD — üst sol köşe
	var hud_root := Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.add_child(hud_root)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.add_theme_constant_override("margin_left",  32)
	margin.add_theme_constant_override("margin_top",   32)
	margin.add_theme_constant_override("margin_right", 0)
	margin.add_theme_constant_override("margin_bottom", 0)
	hud_root.add_child(margin)

	var hud_vbox := VBoxContainer.new()
	hud_vbox.add_theme_constant_override("separation", 4)
	margin.add_child(hud_vbox)

	var sys_label := Label.new()
	sys_label.text = "SYSTEM ACTIVE"
	sys_label.add_theme_font_size_override("font_size", 10)
	sys_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.40))
	hud_vbox.add_child(sys_label)

	var title_label := Label.new()
	title_label.text = "OCAK"
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(0.88, 0.90, 1.00, 0.97))
	hud_vbox.add_child(title_label)

	# Kapat butonu — sağ üst köşe
	var btn_margin := MarginContainer.new()
	btn_margin.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn_margin.anchor_left   = 1.0
	btn_margin.anchor_top    = 0.0
	btn_margin.anchor_right  = 1.0
	btn_margin.anchor_bottom = 0.0
	btn_margin.add_theme_constant_override("margin_right",  32)
	btn_margin.add_theme_constant_override("margin_top",    32)
	btn_margin.add_theme_constant_override("margin_left",   0)
	btn_margin.add_theme_constant_override("margin_bottom", 0)
	hud_root.add_child(btn_margin)

	var close_btn := _make_button("✕  KAPAT", Color(0.42, 0.42, 0.58))
	close_btn.pressed.connect(func() -> void: close_pressed.emit())
	btn_margin.add_child(close_btn)


# ── Göster / Gizle ─────────────────────────────────────────────────────────────

func show_screen() -> void:
	if _animating:
		return
	_animating = true
	if _overlay  != null: _overlay.color.a  = 0.0
	if _content  != null: _content.modulate.a = 0.0

	var tw := create_tween()
	tw.set_parallel(true)
	if _overlay != null:
		tw.tween_property(_overlay, "color:a", 0.55, 0.30).set_ease(Tween.EASE_IN)
	if _content != null:
		tw.tween_property(_content, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func() -> void: _animating = false)


func hide_screen() -> void:
	if _animating:
		return
	_animating = true

	var tw := create_tween()
	tw.set_parallel(true)
	if _content != null:
		tw.tween_property(_content, "modulate:a", 0.0, 0.15).set_ease(Tween.EASE_OUT)
	if _overlay != null:
		tw.tween_property(_overlay, "color:a", 0.0, 0.20).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void: _animating = false)


# ── Input ──────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not get_parent().visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_pressed.emit()
		get_viewport().set_input_as_handled()


# ── Widget yardımcıları ────────────────────────────────────────────────────────

func _make_button(label: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(130, 40)
	btn.add_theme_font_size_override("font_size", 13)
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


# ── İç sınıf: atmosfer glow Node2D ───────────────────────────────────────────

class _AtmosNode extends Node2D:
	func _ready() -> void:
		pass

	func _draw() -> void:
		var vp := get_viewport().get_visible_rect().size
		var cx := vp.x * 0.5
		var cy := vp.y * 0.5

		# App.tsx: 3 radial gradient, opacity 0.20
		# #1e1b4b — koyu indigo, merkez
		draw_circle(Vector2(cx, cy), vp.length() * 0.40, Color(0.118, 0.106, 0.294, 0.08))
		# #312e81 — sol alt
		draw_circle(Vector2(cx * 0.4, cy * 1.6), vp.length() * 0.25, Color(0.192, 0.180, 0.506, 0.06))
		# #4c1d95 — sağ üst
		draw_circle(Vector2(cx * 1.6, cy * 0.4), vp.length() * 0.25, Color(0.298, 0.114, 0.584, 0.06))
