extends Node
## Premium ana menü — void estetiği, mouse wheel tab, stagger animasyon.

signal continue_pressed
signal new_game_pressed
signal settings_pressed
signal quit_pressed

const HEADER_SCRIPT      = preload("res://scripts/ui/main_menu_header_visual.gd")
const BG_SCRIPT          = preload("res://scripts/ui/main_menu_bg.gd")
const BORDER_SCRIPT      = preload("res://scripts/ui/main_menu_border_glow.gd")
const PARTICLES_BG_SCRIPT = preload("res://scripts/ui/menu_particles_bg.gd")

const PANEL_W : float = 440.0
const PANEL_H : float = 580.0
const TAB_W   : float = 376.0
const TAB_H   : float = 200.0

var _overlay      : ColorRect = null
var _panel_root   : Control   = null
var _continue_btn : Button    = null

# Stagger hedefleri (sırayla belirecek elemanlar)
var _stagger_nodes: Array = []

# Tab sistemi
var _tab_clip    : Control = null
var _tabs        : Array   = []
var _dot_labels  : Array   = []
var _current_tab : int     = 0
var _switching   : bool    = false

# Yeni oyun onayı
var _tab0_normal  : Control = null
var _tab0_confirm : Control = null
var _confirm_mode : bool    = false

# Kayıt verisi
var _save_data: Dictionary = {}


func _ready() -> void:
	set_process_input(true)
	var canvas := get_parent()
	for child in canvas.get_children():
		if child != self:
			child.queue_free()
	_load_save_data()
	_build_ui(canvas)
	_animate_in()


func setup_continue_button(enabled: bool, label: String) -> void:
	if _continue_btn == null:
		return
	_continue_btn.disabled   = not enabled
	_continue_btn.text       = label
	_continue_btn.modulate.a = 1.0 if enabled else 0.35


func toggle_settings_hint() -> void:
	pass


# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not get_parent().visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_switch_tab(1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_switch_tab(-1)


# ── Tab geçişi ────────────────────────────────────────────────────────────────

func _switch_tab(dir: int) -> void:
	if _switching or _tabs.is_empty():
		return
	var next := (_current_tab + dir) % _tabs.size()
	if next < 0:
		next += _tabs.size()
	if next == _current_tab:
		return
	_switching = true

	# Onay modu açıksa geri al
	if _confirm_mode:
		_exit_confirm_mode()

	var old_c := _tabs[_current_tab] as Control
	var new_c := _tabs[next]         as Control
	new_c.position.x = TAB_W * sign(dir)
	new_c.modulate.a = 0.0
	new_c.visible    = true

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(old_c, "position:x", -TAB_W * sign(dir), 0.22)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_property(old_c, "modulate:a", 0.0, 0.16)
	tw.tween_property(new_c, "position:x", 0.0, 0.24)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(new_c, "modulate:a", 1.0, 0.24)
	tw.chain().tween_callback(func() -> void:
		old_c.visible    = false
		old_c.position.x = 0.0
		_current_tab  = next
		_switching    = false
		_update_dots()
	)


func _update_dots() -> void:
	for i in range(_dot_labels.size()):
		var lbl    := _dot_labels[i] as Label
		var active := i == _current_tab
		lbl.add_theme_color_override("font_color",
			Color(0.88, 0.90, 1.00, 0.95) if active else Color(0.30, 0.33, 0.50, 0.45))
		lbl.add_theme_font_size_override("font_size", 12 if active else 8)


# ── Yeni oyun onayı ───────────────────────────────────────────────────────────

func _on_new_game_pressed() -> void:
	# Kayıt yoksa direkt başlat
	if _save_data.is_empty():
		new_game_pressed.emit()
		return
	_enter_confirm_mode()


func _enter_confirm_mode() -> void:
	if _confirm_mode:
		return
	_confirm_mode = true
	if _tab0_normal   != null: _tab0_normal.visible   = false
	if _tab0_confirm  != null: _tab0_confirm.visible  = true


func _exit_confirm_mode() -> void:
	_confirm_mode = false
	if _tab0_normal   != null: _tab0_normal.visible   = true
	if _tab0_confirm  != null: _tab0_confirm.visible  = false


# ── Kayıt verisi ──────────────────────────────────────────────────────────────

func _load_save_data() -> void:
	var sm: Node = Engine.get_main_loop().root.get_node_or_null("/root/SaveManager")
	if sm != null and sm.save_exists():
		_save_data = sm.read_save()


# ── UI İnşası ─────────────────────────────────────────────────────────────────

