extends CanvasLayer

@export var player_path: NodePath = NodePath("../Player")
@onready var energy_bar_frame: ColorRect = $EnergyBarFrame
@onready var energy_bar_fill: ColorRect = $EnergyBarFrame/EnergyBarFill
@onready var energy_bar_text: Label = $EnergyBarFrame/EnergyBarText
@onready var iron_label: Label = $IronLabel
@onready var gold_label: Label = $GoldLabel
@onready var crystal_label: Label = $CrystalLabel
@onready var uranium_label: Label = get_node_or_null("UraniumLabel") as Label
@onready var titanium_label: Label = get_node_or_null("TitaniumLabel") as Label
@onready var multiplier_label: Label = $MultiplierLabel
@onready var time_label: Label = $TimeLabel
@onready var zone_label: Label = $ZoneLabel
@onready var speed_label: Label = $SpeedLabel
@onready var player_konumu_label: Label = $PlayerKonumuLabel
@onready var player_label: Label = $PlayerLabel
@onready var attraction_radius_label: Label = $AttractionRadiusLabel
@onready var energy_field_radius_label: Label = $EnergyFieldRadiusLabel
@onready var damage_radius_label: Label = $DamageRadiusLabel
@onready var minimap_frame: ColorRect = $MinimapFrame
@onready var minimap_border: ColorRect = $MinimapFrame/MinimapBorder
@onready var minimap_storm_marker: ColorRect = $MinimapFrame/StormMarker
@onready var minimap_player_glow: ColorRect = $MinimapFrame/PlayerGlow
@onready var minimap_player_marker: ColorRect = $MinimapFrame/PlayerMarker
@onready var minimap_portal_marker: ColorRect = $MinimapFrame/PortalMarker

var _player: Node = null
var _energy_fx_time: float = 0.0
var _attract_lbl: Label = null
var _minimap_titanium_markers: Array[ColorRect] = []
var _minimap_sulfur_markers: Array[ColorRect] = []
var _minimap_wind_markers: Array[ColorRect] = []

const RESOURCE_LABEL_FONT_SIZE: int = 15
const RESOURCE_LABEL_OUTLINE_SIZE: int = 2
const RESOURCE_LABEL_VERTICAL_GAP: float = 22.0
const RESOURCE_LABEL_SHADOW: Color = Color(0.02, 0.04, 0.08, 0.92)
const INFO_LABEL_FONT_SIZE: int = 14
const MINIMAP_MARKER_SCALE: float = 1.0
const MINIMAP_FRAME_SCALE: float = 1.5
const MINIMAP_SCREEN_MARGIN: float = 16.0
const MINIMAP_BOTTOM_OFFSET: float = 64.0

const MINIMAP_CIRCLE_SHADER_CODE := """
shader_type canvas_item;

void fragment() {
	vec2 centered_uv = UV * 2.0 - vec2(1.0);
	if (dot(centered_uv, centered_uv) > 1.0) {
		discard;
	}
}
"""


func _ready() -> void:
	_player = get_node_or_null(player_path)
	_ensure_uranium_label()
	_ensure_titanium_label()
	_style_resource_labels()
	_style_info_labels()
	_style_minimap_frame()
	_style_minimap_markers()
	_build_attract_label()
	_update_text()


func _ensure_uranium_label() -> void:
	if uranium_label != null:
		return
	if crystal_label == null:
		return
	uranium_label = Label.new()
	uranium_label.name = "UraniumLabel"
	uranium_label.position = crystal_label.position + Vector2(0.0, RESOURCE_LABEL_VERTICAL_GAP)
	uranium_label.size = crystal_label.size
	uranium_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	uranium_label.horizontal_alignment = crystal_label.horizontal_alignment
	uranium_label.vertical_alignment = crystal_label.vertical_alignment
	add_child(uranium_label)


