extends Node
## Premium ölüm özeti paneli.
## CanvasLayer (DeathScreen) çocuğu olarak eklenir.
## populate(run_state) çağrıldığında RunState verisini alır ve animasyonu başlatır.

signal retry_pressed
signal upgrade_pressed
signal quit_pressed

# ── Sabitler ───────────────────────────────────────────────────────────────────

const HEADER_SCRIPT      = preload("res://scripts/ui/death_header_visual.gd")
const PARTICLES_BG_SCRIPT = preload("res://scripts/ui/menu_particles_bg.gd")

const COL_IRON    := Color(0.54, 0.63, 0.73)
const COL_GOLD    := Color(1.00, 0.82, 0.40)
const COL_CRYSTAL := Color(0.48, 0.94, 0.88)
const COL_URANIUM := Color(0.70, 1.00, 0.24)

# ── Referanslar ────────────────────────────────────────────────────────────────

var _overlay    : ColorRect  = null
var _panel_root : Control    = null
var _header_vis             = null   # death_header_visual instance

var _time_label   : Label       = null
var _iron_label   : Label       = null
var _gold_label   : Label       = null
var _crystal_label: Label       = null
var _uranium_label: Label       = null
var _score_label  : Label       = null

var _iron_bar    : ProgressBar  = null
var _gold_bar    : ProgressBar  = null
var _crystal_bar : ProgressBar  = null
var _uranium_bar : ProgressBar  = null

var _retry_btn   : Button       = null
var _upgrade_btn : Button       = null
var _quit_btn    : Button       = null

# ── Kurulum ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	var canvas := get_parent()
	# Eski CanvasLayer çocuklarını temizle (tscn'deki basit panel)
	for child in canvas.get_children():
		if child != self:
			child.queue_free()
	_build_ui(canvas)


## RunState node'undan veri alır ve giriş animasyonunu başlatır.
func populate(rs: Node) -> void:
	if rs == null:
		_start_animation(0.0, 0, 0, 0, 0)
		return
	_start_animation(
		float(rs.get("run_time")),
		int(rs.get("iron")),
		int(rs.get("gold")),
		int(rs.get("crystal")),
		int(rs.get("uranium"))
	)


func set_buttons_disabled(disabled: bool) -> void:
	if _retry_btn   != null: _retry_btn.disabled   = disabled
	if _upgrade_btn != null: _upgrade_btn.disabled  = disabled
	if _quit_btn    != null: _quit_btn.disabled     = disabled


# ── UI İnşası ─────────────────────────────────────────────────────────────────

