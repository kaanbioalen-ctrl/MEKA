extends Node
## Ocak ekranı — pause menüsünden açılır, polar grid görüntüler.
## Sol üst: kaynak paneli. Üst orta: enerji sayacı. Merkez: drop fiziği.

signal close_pressed

const PARTICLES_BG_SCRIPT = preload("res://scripts/ui/menu_particles_bg.gd")
const OCAK_GRID_SCRIPT    = preload("res://scripts/ui/ocak_grid.gd")

const ACTIVE_DROP_TARGET := 24
const ACTIVE_DROP_LIMIT  := 50

var _overlay      : ColorRect  = null
var _content      : Control    = null
var _animating    : bool       = false
var _res_labels   : Dictionary = {}   # StringName → Label
var _energy_label : Label      = null
var _ocak_energy  : int        = 0
var _drops_node   : Node2D     = null
var _player_cache : Node       = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui(get_parent())


func _process(_delta: float) -> void:
	if _content != null and _content.modulate.a > 0.01:
		_update_resource_labels()


# ── Kaynak okuma ───────────────────────────────────────────────────────────────

func _find_player() -> Node:
	if is_instance_valid(_player_cache):
		return _player_cache
	_player_cache = get_tree().get_first_node_in_group("player")
	return _player_cache


func _update_resource_labels() -> void:
	var p := _find_player()
	if p == null:
		return
	for key in _res_labels:
		var lbl: Label = _res_labels[key]
		if key in p:
			lbl.text = str(int(p.get(key)))


func _on_drop_absorbed(kind: StringName, value: int) -> void:
	_ocak_energy += value
	if _energy_label != null:
		_energy_label.text = str(_ocak_energy)


# ── Arayüz inşası ──────────────────────────────────────────────────────────────