func _ensure_titanium_label() -> void:
	if titanium_label != null:
		return
	var anchor_label := uranium_label if uranium_label != null else crystal_label
	if anchor_label == null:
		return
	titanium_label = Label.new()
	titanium_label.name = "TitaniumLabel"
	titanium_label.position = anchor_label.position + Vector2(0.0, RESOURCE_LABEL_VERTICAL_GAP)
	titanium_label.size = anchor_label.size
	titanium_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	titanium_label.horizontal_alignment = anchor_label.horizontal_alignment
	titanium_label.vertical_alignment = anchor_label.vertical_alignment
	add_child(titanium_label)


func _style_resource_labels() -> void:
	var labels: Array[Label] = [iron_label, gold_label, crystal_label, uranium_label, titanium_label]
	var colors: Array[Color] = [
		Color(0.90, 0.96, 1.0, 1.0),
		Color(1.0, 0.87, 0.38, 1.0),
		Color(0.48, 0.90, 1.0, 1.0),
		Color(0.32, 1.0, 0.20, 1.0),
		Color(0.72, 0.90, 1.0, 1.0),
	]
	var base_position := Vector2.ZERO
	if iron_label != null:
		base_position = iron_label.position
	for i in range(labels.size()):
		var label := labels[i]
		if label == null:
			continue
		label.position = base_position + Vector2(0.0, RESOURCE_LABEL_VERTICAL_GAP * i)
		label.size = Vector2(maxf(label.size.x, 190.0), maxf(label.size.y, 20.0))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", RESOURCE_LABEL_FONT_SIZE)
		label.add_theme_constant_override("outline_size", RESOURCE_LABEL_OUTLINE_SIZE)
		label.add_theme_color_override("font_outline_color", RESOURCE_LABEL_SHADOW)
		label.add_theme_color_override("font_color", colors[i])


func _style_info_labels() -> void:
	var labels: Array[Label] = [
		multiplier_label,
		time_label,
		zone_label,
		speed_label,
		player_konumu_label,
		player_label,
		attraction_radius_label,
		energy_field_radius_label,
		damage_radius_label,
	]
	for label in labels:
		if label == null:
			continue
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", INFO_LABEL_FONT_SIZE)
		label.add_theme_constant_override("outline_size", RESOURCE_LABEL_OUTLINE_SIZE)
		label.add_theme_color_override("font_outline_color", RESOURCE_LABEL_SHADOW)


func _style_minimap_frame() -> void:
	if minimap_frame == null:
		return
	var old_size := minimap_frame.size
	var new_size := old_size * MINIMAP_FRAME_SCALE
	var unified_color := Color(0.01, 0.01, 0.015, 0.92)
	minimap_frame.size = new_size
	minimap_frame.color = unified_color
	if minimap_border != null:
		minimap_border.size = new_size
		minimap_border.color = unified_color
	_position_minimap_frame()


func _position_minimap_frame() -> void:
	if minimap_frame == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	minimap_frame.position = Vector2(
		MINIMAP_SCREEN_MARGIN,
		maxf(MINIMAP_SCREEN_MARGIN, viewport_size.y - minimap_frame.size.y - MINIMAP_BOTTOM_OFFSET)
	)


func _style_minimap_markers() -> void:
	_style_minimap_marker(minimap_storm_marker, MINIMAP_MARKER_SCALE)
	_style_minimap_marker(minimap_player_marker, MINIMAP_MARKER_SCALE)
	_style_minimap_marker(minimap_portal_marker, MINIMAP_MARKER_SCALE)
	_style_minimap_marker(minimap_player_glow, MINIMAP_MARKER_SCALE)


func _style_minimap_marker(marker: ColorRect, scale_factor: float) -> void:
	if marker == null:
		return
	var old_size := marker.size
	var new_size := Vector2(
		maxf(4.0, old_size.x * scale_factor),
		maxf(4.0, old_size.y * scale_factor)
	)
	marker.position += (old_size - new_size) * 0.5
	marker.size = new_size
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = MINIMAP_CIRCLE_SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = shader
	marker.material = material


