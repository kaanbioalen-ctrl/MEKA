extends Control
class_name ResourcePanel
## Left-side resource display panel.
## Shows Iron / Gold / Elmas with flash animation on value change.
## Pure Control — immune to Camera2D zoom.

const FLASH_DURATION: float = 0.50
const PANEL_W:  float = 200.0
const ROW_H:    float = 34.0
const LABEL_SZ: int   = 14

var _rows: Array[Dictionary] = []   # [{lbl, base_col, prev, flash}]

const RESOURCE_DEFS: Array[Dictionary] = [
	{"key": "iron",    "icon": "Fe", "label": "Iron",    "color": Color(0.78, 0.88, 1.0, 1.0)},
	{"key": "gold",    "icon": "Au", "label": "Gold",    "color": Color(1.0,  0.88, 0.38, 1.0)},
	{"key": "crystal", "icon": "El", "label": "Elmas", "color": Color(0.68, 1.0,  0.90, 1.0)},
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(PANEL_W, float(RESOURCE_DEFS.size()) * ROW_H + 24.0)
	_build_layout()
	set_process(true)


func _draw() -> void:
	# Draw panel background manually (works on plain Control nodes).
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.04, 0.07, 0.14, 0.90), true)
	draw_rect(r, Color(0.22, 0.40, 0.68, 0.58), false, 1.0)


func _build_layout() -> void:

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.position = Vector2(12.0, 12.0)
	vbox.size.x = PANEL_W - 24.0
	add_child(vbox)

	# Header
	var hdr := Label.new()
	hdr.text = "KAYNAKLAR"
	hdr.add_theme_font_size_override("font_size", 11)
	hdr.add_theme_color_override("font_color", Color(0.50, 0.70, 0.90, 0.75))
	vbox.add_child(hdr)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.22, 0.40, 0.68, 0.45))
	vbox.add_child(sep)

	# One row per resource
	_rows.clear()
	for rdef in RESOURCE_DEFS:
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)

		var icon_lbl := Label.new()
		icon_lbl.text = "[%s]" % str(rdef["icon"])
		icon_lbl.add_theme_font_size_override("font_size", LABEL_SZ)
		icon_lbl.add_theme_color_override("font_color",
			(rdef["color"] as Color).darkened(0.10))
		icon_lbl.custom_minimum_size = Vector2(36.0, 0.0)

		var val_lbl := Label.new()
		val_lbl.text = "--"
		val_lbl.add_theme_font_size_override("font_size", LABEL_SZ)
		val_lbl.add_theme_color_override("font_color", rdef["color"] as Color)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		hbox.add_child(icon_lbl)
		hbox.add_child(val_lbl)
		vbox.add_child(hbox)

		_rows.append({
			"lbl":      val_lbl,
			"base_col": rdef["color"] as Color,
			"prev":     -1,
			"flash":    0.0,
		})


## Call every frame while panel is visible.
## Pass -1 for any resource that is unknown.
func update_resources(iron: int, gold: int, crystal: int) -> void:
	var values := [iron, gold, crystal]
	for i in range(_rows.size()):
		var row := _rows[i]
		var lbl: Label = row["lbl"] as Label
		if lbl == null:
			continue
		var val: int = values[i]
		if val < 0:
			lbl.text = "--"
			continue
		var prev: int = int(row["prev"])
		if val != prev and prev >= 0:
			row["flash"] = 1.0   # trigger flash
		row["prev"] = val
		lbl.text = _fmt(val)


func _fmt(n: int) -> String:
	# Add thousands separator for readability
	var s := str(n)
	var result := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return result


func _process(delta: float) -> void:
	queue_redraw()
	for row in _rows:
		if float(row["flash"]) <= 0.0:
			continue
		row["flash"] = maxf(0.0, float(row["flash"]) - delta / FLASH_DURATION)
		var lbl: Label = row["lbl"] as Label
		if lbl == null:
			continue
		var t: float  = float(row["flash"])
		var base: Color = row["base_col"] as Color
		# Flash to white then back
		var flash_col := Color(
			lerpf(base.r, 1.0, t * 0.70),
			lerpf(base.g, 1.0, t * 0.70),
			lerpf(base.b, 1.0, t * 0.70),
			1.0)
		lbl.add_theme_color_override("font_color", flash_col)
		if t <= 0.0:
			lbl.add_theme_color_override("font_color", base)