func _build_ui(canvas: Node) -> void:
	# Oyunu tamamen örten solid arka plan — en alt katman
	var solid := ColorRect.new()
	solid.set_anchors_preset(Control.PRESET_FULL_RECT)
	solid.color = Color(0.00, 0.00, 0.04, 1.0)
	solid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(solid)

	# ── Parçacık arka planı — en alt katman ──
	var particles := PARTICLES_BG_SCRIPT.new()
	canvas.add_child(particles)

	# ── Arka plan ──
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.00, 0.00, 0.03, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_overlay)

	# ── Tam ekran kapsayıcı ──
	var fullscreen := Control.new()
	fullscreen.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(fullscreen)

	# ── Ortalama kapsayıcı ──
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	fullscreen.add_child(center)

	# ── Panel ──
	_panel_root = Control.new()
	_panel_root.custom_minimum_size = Vector2(460, 620)
	_panel_root.modulate.a = 0.0
	center.add_child(_panel_root)

	# Panel arka planı
	var panel_bg := ColorRect.new()
	panel_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_bg.color = Color(0.03, 0.00, 0.10, 0.84)
	_panel_root.add_child(panel_bg)

	# Panel kenar çizgisi (ince glow)
	var border := ColorRect.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.color = Color(0.0, 0.0, 0.0, 0.0)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(border)

	# ── İçerik MarginContainer ──
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   28)
	margin.add_theme_constant_override("margin_right",  28)
	margin.add_theme_constant_override("margin_top",    10)
	margin.add_theme_constant_override("margin_bottom", 24)
	_panel_root.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	margin.add_child(vbox)

	# ── Header görseli ──
	_header_vis = HEADER_SCRIPT.new()
	_header_vis.custom_minimum_size = Vector2(0, 120)
	_header_vis.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_header_vis)

	vbox.add_child(_spacer(6))

	# ── Başlık ──
	var title := Label.new()
	title.text = "SINGULARITY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.88, 0.90, 1.00, 0.95))
	title.add_theme_font_size_override("font_size", 26)
	vbox.add_child(title)

	vbox.add_child(_spacer(8))

	# ── Süre satırı ──
	var time_row := HBoxContainer.new()
	time_row.alignment = BoxContainer.ALIGNMENT_CENTER
	time_row.add_theme_constant_override("separation", 10)
	vbox.add_child(time_row)

	var collapsed_lbl := Label.new()
	collapsed_lbl.text = "COLLAPSED AT"
	collapsed_lbl.add_theme_color_override("font_color", Color(0.50, 0.55, 0.70, 0.80))
	collapsed_lbl.add_theme_font_size_override("font_size", 12)
	collapsed_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_row.add_child(collapsed_lbl)

	_time_label = Label.new()
	_time_label.text = "0.0s"
	_time_label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.00, 1.0))
	_time_label.add_theme_font_size_override("font_size", 36)
	time_row.add_child(_time_label)

	vbox.add_child(_spacer(16))
	vbox.add_child(_divider())
	vbox.add_child(_spacer(14))

	# ── Kaynak satırları ──
	var res_rows := _build_resource_rows()
	for row_container in res_rows:
		vbox.add_child(row_container)
		vbox.add_child(_spacer(8))

	vbox.add_child(_spacer(6))
	vbox.add_child(_divider())
	vbox.add_child(_spacer(12))

	# ── Toplam skor ──
	_score_label = Label.new()
	_score_label.text = "0  Ω"
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_color_override("font_color", Color(0.78, 0.70, 1.00, 1.0))
	_score_label.add_theme_font_size_override("font_size", 30)
	vbox.add_child(_score_label)

	vbox.add_child(_spacer(22))

	# ── Butonlar ──
	_retry_btn = _make_button("◉  COLLAPSE AGAIN", Color(0.55, 0.75, 1.00))
	_retry_btn.pressed.connect(func() -> void: retry_pressed.emit())
	vbox.add_child(_retry_btn)

	vbox.add_child(_spacer(10))

	_upgrade_btn = _make_button("UPGRADES", Color(0.60, 0.58, 0.90))
	_upgrade_btn.pressed.connect(func() -> void: upgrade_pressed.emit())
	vbox.add_child(_upgrade_btn)

	vbox.add_child(_spacer(8))

	_quit_btn = _make_button("RETURN TO VOID", Color(0.42, 0.42, 0.58))
	_quit_btn.pressed.connect(func() -> void: quit_pressed.emit())
	vbox.add_child(_quit_btn)


func _build_resource_rows() -> Array:
	var rows: Array = []

	var r1 := _make_resource_row("IRON",    COL_IRON,    "⬡")
	_iron_label = r1[0];  _iron_bar = r1[1]
	rows.append(r1[2])

	var r2 := _make_resource_row("GOLD",    COL_GOLD,    "◈")
	_gold_label = r2[0];  _gold_bar = r2[1]
	rows.append(r2[2])

	var r3 := _make_resource_row("CRYSTAL", COL_CRYSTAL, "◆")
	_crystal_label = r3[0]; _crystal_bar = r3[1]
	rows.append(r3[2])

	var r4 := _make_resource_row("URANIUM", COL_URANIUM, "☢")
	_uranium_label = r4[0]; _uranium_bar = r4[1]
	rows.append(r4[2])

	return rows


# ── Animasyon ──────────────────────────────────────────────────────────────────

func _start_animation(run_time: float, iron: int, gold: int, crystal: int, uranium: int) -> void:
	if _header_vis != null:
		_header_vis.start()

	# Bar max değerini ayarla
	var max_res := maxi(1, maxi(iron, maxi(gold, maxi(crystal, uranium))))
	if _iron_bar    != null: _iron_bar.max_value    = max_res
	if _gold_bar    != null: _gold_bar.max_value    = max_res
	if _crystal_bar != null: _crystal_bar.max_value = max_res
	if _uranium_bar != null: _uranium_bar.max_value = max_res

	var total := iron + gold * 3 + crystal * 5 + uranium * 10

	var tw := create_tween()
	tw.set_parallel(false)

	# Arka plan soluklaşması
	if _overlay != null:
		tw.tween_property(_overlay, "color:a", 0.88, 0.45).set_ease(Tween.EASE_IN)

	# Panel beliriş
	if _panel_root != null:
		tw.tween_property(_panel_root, "modulate:a", 1.0, 0.30).set_ease(Tween.EASE_OUT)

	# Süre sayacı
	tw.tween_method(
		func(v: float) -> void:
			if _time_label != null:
				_time_label.text = "%.1fs" % v,
		0.0, run_time, 0.55)

	# Kaynak satırları — stagger
	tw.tween_interval(0.08)
	tw.tween_method(
		func(v: int) -> void:
			if _iron_label != null: _iron_label.text = str(v)
			if _iron_bar   != null: _iron_bar.value  = v,
		0, iron, 0.35)

	tw.tween_interval(0.06)
	tw.tween_method(
		func(v: int) -> void:
			if _gold_label != null: _gold_label.text = str(v)
			if _gold_bar   != null: _gold_bar.value  = v,
		0, gold, 0.30)

	tw.tween_interval(0.06)
	tw.tween_method(
		func(v: int) -> void:
			if _crystal_label != null: _crystal_label.text = str(v)
			if _crystal_bar   != null: _crystal_bar.value  = v,
		0, crystal, 0.30)

	tw.tween_interval(0.06)
	tw.tween_method(
		func(v: int) -> void:
			if _uranium_label != null: _uranium_label.text = str(v)
			if _uranium_bar   != null: _uranium_bar.value  = v,
		0, uranium, 0.30)

	# Toplam skor
	tw.tween_interval(0.10)
	tw.tween_method(
		func(v: int) -> void:
			if _score_label != null:
				_score_label.text = "%d  Ω" % v,
		0, total, 0.45)