func _build_attract_label() -> void:
	if energy_bar_frame == null:
		return
	_attract_lbl = Label.new()
	_attract_lbl.add_theme_font_size_override("font_size", 9)
	_attract_lbl.add_theme_color_override("font_color", Color(0.55, 0.92, 1.0, 0.78))
	_attract_lbl.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	_attract_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	_attract_lbl.anchor_top    = 1.0
	_attract_lbl.anchor_bottom = 1.0
	_attract_lbl.anchor_left   = 0.0
	_attract_lbl.anchor_right  = 1.0
	_attract_lbl.offset_top    = 2.0
	_attract_lbl.offset_bottom = 16.0
	energy_bar_frame.add_child(_attract_lbl)


func _process(delta: float) -> void:
	_energy_fx_time += delta
	if _player == null:
		_player = get_node_or_null(player_path)
	_position_minimap_frame()
	_update_text()


func _update_text() -> void:
	_update_energy_text()
	_update_iron_text()
	_update_gold_text()
	_update_crystal_text()
	_update_uranium_text()
	_update_titanium_text()
	_update_run_state_text()
	_update_player_speed_text()
	_update_player_position_text()
	_update_engine_player_position_text()
	_update_radius_labels()
	_update_storm_minimap()
	_update_player_minimap()
	_update_portal_minimap()
	_update_titanium_minimap()
	_update_sulfur_minimap()
	_update_wind_minimap()


func _update_energy_text() -> void:
	if energy_bar_frame == null or energy_bar_fill == null or energy_bar_text == null:
		return
	if _player == null:
		energy_bar_fill.size.x = 0.0
		energy_bar_text.text = "--%"
		if _attract_lbl != null:
			_attract_lbl.text = "--"
		return

	var current_energy := float(_player.get("energy"))
	var max_energy := maxf(1.0, float(_player.get("max_energy")))
	var ratio := clampf(current_energy / max_energy, 0.0, 1.0)
	var pct := clampi(int(round(ratio * 100.0)), 0, 100)
	energy_bar_fill.size.x = energy_bar_frame.size.x * ratio
	energy_bar_text.text = "%d%%" % pct
	if _attract_lbl != null:
		_attract_lbl.text = "cekim r: %d" % int(EnergyOrb.DEFAULT_ATTRACT_RADIUS)
	_update_energy_bar_style(ratio)


func _update_energy_bar_style(ratio: float) -> void:
	if energy_bar_frame == null or energy_bar_fill == null or energy_bar_text == null:
		return

	var high_pulse := 0.5 + (0.5 * sin(_energy_fx_time * 11.0))
	var low_blink := 0.5 + (0.5 * sin(_energy_fx_time * 6.5))
	var storm_active := false
	var storm_glow_boost := 0.0
	if _player != null:
		var storm_active_variant: Variant = _player.get("_storm_active")
		if storm_active_variant != null:
			storm_active = bool(storm_active_variant)
		var storm_glow_variant: Variant = _player.get("_storm_glow_boost")
		if storm_glow_variant != null:
			storm_glow_boost = float(storm_glow_variant)

	if storm_active:
		var storm_pulse := 0.5 + (0.5 * sin(_energy_fx_time * 13.0))
		energy_bar_frame.color = Color(0.02, 0.12, 0.06, 0.9)
		energy_bar_fill.color = Color(
			0.0,
			minf(1.0, 0.88 + 0.12 * storm_pulse),
			minf(1.0, 0.55 + 0.1 * storm_pulse),
			0.88 + 0.1 * storm_pulse
		)
		energy_bar_text.modulate = Color(0.72, 1.0, 0.82, 1.0)
		return

	if ratio >= 0.66:
		var electric_strength := (ratio - 0.66) / 0.34
		var glow_mix := lerpf(0.15, 0.42, electric_strength) * high_pulse
		energy_bar_frame.color = Color(0.16, 0.12, 0.04, 0.88)
		energy_bar_fill.color = Color(
			minf(1.0, 0.95 + (0.18 * glow_mix)),
			minf(1.0, 0.8 + (0.2 * glow_mix)),
			minf(1.0, 0.12 + (0.18 * glow_mix)),
			0.92
		)
		energy_bar_text.modulate = Color(1.0, 0.97, 0.8 + (0.2 * glow_mix), 1.0)
		return

	if ratio <= 0.33:
		var danger_mix := 1.0 - (ratio / 0.33)
		var alpha := lerpf(0.95, 0.38, low_blink * danger_mix)
		energy_bar_frame.color = Color(0.12, 0.09, 0.04, 0.82)
		energy_bar_fill.color = Color(0.9, 0.7, 0.08, alpha)
		energy_bar_text.modulate = Color(1.0, 0.93, 0.72, lerpf(1.0, 0.55, low_blink * danger_mix))
		return

	energy_bar_frame.color = Color(0.14, 0.1, 0.04, 0.84)
	energy_bar_fill.color = Color(0.96, 0.8, 0.12, 0.9)
	energy_bar_text.modulate = Color(1.0, 0.96, 0.82, 1.0)