func _build_ui(canvas: Node) -> void:
	var vp := get_viewport().get_visible_rect().size

	# 1. Solid arka plan
	var solid := ColorRect.new()
	solid.set_anchors_preset(Control.PRESET_FULL_RECT)
	solid.color = Color(0.02, 0.01, 0.05, 1.0)
	solid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(solid)

	# 2. Parçacık arka planı
	var particles := PARTICLES_BG_SCRIPT.new()
	canvas.add_child(particles)

	# 3. Atmosfer glow
	var atmo := _AtmosNode.new()
	canvas.add_child(atmo)

	# 4. İçerik grubu — grid + HUD + drop fiziği birlikte fade edilir
	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.modulate.a = 0.0
	canvas.add_child(_content)

	# Grid — viewport merkezinde, ölçek 1.15
	var grid := OCAK_GRID_SCRIPT.new()
	grid.position = vp * 0.5
	grid.scale    = Vector2(1.15, 1.15)
	_content.add_child(grid)

	# Drop fiziği node — grid merkezi ile aynı konumda
	var dn := _OcakDropsNode.new()
	dn.position  = vp * 0.5
	_drops_node  = dn
	_content.add_child(dn)

	# Overlay (karartma katmanı)
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color        = Color(0.0, 0.0, 0.03, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_overlay)

	# ── HUD kökü — tam ekran, tüm UI elemanlarını taşır ──────────────────────
	var hud_root := Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.add_child(hud_root)

	# ── Sol üst: SYSTEM ACTIVE / OCAK / kaynak paneli ─────────────────────────
	var left_margin := MarginContainer.new()
	left_margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	left_margin.add_theme_constant_override("margin_left",   32)
	left_margin.add_theme_constant_override("margin_top",    32)
	left_margin.add_theme_constant_override("margin_right",  0)
	left_margin.add_theme_constant_override("margin_bottom", 0)
	hud_root.add_child(left_margin)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 4)
	left_margin.add_child(left_vbox)

	var sys_label := Label.new()
	sys_label.text = "SYSTEM ACTIVE"
	sys_label.add_theme_font_size_override("font_size", 10)
	sys_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.40))
	left_vbox.add_child(sys_label)

	var title_label := Label.new()
	title_label.text = "OCAK"
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(0.88, 0.90, 1.00, 0.97))
	left_vbox.add_child(title_label)

	# Ayraç
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	sep.custom_minimum_size = Vector2(150, 1)
	left_vbox.add_child(sep)

	# Kaynak satırları
	var res_defs: Array = [
		[&"iron",     "DEMİR",    Color(0.72, 0.76, 0.84)],
		[&"gold",     "ALTIN",    Color(1.00, 0.84, 0.30)],
		[&"crystal",  "KRİSTAL",  Color(0.55, 0.95, 0.90)],
		[&"uranium",  "URANYUM",  Color(0.55, 0.92, 0.45)],
		[&"titanium", "TİTANYUM", Color(0.80, 0.80, 0.95)],
	]
	for rd in res_defs:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		left_vbox.add_child(row)

		var name_lbl := Label.new()
		name_lbl.text = str(rd[1]) + ":"
		name_lbl.custom_minimum_size = Vector2(82, 0)
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color",
				(rd[2] as Color).lerp(Color.WHITE, 0.25))
		row.add_child(name_lbl)

		var val_lbl := Label.new()
		val_lbl.text = "0"
		val_lbl.add_theme_font_size_override("font_size", 12)
		val_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.85))
		row.add_child(val_lbl)

		_res_labels[rd[0]] = val_lbl

	# ── Üst orta: enerji sayacı ───────────────────────────────────────────────
	var ec_strip := Control.new()
	ec_strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	ec_strip.offset_bottom = 88.0
	ec_strip.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(ec_strip)

	var ec_center := CenterContainer.new()
	ec_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	ec_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ec_strip.add_child(ec_center)

	var ec_vbox := VBoxContainer.new()
	ec_vbox.add_theme_constant_override("separation", 2)
	ec_center.add_child(ec_vbox)

	var ec_title := Label.new()
	ec_title.text                 = "ENERJİ"
	ec_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ec_title.add_theme_font_size_override("font_size", 11)
	ec_title.add_theme_color_override("font_color", Color(0.60, 0.85, 1.00, 0.55))
	ec_vbox.add_child(ec_title)

	_energy_label                         = Label.new()
	_energy_label.text                    = "0"
	_energy_label.horizontal_alignment    = HORIZONTAL_ALIGNMENT_CENTER
	_energy_label.add_theme_font_size_override("font_size", 34)
	_energy_label.add_theme_color_override("font_color", Color(0.55, 0.90, 1.00, 0.95))
	ec_vbox.add_child(_energy_label)

	# ── Sağ üst: kapat butonu ─────────────────────────────────────────────────
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
	_animating    = true
	_ocak_energy  = 0
	if _energy_label != null:
		_energy_label.text = "0"
	if _overlay != null: _overlay.color.a   = 0.0
	if _content != null: _content.modulate.a = 0.0

	_spawn_ocak_drops()

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
		tw.tween_property(_overlay, "color:a",    0.0, 0.20).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void: _animating = false)


# ── Drop spawn ─────────────────────────────────────────────────────────────────

func _spawn_ocak_drops() -> void:
	if _drops_node == null:
		return
	var dn := _drops_node as _OcakDropsNode
	if dn == null:
		return
	dn.clear_drops()
	dn.on_absorbed = _on_drop_absorbed

	var p := _find_player()
	var stock := {}
	var total_stock := 0
	var res_kinds: Array = [&"iron", &"gold", &"crystal", &"uranium", &"titanium"]
	for kind: StringName in res_kinds:
		var val := 0
		if p != null and kind in p:
			val = int(p.get(kind))
		if val > 0:
			stock[kind] = val
			total_stock += val

	if total_stock <= 0:
		stock[&"iron"] = ACTIVE_DROP_TARGET

	dn.start_stream(stock, ACTIVE_DROP_TARGET, ACTIVE_DROP_LIMIT)


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
	btn.text                  = label
	btn.custom_minimum_size   = Vector2(130, 40)
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