# ── Widget yardımcıları ───────────────────────────────────────────────────────

func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _divider() -> ColorRect:
	var c := ColorRect.new()
	c.custom_minimum_size = Vector2(0, 1)
	c.color = Color(1.0, 1.0, 1.0, 0.13)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Döndürür: [value_label, progress_bar, row_container]
func _make_resource_row(res_name: String, col: Color, icon: String) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var icon_lbl := Label.new()
	icon_lbl.text = icon
	icon_lbl.add_theme_color_override("font_color", col)
	icon_lbl.add_theme_font_size_override("font_size", 16)
	icon_lbl.custom_minimum_size = Vector2(22, 0)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	row.add_child(icon_lbl)

	var name_lbl := Label.new()
	name_lbl.text = res_name
	name_lbl.add_theme_color_override("font_color",
		Color(col.r * 0.68, col.g * 0.68, col.b * 0.68, 0.85))
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.custom_minimum_size = Vector2(70, 0)
	name_lbl.vertical_alignment  = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_lbl)

	var val_lbl := Label.new()
	val_lbl.text = "0"
	val_lbl.add_theme_color_override("font_color", col)
	val_lbl.add_theme_font_size_override("font_size", 16)
	val_lbl.custom_minimum_size  = Vector2(68, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	row.add_child(val_lbl)

	var bar := ProgressBar.new()
	bar.min_value    = 0.0
	bar.max_value    = 100.0
	bar.value        = 0.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical   = Control.SIZE_SHRINK_CENTER

	var sf_fill := StyleBoxFlat.new()
	sf_fill.bg_color = col
	sf_fill.corner_radius_top_left     = 2
	sf_fill.corner_radius_top_right    = 2
	sf_fill.corner_radius_bottom_right = 2
	sf_fill.corner_radius_bottom_left  = 2
	bar.add_theme_stylebox_override("fill", sf_fill)

	var sf_bg := StyleBoxFlat.new()
	sf_bg.bg_color = Color(1.0, 1.0, 1.0, 0.07)
	sf_bg.corner_radius_top_left     = 2
	sf_bg.corner_radius_top_right    = 2
	sf_bg.corner_radius_bottom_right = 2
	sf_bg.corner_radius_bottom_left  = 2
	bar.add_theme_stylebox_override("background", sf_bg)

	row.add_child(bar)

	return [val_lbl, bar, row]


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
	sn.bg_color    = Color(0.04, 0.01, 0.12, 0.88)
	sn.border_color = Color(accent.r * 0.48, accent.g * 0.48, accent.b * 0.48, 0.50)
	sn.border_width_left   = 1
	sn.border_width_right  = 1
	sn.border_width_top    = 1
	sn.border_width_bottom = 1
	sn.corner_radius_top_left     = 3
	sn.corner_radius_top_right    = 3
	sn.corner_radius_bottom_right = 3
	sn.corner_radius_bottom_left  = 3
	btn.add_theme_stylebox_override("normal", sn)

	var sh := StyleBoxFlat.new()
	sh.bg_color    = Color(accent.r * 0.14, accent.g * 0.14, accent.b * 0.20, 0.92)
	sh.border_color = Color(accent.r * 0.75, accent.g * 0.75, accent.b * 0.75, 0.72)
	sh.border_width_left   = 1
	sh.border_width_right  = 1
	sh.border_width_top    = 1
	sh.border_width_bottom = 1
	sh.corner_radius_top_left     = 3
	sh.corner_radius_top_right    = 3
	sh.corner_radius_bottom_right = 3
	sh.corner_radius_bottom_left  = 3
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("pressed", sn)

	return btn