func _update_iron_text() -> void:
	if iron_label == null:
		return
	if _player == null:
		iron_label.text = "DEMIR: --"
		return
	iron_label.text = "DEMIR: %d" % int(_player.get("iron"))


func _update_gold_text() -> void:
	if gold_label == null:
		return
	if _player == null:
		gold_label.text = "ALTIN: --"
		return
	gold_label.text = "ALTIN: %d" % int(_player.get("gold"))


func _update_crystal_text() -> void:
	if crystal_label == null:
		return
	if _player == null:
		crystal_label.text = "ELMAS: --"
		return
	crystal_label.text = "ELMAS: %d" % int(_player.get("crystal"))


func _update_uranium_text() -> void:
	if uranium_label == null:
		return
	if _player == null:
		uranium_label.text = "URANYUM: --"
		return
	uranium_label.text = "URANYUM: %d" % int(_player.get("uranium"))


func _update_titanium_text() -> void:
	if titanium_label == null:
		return
	if _player == null:
		titanium_label.text = "TITANYUM: --"
		return
	titanium_label.text = "TITANYUM: %d" % int(_player.get("titanium"))


func _update_run_state_text() -> void:
	var run_state := get_node_or_null("/root/RunState")
	if run_state == null:
		_set_fallback_debug_text()
		return

	if multiplier_label != null:
		multiplier_label.text = "MULTIPLIER: x%.2f" % run_state.multiplier
	if time_label != null:
		time_label.text = "TIME: %s" % _format_time(run_state.run_time)
	if zone_label != null:
		var grid: Vector2i = run_state.current_zone_grid
		zone_label.text = "ZONE: %d (%d,%d) / %d" % [
			run_state.current_zone_id,
			grid.x,
			grid.y,
			run_state.total_zones
		]


func _set_fallback_debug_text() -> void:
	if multiplier_label != null:
		multiplier_label.text = "MULTIPLIER: --"
	if time_label != null:
		time_label.text = "TIME: --:--"
	if zone_label != null:
		zone_label.text = "ZONE: --"


func _update_player_speed_text() -> void:
	if speed_label == null:
		return
	if _player == null:
		speed_label.text = "SPEED: --"
		return

	var current_speed := 0.0
	if _player.has_method("get_current_speed"):
		current_speed = float(_player.call("get_current_speed"))
	else:
		current_speed = float(_player.get("velocity").length())
	speed_label.text = "SPEED: %d" % int(round(current_speed))


func _update_player_position_text() -> void:
	if player_konumu_label == null:
		return
	if _player == null or not (_player is Node2D):
		player_konumu_label.text = "PLAYER KONUMU: --"
		return
	var pos: Vector2 = (_player as Node2D).global_position
	player_konumu_label.text = "PLAYER KONUMU: (%.1f, %.1f)" % [pos.x, pos.y]