func _build_ui(canvas: Node) -> void:
	# Oyunu tamamen örten solid arka plan — en alt katman
	var solid := ColorRect.new()
	solid.set_anchors_preset(Control.PRESET_FULL_RECT)
	solid.color = Color(0.00, 0.00, 0.04, 1.0)
	solid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(solid)

	# Parçacık arka planı — yıldız sahasının altında
	var particles := PARTICLES_BG_SCRIPT.new()
	canvas.add_child(particles)

	# Arka plan — yıldız sahası
	var bg := BG_SCRIPT.new()
	canvas.add_child(bg)

	# Karartma overlay
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

	# Panel — sabit boyut
	_panel_root = Control.new()
	_panel_root.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	_panel_root.modulate.a = 0.0
	center.add_child(_panel_root)

	# Panel arka planı
	var panel_bg := ColorRect.new()
	panel_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_bg.color = Color(0.03, 0.00, 0.10, 0.86)
	panel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(panel_bg)

	# Panel kenar glow
	var border := BORDER_SCRIPT.new()
	_panel_root.add_child(border)

	# İçerik
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   32)
	margin.add_theme_constant_override("margin_right",  32)
	margin.add_theme_constant_override("margin_top",    20)
	margin.add_theme_constant_override("margin_bottom", 24)
	_panel_root.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	margin.add_child(vbox)

	# ── Başlık — kürenin ÜSTÜNDE ──
	var title_block := VBoxContainer.new()
	title_block.add_theme_constant_override("separation", 0)
	title_block.modulate.a = 0.0
	_stagger_nodes.append(title_block)
	vbox.add_child(title_block)

	var title := Label.new()
	title.text = "V O I D"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.88, 0.90, 1.00, 0.97))
	title.add_theme_font_size_override("font_size", 34)
	title_block.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "MINING PROTOCOL"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.38, 0.44, 0.62, 0.65))
	subtitle.add_theme_font_size_override("font_size", 11)
	title_block.add_child(subtitle)

	vbox.add_child(_spacer(10))

	# ── Header görsel ──
	var hv := HEADER_SCRIPT.new()
	hv.custom_minimum_size   = Vector2(0, 130)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.modulate.a = 0.0
	_stagger_nodes.append(hv)
	vbox.add_child(hv)

	vbox.add_child(_spacer(10))

	# ── Tab gösterge noktaları ──
	var dot_row := HBoxContainer.new()
	dot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dot_row.add_theme_constant_override("separation", 14)
	dot_row.modulate.a = 0.0
	_stagger_nodes.append(dot_row)
	vbox.add_child(dot_row)

	for i in range(3):
		var dot := Label.new()
		dot.text = "●"
		_dot_labels.append(dot)
		dot_row.add_child(dot)
	_update_dots()

	vbox.add_child(_spacer(10))

	# ── Tab clip alanı ──
	_tab_clip = Control.new()
	_tab_clip.clip_contents       = true
	_tab_clip.custom_minimum_size = Vector2(0, TAB_H)
	_tab_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_clip.modulate.a = 0.0
	_stagger_nodes.append(_tab_clip)
	vbox.add_child(_tab_clip)

	_build_tab_launch()
	_build_tab_system()
	_build_tab_void()

	vbox.add_child(_spacer(8))

	# ── Alt ipucu ──
	var hint := Label.new()
	hint.text = "scroll  ·  tab değiştir"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.28, 0.30, 0.45, 0.40))
	hint.add_theme_font_size_override("font_size", 10)
	hint.modulate.a = 0.0
	_stagger_nodes.append(hint)
	vbox.add_child(hint)


# ── Tab 0: LAUNCH ─────────────────────────────────────────────────────────────

func _build_tab_launch() -> void:
	var tab := _make_tab_root()
	_tab_clip.add_child(tab)
	_tabs.append(tab)

	_add_tab_label(tab, "LAUNCH", Color(0.55, 0.75, 1.00))
	tab.add_child(_spacer(8))

	# Kayıt özeti (varsa)
	if not _save_data.is_empty():
		var summary := _build_save_summary()
		tab.add_child(summary)
		tab.add_child(_spacer(6))

	# Normal butonlar
	_tab0_normal = VBoxContainer.new()
	_tab0_normal.add_theme_constant_override("separation", 8)
	tab.add_child(_tab0_normal)

	_continue_btn = _make_button("DEVAM ET", Color(0.55, 0.75, 1.00))
	_continue_btn.disabled   = true
	_continue_btn.modulate.a = 0.35
	_continue_btn.pressed.connect(func() -> void: continue_pressed.emit())
	_tab0_normal.add_child(_continue_btn)

	var new_btn := _make_button("YENİ OYUN", Color(0.50, 0.85, 0.55))
	new_btn.pressed.connect(_on_new_game_pressed)
	_tab0_normal.add_child(new_btn)

	# Onay ekranı (gizli)
	_tab0_confirm = VBoxContainer.new()
	_tab0_confirm.add_theme_constant_override("separation", 8)
	_tab0_confirm.visible = false
	tab.add_child(_tab0_confirm)

	var warn := Label.new()
	warn.text = "Mevcut kayıt silinecek.\nEmin misin?"
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn.add_theme_color_override("font_color", Color(1.00, 0.65, 0.40, 0.90))
	warn.add_theme_font_size_override("font_size", 13)
	_tab0_confirm.add_child(warn)

	_tab0_confirm.add_child(_spacer(6))

	var confirm_btn := _make_button("ONAYLA", Color(0.85, 0.45, 0.40))
	confirm_btn.pressed.connect(func() -> void:
		_exit_confirm_mode()
		new_game_pressed.emit())
	_tab0_confirm.add_child(confirm_btn)

	var cancel_btn := _make_button("İPTAL", Color(0.45, 0.48, 0.65))
	cancel_btn.pressed.connect(_exit_confirm_mode)
	_tab0_confirm.add_child(cancel_btn)


