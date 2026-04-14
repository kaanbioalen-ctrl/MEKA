class_name BlackHolePanel
extends CanvasLayer

# ─── Sinyaller ───────────────────────────────────────────────────────────────
signal closed

# ─── Renkler ─────────────────────────────────────────────────────────────────
const C_BG         := Color(0.03, 0.01, 0.10, 0.96)
const C_BORDER     := Color(0.55, 0.08, 1.00, 0.90)
const C_TITLE      := Color(0.85, 0.45, 1.00, 1.00)
const C_TEXT       := Color(0.90, 0.90, 1.00, 1.00)
const C_DIM        := Color(0.60, 0.60, 0.75, 1.00)
const C_EXP_FILL   := Color(0.55, 0.10, 1.00, 1.00)
const C_EXP_BG     := Color(0.10, 0.03, 0.20, 1.00)
const C_IRON       := Color(0.80, 0.86, 0.93, 1.00)
const C_GOLD       := Color(1.00, 0.84, 0.22, 1.00)
const C_CRYSTAL    := Color(0.40, 0.92, 1.00, 1.00)
const C_BTN        := Color(0.15, 0.05, 0.30, 1.00)
const C_BTN_HOVER  := Color(0.28, 0.08, 0.50, 1.00)
const C_BTN_CLOSE  := Color(0.18, 0.03, 0.06, 1.00)
const C_FLASH      := Color(0.80, 0.50, 1.00, 1.00)
const C_HEADER_BG  := Color(0.08, 0.02, 0.18, 1.00)

# ─── UI Düğümleri ─────────────────────────────────────────────────────────────
var _bh_draw:        Control
var _level_label:    Label
var _next_lvl_label: Label   ## Bir sonraki seviye için gereken EXP
var _exp_bar:        ProgressBar
var _exp_label:      Label
var _iron_label:     Label
var _gold_label:     Label
var _crystal_label:  Label
var _iron_btn:       Button
var _gold_btn:       Button
var _crystal_btn:    Button
var _all_btn:        Button
var _result_label:   Label
var _close_btn:      Button
var _panel_root:     Control  ## Tüm paneli tutan kök Control

# ─── Animasyon ───────────────────────────────────────────────────────────────
var _flash_t:    float              = 0.0
var _particles:  Array[Dictionary]  = []
var _bh_time:    float              = 0.0
var _slide_t:    float              = 0.0   ## 0.0 = kapalı, 1.0 = tam açık
var _is_opening: bool               = false

var _exp_style_normal: StyleBoxFlat = null
var _exp_style_flash:  StyleBoxFlat = null

var _black_hole: Node = null

# ─── Yaşam Döngüsü ───────────────────────────────────────────────────────────
func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	layer        = 20
	hide()
	_build_ui()
	_init_cached_styles()


func _process(delta: float) -> void:
	if not visible:
		return
	_bh_time  += delta
	_flash_t   = maxf(_flash_t - delta * 2.5, 0.0)
	_update_particles(delta)
	_refresh_ui()
	_bh_draw.queue_redraw()
	_animate_slide(delta)

# ─── Public API ──────────────────────────────────────────────────────────────
func open(black_hole: Node) -> void:
	_black_hole        = black_hole
	_result_label.text = ""
	_particles.clear()
	_slide_t    = 0.0
	_is_opening = true
	_apply_slide(0.0)
	_refresh_ui()
	show()
	# Oyun durdurulmaz — player paneli açıkken de hareket edebilir


func close() -> void:
	hide()
	_black_hole = null
	_is_opening = false
	closed.emit()