func _update_engine_player_position_text() -> void:
	if player_label == null:
		return
	if _player == null:
		player_label.text = "PLAYER: --"
		return

	var pos: Vector2 = Vector2.ZERO
	if _player is Node2D:
		pos = (_player as Node2D).global_position
	player_label.text = "PLAYER: (%.1f, %.1f)" % [pos.x, pos.y]


func _update_radius_labels() -> void:
	if _player == null:
		if attraction_radius_label != null:
			attraction_radius_label.text = "CEKIM R: --"
		if energy_field_radius_label != null:
			energy_field_radius_label.text = "YER CEKIMI R: --"
		if damage_radius_label != null:
			damage_radius_label.text = "HASAR R: --"
		return

	# 1. Çekim alanı r (AttractionField → MiningField.radius)
	if attraction_radius_label != null:
		var af := (_player as Node).get_node_or_null("AttractionField")
		var af_r := "--"
		if af != null:
			var r_var: Variant = af.get("radius")
			if r_var != null:
				af_r = "%d" % int(round(float(r_var)))
		attraction_radius_label.text = "CEKIM R: %s" % af_r

	# 2. Enerji orb çekim r (energy field)
	if energy_field_radius_label != null:
		var ef_r := "--"
		if _player.has_method("get_energy_field_radius"):
			ef_r = "%d" % int(round(float(_player.call("get_energy_field_radius"))))
		energy_field_radius_label.text = "ENERJI R: %s" % ef_r

	# 3. Hasar alanı r
	if damage_radius_label != null:
		var da_r := "--"
		if _player.has_method("get_damage_aura_radius"):
			da_r = "%d" % int(round(float(_player.call("get_damage_aura_radius"))))
		damage_radius_label.text = "HASAR R: %s" % da_r


func _format_time(seconds: float) -> String:
	var total_seconds := maxi(0, int(floor(seconds)))
	var mins := total_seconds / 60
	var secs := total_seconds % 60
	return "%02d:%02d" % [mins, secs]


func _update_storm_minimap() -> void:
	if minimap_frame == null or minimap_storm_marker == null:
		return

	var world: Node = get_parent()
	if world == null:
		minimap_storm_marker.visible = false
		return
	var zone_manager: Node = world.get_node_or_null("ZoneManager")
	var black_hole: Node2D = world.get_node_or_null("BlackHole") as Node2D
	if zone_manager == null or black_hole == null:
		minimap_storm_marker.visible = false
		return

	var world_size_variant: Variant = zone_manager.get("world_size")
	if not (world_size_variant is Vector2):
		minimap_storm_marker.visible = false
		return
	var world_size: Vector2 = world_size_variant
	if world_size.x <= 0.0 or world_size.y <= 0.0:
		minimap_storm_marker.visible = false
		return

	var bh_pos: Vector2 = black_hole.global_position
	var marker_area: Vector2 = minimap_frame.size - minimap_storm_marker.size
	var normalized: Vector2 = Vector2(
		clampf(bh_pos.x / world_size.x, 0.0, 1.0),
		clampf(bh_pos.y / world_size.y, 0.0, 1.0)
	)
	minimap_storm_marker.position = Vector2(
		marker_area.x * normalized.x,
		marker_area.y * normalized.y
	)
	# Seviyeye göre parlaklık değişsin
	var lvl := 1
	if black_hole.has_method("get_level"):
		lvl = int(black_hole.call("get_level"))
	var pulse := 0.7 + 0.3 * sin(Time.get_ticks_msec() / 500.0)
	const BH_MAX_LEVEL := 30   ## BlackHoleController.MAX_LEVEL ile senkron tutulmalı
	var intensity := clampf(0.5 + float(lvl - 1) / float(BH_MAX_LEVEL - 1) * 0.5, 0.5, 1.0)
	minimap_storm_marker.modulate = Color(0.7 * intensity, 0.1, 1.0 * intensity, pulse)
	minimap_storm_marker.modulate = Color(minimap_storm_marker.modulate.r, minimap_storm_marker.modulate.g, minimap_storm_marker.modulate.b, 0.95)
	minimap_storm_marker.visible = true