func _build_save_summary() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)

	var items := [
		["⬡", Color(0.54, 0.63, 0.73), int(_save_data.get("iron",    0))],
		["◈", Color(1.00, 0.82, 0.40), int(_save_data.get("gold",    0))],
		["◆", Color(0.48, 0.94, 0.88), int(_save_data.get("crystal", 0))],
		["☢", Color(0.70, 1.00, 0.24), int(_save_data.get("uranium", 0))],
	]
	for item in items:
		var col := HBoxContainer.new()
		col.add_theme_constant_override("separation", 3)

		var icon := Label.new()
		icon.text = item[0] as String
		icon.add_theme_color_override("font_color", item[1] as Color)
		icon.add_theme_font_size_override("font_size", 13)
		col.add_child(icon)

		var val := Label.new()
		val.text = str(item[2] as int)
		val.add_theme_color_override("font_color", Color(0.70, 0.72, 0.85, 0.80))
		val.add_theme_font_size_override("font_size", 12)
		val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		col.add_child(val)

		row.add_child(col)

	return row


# ── Tab 1: SYSTEM ─────────────────────────────────────────────────────────────

func _build_tab_system() -> void:
	var tab := _make_tab_root()
	tab.visible    = false
	tab.modulate.a = 0.0
	_tab_clip.add_child(tab)
	_tabs.append(tab)

	_add_tab_label(tab, "SYSTEM", Color(0.60, 0.58, 0.90))
	tab.add_child(_spacer(16))

	var lbl := Label.new()
	lbl.text = "Ayarlar bölümü yakında."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(0.50, 0.50, 0.72, 0.65))
	lbl.add_theme_font_size_override("font_size", 14)
	tab.add_child(lbl)


# ── Tab 2: VOID ───────────────────────────────────────────────────────────────

func _build_tab_void() -> void:
	var tab := _make_tab_root()
	tab.visible    = false
	tab.modulate.a = 0.0
	_tab_clip.add_child(tab)
	_tabs.append(tab)

	_add_tab_label(tab, "VOID", Color(0.65, 0.38, 0.38))
	tab.add_child(_spacer(14))

	var quit_btn := _make_button("VOID'E DÖN", Color(0.65, 0.38, 0.38))
	quit_btn.pressed.connect(func() -> void: quit_pressed.emit())
	tab.add_child(quit_btn)


# ── Animasyon ─────────────────────────────────────────────────────────────────

func _animate_in() -> void:
	var tw := create_tween()
	tw.set_parallel(false)

	# Arka plan + overlay
	if _overlay != null:
		tw.tween_property(_overlay, "color:a", 0.72, 0.55).set_ease(Tween.EASE_IN)

	# Panel belirir
	if _panel_root != null:
		tw.tween_property(_panel_root, "modulate:a", 1.0, 0.30).set_ease(Tween.EASE_OUT)

	# Stagger — her eleman 0.10s arayla
	for node in _stagger_nodes:
		tw.tween_property(node, "modulate:a", 1.0, 0.22).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.06)


# ── Widget yardımcıları ───────────────────────────────────────────────────────

func _make_tab_root() -> VBoxContainer:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 0)
	c.custom_minimum_size = Vector2(TAB_W, 0)
	return c


func _add_tab_label(parent: Control, text: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(col.r, col.g, col.b, 0.60))
	lbl.add_theme_font_size_override("font_size", 11)
	parent.add_child(lbl)

	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = Color(col.r, col.g, col.b, 0.18)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(div)


func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _make_button(label: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size   = Vector2(0, 46)
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