# ─── UI İnşası ───────────────────────────────────────────────────────────────
func _build_ui() -> void:
	# Panel kök — tam ekran (tıklama geçirgen, sadece panel içi aktif)
	_panel_root = Control.new()
	_panel_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel_root)

	# ── Sağ kenar side-panel: ekran genişliğinin 1/4'ü, tam yükseklik
	var panel := PanelContainer.new()
	panel.anchor_left   = 0.75   # 3/4 konumundan başla
	panel.anchor_right  = 1.0    # Ekranın sağ kenarına kadar
	panel.anchor_top    = 0.0
	panel.anchor_bottom = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical   = Control.GROW_DIRECTION_BOTH

	var style := StyleBoxFlat.new()
	style.bg_color        = C_BG
	style.border_color    = C_BORDER
	style.set_border_width_all(0)
	style.border_width_left = 2   # Sol kenar çizgisi
	style.shadow_color    = Color(0.5, 0.0, 1.0, 0.50)
	style.shadow_size     = 24
	panel.add_theme_stylebox_override("panel", style)
	_panel_root.add_child(panel)

	# ── İçerik: ScrollContainer → VBox (uzun içerik varsa kaydırılabilir)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   28)
	margin.add_theme_constant_override("margin_right",  28)
	margin.add_theme_constant_override("margin_top",    28)
	margin.add_theme_constant_override("margin_bottom", 28)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	# ── Başlık bölgesi
	var header_bg := PanelContainer.new()
	var hbg_style := StyleBoxFlat.new()
	hbg_style.bg_color = C_HEADER_BG
	hbg_style.set_corner_radius_all(8)
	header_bg.add_theme_stylebox_override("panel", hbg_style)
	vbox.add_child(header_bg)

	var header_vbox := VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 6)
	var header_margin := MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left",   16)
	header_margin.add_theme_constant_override("margin_right",  16)
	header_margin.add_theme_constant_override("margin_top",    14)
	header_margin.add_theme_constant_override("margin_bottom", 14)
	header_margin.add_child(header_vbox)
	header_bg.add_child(header_margin)

	# Mini karadelik çizim alanı
	_bh_draw = Control.new()
	_bh_draw.custom_minimum_size = Vector2(0, 100)
	_bh_draw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bh_draw.draw.connect(_on_bh_draw)
	header_vbox.add_child(_bh_draw)

	header_vbox.add_child(_lbl("K A R A D E L İ K", 20, C_TITLE, HORIZONTAL_ALIGNMENT_CENTER))

	_level_label = _lbl("SEVİYE  1  /  30", 24, C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	header_vbox.add_child(_level_label)

	# Sonraki seviye bilgisi
	_next_lvl_label = _lbl("Sonraki seviye için  50  EXP gerekli", 13, C_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	header_vbox.add_child(_next_lvl_label)

	vbox.add_child(_sep())

	# ── EXP Bar bölgesi
	vbox.add_child(_lbl("TECRÜBEPUANı", 12, C_DIM, HORIZONTAL_ALIGNMENT_CENTER))

	_exp_bar = ProgressBar.new()
	_exp_bar.min_value           = 0.0
	_exp_bar.max_value           = 100.0
	_exp_bar.value               = 0.0
	_exp_bar.show_percentage     = false
	_exp_bar.custom_minimum_size = Vector2(0, 32)
	_exp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = C_EXP_FILL
	fill_style.set_corner_radius_all(6)
	_exp_bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color     = C_EXP_BG
	bg_style.border_color = C_BORDER
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(6)
	_exp_bar.add_theme_stylebox_override("background", bg_style)
	vbox.add_child(_exp_bar)

	_exp_label = _lbl("0 / 50  EXP", 14, C_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	vbox.add_child(_exp_label)

	vbox.add_child(_sep())

	# ── Element dönüşümü bölgesi
	vbox.add_child(_lbl("ELEMENTLERİ ENERJİYE DÖNÜŞTÜR", 12, C_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	vbox.add_child(_lbl("Elementler karadeliğin EXP'sini artırır", 11,
			Color(0.5, 0.5, 0.65, 1.0), HORIZONTAL_ALIGNMENT_CENTER))

	vbox.add_child(_sep())

	# Demir
	var iron_row := _resource_row("🪨  Demir", C_IRON, "× 1 ⚡  →  Dönüştür")
	_iron_label  = iron_row[0] as Label
	_iron_btn    = iron_row[1] as Button
	_iron_btn.pressed.connect(func(): _convert("iron"))
	vbox.add_child(iron_row[2])

	# Altın
	var gold_row := _resource_row("💛  Altın", C_GOLD, "× 5 ⚡  →  Dönüştür")
	_gold_label  = gold_row[0] as Label
	_gold_btn    = gold_row[1] as Button
	_gold_btn.pressed.connect(func(): _convert("gold"))
	vbox.add_child(gold_row[2])

	# Elmas
	var crys_row    := _resource_row("💎  Elmas", C_CRYSTAL, "× 20 ⚡  →  Dönüştür")
	_crystal_label  = crys_row[0] as Label
	_crystal_btn    = crys_row[1] as Button
	_crystal_btn.pressed.connect(func(): _convert("crystal"))
	_crystal_label.text = "💎  Elmas"
	vbox.add_child(crys_row[2])

	vbox.add_child(_sep())

	# Tümünü dönüştür
	_all_btn = _btn("✦   Tüm Elementleri Dönüştür   ✦", C_BTN)
	_all_btn.custom_minimum_size = Vector2(0, 48)
	_all_btn.pressed.connect(_convert_all)
	vbox.add_child(_all_btn)

	# Sonuç
	_result_label = _lbl("", 15, C_EXP_FILL, HORIZONTAL_ALIGNMENT_CENTER)
	vbox.add_child(_result_label)

	vbox.add_child(_sep())

	# Açıklama
	vbox.add_child(_lbl("Uzaklaştığında panel kapanır", 11,
			Color(0.4, 0.4, 0.55, 0.8), HORIZONTAL_ALIGNMENT_CENTER))

	# Kapat butonu
	_close_btn = _btn("Kapat  ( uzaklaş )", C_BTN_CLOSE)
	_close_btn.custom_minimum_size = Vector2(0, 40)
	_close_btn.pressed.connect(close)
	vbox.add_child(_close_btn)

# ─── Slide-in Animasyonu ─────────────────────────────────────────────────────
func _animate_slide(delta: float) -> void:
	if not _is_opening:
		return
	_slide_t = minf(_slide_t + delta * 6.0, 1.0)  # ~0.17 s açılış
	_apply_slide(_slide_t)


func _apply_slide(t: float) -> void:
	if _panel_root == null:
		return
	# t=0: panel tamamen sağ dışında, t=1: tam yerinde
	var eased := 1.0 - pow(1.0 - t, 3.0)  # ease-out cubic
	# Panel genişliğini viewport'tan hesapla
	var vp_w  := get_viewport().get_visible_rect().size.x if get_viewport() else 1920.0
	var offset := vp_w * 0.25 * (1.0 - eased)
	_panel_root.position = Vector2(offset, 0.0)

# ─── Mini Karadelik Çizimi ────────────────────────────────────────────────────
func _on_bh_draw() -> void:
	if _bh_draw == null:
		return
	var w      := _bh_draw.size.x if _bh_draw.size.x > 1.0 else 400.0
	var h      := _bh_draw.size.y if _bh_draw.size.y > 1.0 else 100.0
	var center := Vector2(w * 0.5, h * 0.5)
	var r      := minf(h * 0.32, 30.0)

	# Dış ışıma
	for i in 4:
		var t    := float(i) / 3.0
		var glow := Color(0.5, 0.05, 1.0, 0.07 * (1.0 - t) + 0.01)
		_bh_draw.draw_circle(center, r * (2.0 + t * 2.5), glow)

	# Akkresyon diski
	var disk_colors: Array[Color] = [
		Color(1.0, 0.95, 0.70, 0.80),
		Color(1.0, 0.55, 0.10, 0.65),
		Color(0.85, 0.18, 0.04, 0.45),
	]
	for i in 3:
		var rot := _bh_time * (1.8 - i * 0.5)
		var dr  := r * (1.05 + i * 0.22)
		_bh_draw.draw_arc(center, dr, rot, rot + TAU * 0.90, 48, disk_colors[i], 4.0 - i)

	# Foton halkası
	var ph := 0.85 + 0.15 * sin(_bh_time * 3.2)
	_bh_draw.draw_arc(center, r * 0.42, 0.0, TAU, 48,
		Color(1.0, 0.95, 0.85, 0.90 * ph), 5.0)

	# EXP parlama — dönüşüm sonrası ring
	if _flash_t > 0.0:
		_bh_draw.draw_arc(center, r * 1.5, 0.0, TAU, 48,
			Color(C_EXP_FILL.r, C_EXP_FILL.g, C_EXP_FILL.b, _flash_t * 0.7), 3.0)

	# Siyah merkez
	_bh_draw.draw_circle(center, r * 0.40, Color(0.0, 0.0, 0.0, 1.0))

	# Parçacıklar
	for p in _particles:
		var col: Color = p["color"] as Color
		col.a = float(p["alpha"])
		_bh_draw.draw_circle(p["pos"] as Vector2, float(p["size"]), col)

# ─── Dönüşüm Eylemleri ───────────────────────────────────────────────────────
func _convert(resource: String) -> void:
	if _black_hole == null:
		return
	var rs := get_node_or_null("/root/RunState")
	if rs == null:
		return
	var iron    := int(rs.iron)    if resource == "iron"    else 0
	var gold    := int(rs.gold)    if resource == "gold"    else 0
	var crystal := int(rs.crystal) if resource == "crystal" else 0
	_do_convert(iron, gold, crystal)


func _convert_all() -> void:
	if _black_hole == null:
		return
	var rs := get_node_or_null("/root/RunState")
	if rs == null:
		return
	_do_convert(int(rs.iron), int(rs.gold), int(rs.crystal))


func _do_convert(iron: int, gold: int, crystal: int) -> void:
	if iron == 0 and gold == 0 and crystal == 0:
		_result_label.text = "Dönüştürülecek element yok."
		return
	var gained: float = _black_hole.call("convert_resources", iron, gold, crystal)
	_result_label.text = "+ %.0f  ⚡  enerji karadeliğe aktarıldı!" % gained
	_flash_t = 1.0
	_spawn_particles(iron, gold, crystal)

# ─── Parçacık Animasyonu ─────────────────────────────────────────────────────
func _spawn_particles(iron: int, gold: int, crystal: int) -> void:
	var w      := _bh_draw.size.x if _bh_draw.size.x > 1.0 else 400.0
	var h      := _bh_draw.size.y if _bh_draw.size.y > 1.0 else 100.0
	var center := Vector2(w * 0.5, h * 0.5)
	var types: Array[Dictionary] = []
	if iron    > 0: types.append({"color": C_IRON,    "count": mini(iron,    8)})
	if gold    > 0: types.append({"color": C_GOLD,    "count": mini(gold,    6)})
	if crystal > 0: types.append({"color": C_CRYSTAL, "count": mini(crystal, 4)})

	for t in types:
		for _i in int(t["count"]):
			var angle := randf_range(0.0, TAU)
			var dist  := randf_range(38.0, 62.0)
			_particles.append({
				"pos":   Vector2(cos(angle), sin(angle)) * dist + center,
				"vel":   (center - (Vector2(cos(angle), sin(angle)) * dist + center)).normalized()
						 * randf_range(55.0, 110.0),
				"color": t["color"],
				"size":  randf_range(2.5, 4.5),
				"alpha": 1.0,
			})


func _update_particles(delta: float) -> void:
	if _particles.is_empty():
		return
	var w      := _bh_draw.size.x if _bh_draw and _bh_draw.size.x > 1.0 else 240.0
	var h      := _bh_draw.size.y if _bh_draw and _bh_draw.size.y > 1.0 else 100.0
	var center := Vector2(w * 0.5, h * 0.5)

	for p in _particles:
		p["pos"]   = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
		p["alpha"] = maxf(float(p["alpha"]) - delta * 1.8, 0.0)
		var to_center := center - (p["pos"] as Vector2)
		if to_center.length_squared() > 0.01:
			p["vel"] = (p["vel"] as Vector2) + to_center.normalized() * 160.0 * delta

	_particles = _particles.filter(func(p: Dictionary) -> bool:
		return float(p["alpha"]) > 0.0
	)

# ─── UI Güncelleme ────────────────────────────────────────────────────────────
func _refresh_ui() -> void:
	if _black_hole == null:
		return
	var rs        := get_node_or_null("/root/RunState")
	var lvl       := int(_black_hole.call("get_level"))
	var bar_ratio := float(_black_hole.call("get_energy_bar_ratio"))
	var bar_text  := str(_black_hole.call("get_energy_bar_text"))

	_level_label.text = "SEVİYE   %d   /   %d" % [lvl, BlackHoleController.MAX_LEVEL]

	# Bir sonraki seviye için gereken EXP bilgisi
	if lvl >= BlackHoleController.MAX_LEVEL:
		_next_lvl_label.text = "— Maksimum seviyeye ulaşıldı —"
	else:
		var idx     := lvl - 1
		var needed  := BlackHoleController.LEVEL_THRESHOLDS[idx] if idx < BlackHoleController.LEVEL_THRESHOLDS.size() else 0.0
		_next_lvl_label.text = "Sonraki seviye için   %.0f  EXP gerekli" % needed

	_exp_bar.value  = bar_ratio * 100.0
	_exp_label.text = bar_text + "  EXP"

	if _flash_t > 0.0:
		_exp_style_flash.bg_color = C_EXP_FILL.lerp(C_FLASH, _flash_t * 0.6)
		_exp_bar.add_theme_stylebox_override("fill", _exp_style_flash)
	else:
		_exp_bar.add_theme_stylebox_override("fill", _exp_style_normal)

	var iron    := int(rs.iron)    if rs else 0
	var gold    := int(rs.gold)    if rs else 0
	var crystal := int(rs.crystal) if rs else 0

	_iron_label.text    = "🪨  Demir        %d  adet" % iron
	_gold_label.text    = "💛  Altın         %d  adet" % gold
	_crystal_label.text = "💎  Elmas        %d  adet" % crystal

	_iron_btn.disabled    = iron    == 0
	_gold_btn.disabled    = gold    == 0
	_crystal_btn.disabled = crystal == 0
	_all_btn.disabled     = (iron + gold + crystal) == 0

	if _crystal_label != null:
		_crystal_label.text = "💎  Elmas        %d  adet" % crystal

# ─── UI Yardımcıları ──────────────────────────────────────────────────────────
func _lbl(text: String, size: int, color: Color, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.text                 = text
	l.horizontal_alignment = align
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	return l


func _btn(text: String, bg: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size   = Vector2(0, 36)
	b.add_theme_color_override("font_color", C_TEXT)
	b.add_theme_font_size_override("font_size", 14)
	var s := StyleBoxFlat.new()
	s.bg_color     = bg
	s.set_corner_radius_all(6)
	s.set_border_width_all(1)
	s.border_color = C_BORDER
	b.add_theme_stylebox_override("normal", s)
	var h := s.duplicate() as StyleBoxFlat
	h.bg_color = C_BTN_HOVER
	b.add_theme_stylebox_override("hover", h)
	return b


## Döndürür: [label, button, hbox]
func _resource_row(label_text: String, label_color: Color, btn_text: String) -> Array:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lbl  := _lbl(label_text, 15, label_color, HORIZONTAL_ALIGNMENT_LEFT)
	hbox.add_child(lbl)
	var btn  := _btn(btn_text, C_BTN)
	btn.custom_minimum_size = Vector2(180, 36)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	hbox.add_child(btn)
	return [lbl, btn, hbox]


func _sep() -> HSeparator:
	var s  := HSeparator.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color             = Color(0.40, 0.06, 0.70, 0.35)
	ss.content_margin_top    = 2
	ss.content_margin_bottom = 2
	s.add_theme_stylebox_override("separator", ss)
	return s


func _init_cached_styles() -> void:
	_exp_style_normal          = StyleBoxFlat.new()
	_exp_style_normal.bg_color = C_EXP_FILL
	_exp_style_normal.set_corner_radius_all(6)

	_exp_style_flash           = StyleBoxFlat.new()
	_exp_style_flash.bg_color  = C_EXP_FILL
	_exp_style_flash.set_corner_radius_all(6)