func _update_player_minimap() -> void:
	if minimap_frame == null or minimap_player_marker == null or minimap_player_glow == null:
		return
	if _player == null or not (_player is Node2D):
		minimap_player_marker.visible = false
		minimap_player_glow.visible = false
		return

	var world: Node = get_parent()
	if world == null:
		minimap_player_marker.visible = false
		minimap_player_glow.visible = false
		return
	var zone_manager: Node = world.get_node_or_null("ZoneManager")
	if zone_manager == null:
		minimap_player_marker.visible = false
		minimap_player_glow.visible = false
		return

	var world_size_variant: Variant = zone_manager.get("world_size")
	if not (world_size_variant is Vector2):
		minimap_player_marker.visible = false
		minimap_player_glow.visible = false
		return
	var world_size: Vector2 = world_size_variant
	if world_size.x <= 0.0 or world_size.y <= 0.0:
		minimap_player_marker.visible = false
		minimap_player_glow.visible = false
		return

	var player_pos: Vector2 = (_player as Node2D).global_position
	var marker_area: Vector2 = minimap_frame.size - minimap_player_marker.size
	var normalized: Vector2 = Vector2(
		clampf(player_pos.x / world_size.x, 0.0, 1.0),
		clampf(player_pos.y / world_size.y, 0.0, 1.0)
	)
	var marker_position := Vector2(
		marker_area.x * normalized.x,
		marker_area.y * normalized.y
	)
	minimap_player_marker.position = marker_position
	minimap_player_glow.position = marker_position - ((minimap_player_glow.size - minimap_player_marker.size) * 0.5)
	minimap_player_marker.visible = true
	minimap_player_glow.visible = true
	var pulse := 0.65 + (0.35 * sin(_energy_fx_time * 6.0))
	minimap_player_glow.modulate = Color(0.5, 0.92, 1.0, pulse)


func _update_portal_minimap() -> void:
	if minimap_frame == null or minimap_portal_marker == null:
		return

	var tree := get_tree()
	if tree == null:
		minimap_portal_marker.visible = false
		return
	var portal_node := tree.get_first_node_in_group("portal") as Node2D
	if portal_node == null:
		minimap_portal_marker.visible = false
		return

	var world: Node = get_parent()
	if world == null:
		minimap_portal_marker.visible = false
		return
	var zone_manager: Node = world.get_node_or_null("ZoneManager")
	if zone_manager == null:
		minimap_portal_marker.visible = false
		return

	var world_size_variant: Variant = zone_manager.get("world_size")
	if not (world_size_variant is Vector2):
		minimap_portal_marker.visible = false
		return
	var world_size: Vector2 = world_size_variant
	if world_size.x <= 0.0 or world_size.y <= 0.0:
		minimap_portal_marker.visible = false
		return

	var portal_pos: Vector2 = portal_node.global_position
	var marker_area: Vector2 = minimap_frame.size - minimap_portal_marker.size
	var normalized: Vector2 = Vector2(
		clampf(portal_pos.x / world_size.x, 0.0, 1.0),
		clampf(portal_pos.y / world_size.y, 0.0, 1.0)
	)
	minimap_portal_marker.position = Vector2(
		marker_area.x * normalized.x,
		marker_area.y * normalized.y
	)
	var portal_pulse := 0.55 + (0.45 * sin(_energy_fx_time * 4.0))
	minimap_portal_marker.modulate = Color(0.55, 0.92, 1.0, portal_pulse)
	minimap_portal_marker.visible = true