# ── İç sınıf: drop fiziği ─────────────────────────────────────────────────────
## Drop'lar karadeliğe doğru çekilir. BOUNCE_R'e çarptıklarında sekip
## saat yönünde 250 px/s sabit hızla yörüngeye girerler. Yavaşça merkeze
## doğru sarmal çizerek ABSORB_R'e ulaşınca absorbe edilir → enerji ++.

class _OcakDropsNode extends Node2D:
	const IRON_ORE_TEX_PATH := "res://assets/asteroids/iron/iron_ore_drop.png"
	const GOLD_ORE_TEX_PATH := "res://assets/asteroids/gold/gold_ore_drop.png"
	const SPAWN_INTERVAL := 0.08
	const GRAVITY_K   := 9000.0   # çekim kuvveti sabiti (px³/s²)
	const MAX_SPEED   := 360.0    # yaklaşma fazında maksimum hız (px/s)
	const BOUNCE_R    := 46.0     # bu yarıçapa girilince yörüngeye geç
	const ABSORB_R    := 20.0     # bu yarıçapa girilince absorbe et
	const ORBIT_SPEED := 250.0    # saat yönünde yörünge hızı (px/s)
	const SPIRAL_RATE := 10.0     # yörüngede içe doğru kayma hızı (px/s)

	## Absorbe sinyali: on_absorbed.call(kind, value)
	var on_absorbed : Callable = Callable()

	var _drops : Array = []   # Array[Dictionary]
	var _spawn_queue : Array[StringName] = []
	var _active_target: int = 24
	var _active_limit: int = 50
	var _spawn_cooldown: float = 0.0
	var _iron_ore_tex: Texture2D = null
	var _gold_ore_tex: Texture2D = null


	func add_drop(pos: Vector2, vel: Vector2, kind: StringName, value: int) -> void:
		_drops.append({
			"pos":         pos,
			"vel":         vel,
			"kind":        kind,
			"value":       value,
			"phase":       0,       # 0 = yaklaşma, 1 = yörünge
			"orbit_angle": 0.0,
			"orbit_r":     0.0,
			"spin":        randf_range(-2.6, 2.6),
			"rot":         randf() * TAU,
			"scale":       randf_range(0.90, 1.18),
		})
		queue_redraw()


	func clear_drops() -> void:
		_drops.clear()
		_spawn_queue.clear()
		_spawn_cooldown = 0.0
		queue_redraw()


	func start_stream(resource_counts: Dictionary, active_target: int, active_limit: int) -> void:
		clear_drops()
		_active_target = maxi(1, active_target)
		_active_limit = maxi(_active_target, active_limit)
		_spawn_queue = _build_spawn_queue(resource_counts)
		_ensure_textures()
		_refill_drops(0.0)


	func _build_spawn_queue(resource_counts: Dictionary) -> Array[StringName]:
		var queue: Array[StringName] = []
		var counts := {}
		var kinds: Array[StringName] = [&"iron", &"gold", &"crystal", &"uranium", &"titanium"]
		var has_any := false
		for kind in kinds:
			var amount := int(resource_counts.get(kind, 0))
			if amount > 0:
				counts[kind] = amount
				has_any = true
		if not has_any:
			counts[&"iron"] = _active_target

		var keep_going := true
		while keep_going:
			keep_going = false
			for kind in kinds:
				var left := int(counts.get(kind, 0))
				if left <= 0:
					continue
				queue.append(kind)
				counts[kind] = left - 1
				keep_going = true
		return queue


	func _ensure_textures() -> void:
		if _iron_ore_tex == null:
			_iron_ore_tex = load(IRON_ORE_TEX_PATH) as Texture2D
		if _gold_ore_tex == null:
			_gold_ore_tex = load(GOLD_ORE_TEX_PATH) as Texture2D


	func _refill_drops(delta: float) -> void:
		var desired := mini(_active_target, _active_limit)
		_spawn_cooldown -= delta
		while _drops.size() < desired and _drops.size() < _active_limit and not _spawn_queue.is_empty() and _spawn_cooldown <= 0.0:
			var kind: StringName = _spawn_queue.pop_front()
			var spawn_data: Dictionary = _make_edge_spawn()
			var spawn_pos: Vector2 = spawn_data["pos"]
			var spawn_vel: Vector2 = spawn_data["vel"]
			add_drop(spawn_pos, spawn_vel, kind, 1)
			_spawn_cooldown += SPAWN_INTERVAL


	func _make_edge_spawn() -> Dictionary:
		var half := get_viewport().get_visible_rect().size * 0.5
		var margin := 80.0
		var side := randi() % 4
		var pos := Vector2.ZERO

		match side:
			0:
				pos = Vector2(randf_range(-half.x, half.x), -half.y - margin)
			1:
				pos = Vector2(half.x + margin, randf_range(-half.y, half.y))
			2:
				pos = Vector2(randf_range(-half.x, half.x), half.y + margin)
			_:
				pos = Vector2(-half.x - margin, randf_range(-half.y, half.y))

		var inward := (-pos).normalized()
		var tangent := inward.orthogonal() * randf_range(-28.0, 28.0)
		var vel := inward * randf_range(18.0, 62.0) + tangent
		return {"pos": pos, "vel": vel}


	func _physics_process(delta: float) -> void:
		var i := _drops.size() - 1
		while i >= 0:
			var d : Dictionary = _drops[i]

			if d["phase"] == 0:
				_step_approach(d, delta)
			else:
				_step_orbit(d, delta)

			var pos : Vector2 = d["pos"]
			if pos.length() <= ABSORB_R:
				if on_absorbed.is_valid():
					on_absorbed.call(d["kind"] as StringName, d["value"] as int)
				_drops.remove_at(i)

			i -= 1

		_refill_drops(delta)

		queue_redraw()


	func _step_approach(d: Dictionary, delta: float) -> void:
		var pos : Vector2 = d["pos"]
		var vel : Vector2 = d["vel"]
		var r   := pos.length()

		if r > 0.001:
			var force := GRAVITY_K / (r * r)
			vel += (-pos.normalized()) * force * delta
			var spd := vel.length()
			if spd > MAX_SPEED:
				vel = vel * (MAX_SPEED / spd)

		d["vel"] = vel
		d["pos"] = pos + vel * delta
		d["rot"] = float(d["rot"]) + float(d["spin"]) * delta

		# BOUNCE_R'e girildi → yörüngeye geç
		var new_pos : Vector2 = d["pos"]
		if new_pos.length() < BOUNCE_R:
			d["phase"]       = 1
			d["orbit_r"]     = maxf(BOUNCE_R, new_pos.length())
			d["orbit_angle"] = atan2(new_pos.y, new_pos.x)
			d["pos"]         = Vector2(cos(d["orbit_angle"]), sin(d["orbit_angle"])) \
								* d["orbit_r"]


	func _step_orbit(d: Dictionary, delta: float) -> void:
		var r     : float = d["orbit_r"]
		var angle : float = d["orbit_angle"]

		# Saat yönünde dön (açısal hız = hız / yarıçap)
		angle -= (ORBIT_SPEED / maxf(r, 1.0)) * delta

		# Yavaşça içe doğru sarmal
		r -= SPIRAL_RATE * delta
		r  = maxf(ABSORB_R - 1.0, r)

		d["orbit_angle"] = angle
		d["orbit_r"]     = r
		d["pos"]         = Vector2(cos(angle), sin(angle)) * r
		d["rot"]         = float(d["rot"]) + float(d["spin"]) * delta


	func _draw_textured_drop(pos: Vector2, rot: float, scale_factor: float, tex: Texture2D, tint: Color, size: float) -> bool:
		if tex == null:
			return false
		draw_set_transform(pos, rot, Vector2.ONE * scale_factor)
		draw_texture_rect(tex, Rect2(Vector2(-size, -size), Vector2(size * 2.0, size * 2.0)), false, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return true


	func _draw_diamond(pos: Vector2, radius: float, fill: Color, outline: Color) -> void:
		var points := PackedVector2Array([
			pos + Vector2(0.0, -radius),
			pos + Vector2(radius * 0.78, 0.0),
			pos + Vector2(0.0, radius),
			pos + Vector2(-radius * 0.78, 0.0),
		])
		draw_colored_polygon(points, fill)
		draw_polyline(points + PackedVector2Array([points[0]]), outline, 1.2, true)


	func _draw_hex(pos: Vector2, radius: float, fill: Color, core: Color) -> void:
		var points := PackedVector2Array()
		for i in range(6):
			var angle := (-PI * 0.5) + (TAU * float(i) / 6.0)
			points.append(pos + Vector2.RIGHT.rotated(angle) * radius)
		draw_colored_polygon(points, fill)
		var inner := PackedVector2Array()
		for point in points:
			inner.append(pos + (point - pos) * 0.56)
		draw_colored_polygon(inner, core)
		draw_polyline(points + PackedVector2Array([points[0]]), Color(1.0, 1.0, 1.0, 0.30), 1.0, true)


	func _draw() -> void:
		for d in _drops:
			var pos  : Vector2    = d["pos"]
			var kind : StringName = d["kind"]
			var rot  : float = float(d["rot"])
			var scale_factor : float = float(d["scale"])

			var core := Color(0.72, 0.76, 0.84, 0.95)
			var glow := Color(0.45, 0.55, 0.80, 0.22)
			var draw_radius : float = 11.0 * scale_factor

			match kind:
				&"gold":
					core = Color(1.00, 0.88, 0.30, 0.95)
					glow = Color(0.95, 0.72, 0.08, 0.22)
				&"crystal":
					core = Color(0.55, 0.95, 0.92, 0.95)
					glow = Color(0.25, 0.82, 0.88, 0.22)
				&"uranium":
					core = Color(0.50, 0.95, 0.40, 0.95)
					glow = Color(0.28, 0.82, 0.18, 0.22)
				&"titanium":
					core = Color(0.82, 0.82, 0.98, 0.95)
					glow = Color(0.60, 0.60, 0.92, 0.22)

			draw_circle(pos, draw_radius * 1.55, glow)

			if kind == &"iron":
				if _draw_textured_drop(pos, rot, scale_factor, _iron_ore_tex, Color(0.86, 0.88, 0.94, 0.98), 11.0):
					continue
			elif kind == &"gold":
				if _draw_textured_drop(pos, rot, scale_factor, _gold_ore_tex, Color(1.00, 0.94, 0.66, 0.98), 11.0):
					continue
			elif kind == &"crystal":
				_draw_diamond(pos, draw_radius * 0.86, core, Color(1.0, 1.0, 1.0, 0.40))
				draw_circle(pos, draw_radius * 0.24, Color(1.0, 1.0, 1.0, 0.55))
				continue
			elif kind == &"uranium":
				_draw_diamond(pos, draw_radius * 0.92, core.darkened(0.18), Color(0.85, 1.0, 0.78, 0.42))
				draw_circle(pos, draw_radius * 0.34, Color(0.90, 1.0, 0.82, 0.60))
				continue
			elif kind == &"titanium":
				_draw_hex(pos, draw_radius * 0.88, core.darkened(0.06), Color(0.94, 0.97, 1.0, 0.90))
				continue

			draw_circle(pos, draw_radius * 0.50, core)


# ── İç sınıf: atmosfer glow ───────────────────────────────────────────────────

class _AtmosNode extends Node2D:
	func _draw() -> void:
		var vp := get_viewport().get_visible_rect().size
		var cx := vp.x * 0.5
		var cy := vp.y * 0.5

		draw_circle(Vector2(cx, cy),          vp.length() * 0.40, Color(0.118, 0.106, 0.294, 0.08))
		draw_circle(Vector2(cx * 0.4, cy * 1.6), vp.length() * 0.25, Color(0.192, 0.180, 0.506, 0.06))
		draw_circle(Vector2(cx * 1.6, cy * 0.4), vp.length() * 0.25, Color(0.298, 0.114, 0.584, 0.06))