func _update_titanium_minimap() -> void:
	if minimap_frame == null:
		return

	var tree := get_tree()
	if tree == null:
		_hide_titanium_minimap_markers()
		return
	var titanium_nodes: Array = tree.get_nodes_in_group("asteroid_titanium")
	if titanium_nodes.is_empty():
		_hide_titanium_minimap_markers()
		return

	var world: Node = get_parent()
	if world == null:
		_hide_titanium_minimap_markers()
		return
	var zone_manager: Node = world.get_node_or_null("ZoneManager")
	if zone_manager == null:
		_hide_titanium_minimap_markers()
		return

	var world_size_variant: Variant = zone_manager.get("world_size")
	if not (world_size_variant is Vector2):
		_hide_titanium_minimap_markers()
		return
	var world_size: Vector2 = world_size_variant
	if world_size.x <= 0.0 or world_size.y <= 0.0:
		_hide_titanium_minimap_markers()
		return

	_ensure_titanium_minimap_markers(titanium_nodes.size())
	var marker_area := minimap_frame.size - Vector2(8.0, 8.0)
	for i in range(_minimap_titanium_markers.size()):
		var marker := _minimap_titanium_markers[i]
		if i >= titanium_nodes.size():
			marker.visible = false
			continue
		var titanium_node := titanium_nodes[i] as Node2D
		if titanium_node == null:
			marker.visible = false
			continue
		var titanium_pos: Vector2 = titanium_node.global_position
		var normalized := Vector2(
			clampf(titanium_pos.x / world_size.x, 0.0, 1.0),
			clampf(titanium_pos.y / world_size.y, 0.0, 1.0)
		)
		marker.position = Vector2(
			marker_area.x * normalized.x,
			marker_area.y * normalized.y
		)
		var pulse := 0.72 + (0.28 * sin((_energy_fx_time * 4.5) + (float(i) * 0.9)))
		marker.modulate = Color(0.78, 0.92, 1.0, pulse)
		marker.visible = true


func _ensure_titanium_minimap_markers(count: int) -> void:
	while _minimap_titanium_markers.size() < count:
		var marker := ColorRect.new()
		marker.name = "TitaniumMarker%d" % _minimap_titanium_markers.size()
		marker.size = Vector2(8.0, 8.0)
		marker.color = Color(0.62, 0.86, 1.0, 0.96)
		marker.visible = false
		minimap_frame.add_child(marker)
		_style_minimap_marker(marker, MINIMAP_MARKER_SCALE)
		_minimap_titanium_markers.append(marker)


func _hide_titanium_minimap_markers() -> void:
	for marker in _minimap_titanium_markers:
		marker.visible = false


func _update_sulfur_minimap() -> void:
	if minimap_frame == null:
		return

	var tree := get_tree()
	if tree == null:
		_hide_sulfur_minimap_markers()
		return
	var sulfur_nodes: Array = tree.get_nodes_in_group("asteroid_sulfur")
	if sulfur_nodes.is_empty():
		_hide_sulfur_minimap_markers()
		return

	var world: Node = get_parent()
	if world == null:
		_hide_sulfur_minimap_markers()
		return
	var zone_manager: Node = world.get_node_or_null("ZoneManager")
	if zone_manager == null:
		_hide_sulfur_minimap_markers()
		return

	var world_size_variant: Variant = zone_manager.get("world_size")
	if not (world_size_variant is Vector2):
		_hide_sulfur_minimap_markers()
		return
	var world_size: Vector2 = world_size_variant
	if world_size.x <= 0.0 or world_size.y <= 0.0:
		_hide_sulfur_minimap_markers()
		return

	_ensure_sulfur_minimap_markers(sulfur_nodes.size())
	var marker_area := minimap_frame.size - Vector2(8.0, 8.0)
	for i in range(_minimap_sulfur_markers.size()):
		var marker := _minimap_sulfur_markers[i]
		if i >= sulfur_nodes.size():
			marker.visible = false
			continue
		var sulfur_node := sulfur_nodes[i] as Node2D
		if sulfur_node == null:
			marker.visible = false
			continue
		var sulfur_pos: Vector2 = sulfur_node.global_position
		var normalized := Vector2(
			clampf(sulfur_pos.x / world_size.x, 0.0, 1.0),
			clampf(sulfur_pos.y / world_size.y, 0.0, 1.0)
		)
		marker.position = Vector2(
			marker_area.x * normalized.x,
			marker_area.y * normalized.y
		)
		var pulse := 0.78 + (0.22 * sin((_energy_fx_time * 5.2) + (float(i) * 1.1)))
		marker.modulate = Color(1.0, 0.88, 0.24, pulse)
		marker.visible = true


func _ensure_sulfur_minimap_markers(count: int) -> void:
	while _minimap_sulfur_markers.size() < count:
		var marker := ColorRect.new()
		marker.name = "SulfurMarker%d" % _minimap_sulfur_markers.size()
		marker.size = Vector2(8.0, 8.0)
		marker.color = Color(1.0, 0.88, 0.24, 0.96)
		marker.visible = false
		minimap_frame.add_child(marker)
		_style_minimap_marker(marker, MINIMAP_MARKER_SCALE)
		_minimap_sulfur_markers.append(marker)


func _hide_sulfur_minimap_markers() -> void:
	for marker in _minimap_sulfur_markers:
		marker.visible = false


func _update_wind_minimap() -> void:
	if minimap_frame == null:
		return
	var tree := get_tree()
	if tree == null:
		_hide_wind_minimap_markers()
		return
	var wind_nodes: Array = tree.get_nodes_in_group("space_wind_zone")
	if wind_nodes.is_empty():
		_hide_wind_minimap_markers()
		return
	var world: Node = get_parent()
	if world == null:
		_hide_wind_minimap_markers()
		return
	var zone_manager: Node = world.get_node_or_null("ZoneManager")
	if zone_manager == null:
		_hide_wind_minimap_markers()
		return
	var world_size_variant: Variant = zone_manager.get("world_size")
	if not (world_size_variant is Vector2):
		_hide_wind_minimap_markers()
		return
	var world_size: Vector2 = world_size_variant
	if world_size.x <= 0.0 or world_size.y <= 0.0:
		_hide_wind_minimap_markers()
		return
	_ensure_wind_minimap_markers(wind_nodes.size())
	var marker_area := minimap_frame.size - Vector2(8.0, 8.0)
	for i in range(_minimap_wind_markers.size()):
		var marker := _minimap_wind_markers[i]
		if i >= wind_nodes.size():
			marker.visible = false
			continue
		var wind_node := wind_nodes[i] as Node2D
		if wind_node == null:
			marker.visible = false
			continue
		var wind_pos: Vector2 = wind_node.global_position
		var normalized := Vector2(
			clampf(wind_pos.x / world_size.x, 0.0, 1.0),
			clampf(wind_pos.y / world_size.y, 0.0, 1.0)
		)
		marker.position = Vector2(marker_area.x * normalized.x, marker_area.y * normalized.y)
		var pulse := 0.72 + (0.28 * sin((_energy_fx_time * 6.0) + float(i)))
		marker.modulate = Color(0.38, 1.0, 0.46, pulse)
		marker.visible = true


func _ensure_wind_minimap_markers(count: int) -> void:
	while _minimap_wind_markers.size() < count:
		var marker := ColorRect.new()
		marker.name = "WindMarker%d" % _minimap_wind_markers.size()
		marker.size = Vector2(8.0, 8.0)
		marker.color = Color(0.38, 1.0, 0.46, 0.96)
		marker.visible = false
		minimap_frame.add_child(marker)
		_style_minimap_marker(marker, MINIMAP_MARKER_SCALE)
		_minimap_wind_markers.append(marker)


func _hide_wind_minimap_markers() -> void:
	for marker in _minimap_wind_markers:
		marker.visible = false
