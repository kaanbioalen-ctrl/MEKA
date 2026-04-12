extends Control
class_name MinimapHUD

## Tam çizim tabanlı minimap — tüm harita nesnelerini _draw() ile gösterir.
## CanvasLayer (HUD) içine eklenir, dünya bilgisini ebeveyn zincirinden bulur.

const RADIUS         : float = 98.0      # minimap daire yarıçapı (piksel)
const SCREEN_MARGIN  : float = 18.0      # ekran kenarından boşluk
const GRID_COLS      : int   = 10
const GRID_ROWS      : int   = 10

# ── Renkler ────────────────────────────────────────────────────────────────────
const COL_BG          := Color(0.018, 0.022, 0.042, 0.93)
const COL_BORDER      := Color(0.30, 0.56, 1.0, 0.88)
const COL_GRID        := Color(1.0, 1.0, 1.0, 0.038)
const COL_ZONE_CUR    := Color(0.40, 0.65, 1.0, 0.060)
const COL_PLAYER      := Color(0.40, 0.94, 1.0, 1.0)
const COL_WORM        := Color(1.0, 0.22, 0.08, 1.0)
const COL_DEVASA_IRON := Color(0.76, 0.84, 1.0, 1.0)
const COL_DEVASA_GOLD := Color(1.0, 0.88, 0.26, 1.0)

# ── Durum ──────────────────────────────────────────────────────────────────────
var _pulse_t    : float   = 0.0
var _player     : Node2D  = null
var _world_size : Vector2 = Vector2(19200.0, 10800.0)
var _font       : Font    = null


# ── Yaşam döngüsü ──────────────────────────────────────────────────────────────

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
	# Sol alt köşeye sabitle
	anchor_left   = 0.0
	anchor_right  = 0.0
	anchor_top    = 1.0
	anchor_bottom = 1.0
	offset_left   = SCREEN_MARGIN
	offset_right  = SCREEN_MARGIN + RADIUS * 2.0
	offset_top    = -(SCREEN_MARGIN + RADIUS * 2.0)
	offset_bottom = -SCREEN_MARGIN
	_font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	_pulse_t += delta
	_refresh_player()
	_refresh_world_size()
	queue_redraw()


# ── Ana çizim ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	var c := Vector2(RADIUS, RADIUS)
	_draw_bg(c)
	_draw_grid(c)
	_draw_current_zone(c)
	_draw_devasa(c)
	_draw_worms(c)
	_draw_portals(c)
	_draw_player(c)
	_draw_border(c)
	_draw_compass(c)
	_draw_label(c)


# ── Arkaplan ───────────────────────────────────────────────────────────────────

func _draw_bg(c: Vector2) -> void:
	# Dış ortam ışıması
	draw_circle(c, RADIUS + 8.0, Color(0.18, 0.38, 1.0, 0.048))
	draw_circle(c, RADIUS + 4.0, Color(0.20, 0.42, 1.0, 0.032))
	# Ana koyu daire
	draw_circle(c, RADIUS, COL_BG)


# ── Zone grid ──────────────────────────────────────────────────────────────────

func _draw_grid(c: Vector2) -> void:
	# Dikey çizgiler (zone sütunları)
	for i in range(1, GRID_COLS):
		var wx   := _world_size.x * float(i) / float(GRID_COLS)
		var mx   := _wmx(wx, c)
		var dx   := mx - c.x
		var half := sqrt(maxf(0.0, RADIUS * RADIUS - dx * dx))
		if half < 1.0:
			continue
		draw_line(Vector2(mx, c.y - half), Vector2(mx, c.y + half), COL_GRID, 0.55)
	# Yatay çizgiler (zone satırları)
	for i in range(1, GRID_ROWS):
		var wy   := _world_size.y * float(i) / float(GRID_ROWS)
		var my   := _wmy(wy, c)
		var dy   := my - c.y
		var half := sqrt(maxf(0.0, RADIUS * RADIUS - dy * dy))
		if half < 1.0:
			continue
		draw_line(Vector2(c.x - half, my), Vector2(c.x + half, my), COL_GRID, 0.55)


# ── Mevcut zone vurgusu ────────────────────────────────────────────────────────

func _draw_current_zone(c: Vector2) -> void:
	var rs := get_node_or_null("/root/RunState")
	if rs == null:
		return
	var grid: Variant = rs.get("current_zone_grid")
	if not (grid is Vector2i):
		return
	var gz  := grid as Vector2i
	var zw  := _world_size.x / float(GRID_COLS)
	var zh  := _world_size.y / float(GRID_ROWS)
	var p0  := _wm(Vector2(zw * float(gz.x),        zh * float(gz.y)),        c)
	var p1  := _wm(Vector2(zw * float(gz.x + 1),    zh * float(gz.y + 1)),    c)
	draw_rect(Rect2(p0, p1 - p0), COL_ZONE_CUR, true)


# ── Devasa boss asteroidler ────────────────────────────────────────────────────

func _draw_devasa(c: Vector2) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var pulse := 0.52 + 0.48 * sin(_pulse_t * 2.6)
	for ast in tree.get_nodes_in_group("devasa"):
		if not (ast is Node2D):
			continue
		var pos := _clamp_to_edge(_wm((ast as Node2D).global_position, c), c, 4.0)
		var kind: Variant = ast.get("orb_resource_kind")
		var col  := COL_DEVASA_GOLD if kind == &"gold" else COL_DEVASA_IRON
		# Glow katmanları
		draw_circle(pos, 11.0, Color(col.r, col.g, col.b, 0.10 * pulse))
		draw_circle(pos, 6.5,  Color(col.r, col.g, col.b, 0.28 * pulse))
		draw_circle(pos, 3.2,  Color(col.r, col.g, col.b, 0.95))
		# Boss çarpı işareti
		var cr := 4.5 * pulse
		draw_line(pos + Vector2(-cr, 0), pos + Vector2(cr, 0),
			Color(col.r, col.g, col.b, 0.55 * pulse), 0.9)
		draw_line(pos + Vector2(0, -cr), pos + Vector2(0, cr),
			Color(col.r, col.g, col.b, 0.55 * pulse), 0.9)


# ── Düşmanlar (wormlar) ────────────────────────────────────────────────────────

func _draw_worms(c: Vector2) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var pulse := 0.60 + 0.40 * sin(_pulse_t * 4.2)
	for worm in tree.get_nodes_in_group("worm"):
		if not (worm is Node2D):
			continue
		var pos := _clamp_to_edge(_wm((worm as Node2D).global_position, c), c, 3.0)
		draw_circle(pos, 6.0,  Color(1.0, 0.16, 0.04, 0.18 * pulse))
		draw_circle(pos, 3.0,  COL_WORM)


# ── Portallar ──────────────────────────────────────────────────────────────────

func _draw_portals(c: Vector2) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var idx := 0
	for portal in tree.get_nodes_in_group("portal"):
		if not (portal is Node2D):
			continue
		var pos := _clamp_to_edge(_wm((portal as Node2D).global_position, c), c, 5.0)
		var col := Color(0.38, 0.78, 1.0, 1.0)
		if "portal_color" in portal:
			col = portal.portal_color as Color
		var pulse := 0.50 + 0.50 * sin(_pulse_t * 3.6 + float(idx) * 1.5)
		# Glow
		draw_circle(pos, 12.0, Color(col.r, col.g, col.b, 0.09 * pulse))
		draw_circle(pos, 7.0,  Color(col.r, col.g, col.b, 0.24 * pulse))
		# Elmas (portal ikonu)
		var d := 4.8
		draw_colored_polygon(PackedVector2Array([
			pos + Vector2(0, -d),
			pos + Vector2(d * 0.70,  0),
			pos + Vector2(0,  d),
			pos + Vector2(-d * 0.70, 0),
		]), Color(col.r, col.g, col.b, 0.88 * pulse))
		# Elmas kenar çizgisi
		draw_polyline(PackedVector2Array([
			pos + Vector2(0, -d),
			pos + Vector2(d * 0.70,  0),
			pos + Vector2(0,  d),
			pos + Vector2(-d * 0.70, 0),
			pos + Vector2(0, -d),
		]), Color(1.0, 1.0, 1.0, 0.45 * pulse), 0.7)
		idx += 1


# ── Oyuncu ─────────────────────────────────────────────────────────────────────

func _draw_player(c: Vector2) -> void:
	if not is_instance_valid(_player):
		return
	var pos   := _clamp_to_edge(_wm(_player.global_position, c), c, 7.0)
	var pulse := 0.70 + 0.30 * sin(_pulse_t * 5.2)
	var col   := COL_PLAYER
	# Dış parlama
	draw_circle(pos, 13.0, Color(col.r, col.g, col.b, 0.08 * pulse))
	draw_circle(pos, 7.5,  Color(col.r, col.g, col.b, 0.24 * pulse))
	# Yön oku (üçgen)
	var rot := _player.rotation
	var fwd := Vector2(cos(rot), sin(rot))
	var rgt := Vector2(-sin(rot), cos(rot))
	var sz  := 5.8
	var tip    := pos + fwd * sz * 1.85
	var base_l := pos - fwd * sz * 0.52 + rgt * sz * 0.92
	var base_r := pos - fwd * sz * 0.52 - rgt * sz * 0.92
	draw_colored_polygon(
		PackedVector2Array([tip, base_l, base_r]),
		Color(col.r, col.g, col.b, 0.96)
	)
	draw_polyline(
		PackedVector2Array([tip, base_l, base_r, tip]),
		Color(1.0, 1.0, 1.0, 0.52), 0.8
	)


# ── Kenarlık halkası ───────────────────────────────────────────────────────────

func _draw_border(c: Vector2) -> void:
	# Dış ışıma halkası
	draw_arc(c, RADIUS + 1.5, 0.0, TAU, 80,
		Color(COL_BORDER.r, COL_BORDER.g, COL_BORDER.b, 0.20), 3.0, true)
	# Ana kenar
	draw_arc(c, RADIUS, 0.0, TAU, 128, COL_BORDER, 1.6, true)
	# İç yumuşak hat
	draw_arc(c, RADIUS - 2.5, 0.0, TAU, 64,
		Color(COL_BORDER.r, COL_BORDER.g, COL_BORDER.b, 0.12), 1.0, true)


# ── Pusula noktaları ───────────────────────────────────────────────────────────

func _draw_compass(c: Vector2) -> void:
	var dirs := [Vector2(0, -1), Vector2(0, 1), Vector2(1, 0), Vector2(-1, 0)]
	for d in dirs:
		draw_circle(c + d * (RADIUS - 3.5), 1.8, Color(1.0, 1.0, 1.0, 0.26))
	# Kuzey nokta biraz daha belirgin
	draw_circle(c + Vector2(0, -(RADIUS - 3.5)), 2.4,
		Color(0.50, 0.80, 1.0, 0.55))


# ── MAP etiketi ────────────────────────────────────────────────────────────────

func _draw_label(c: Vector2) -> void:
	if _font == null:
		return
	draw_string(_font,
		Vector2(c.x - RADIUS, c.y + RADIUS - 8.0),
		"MAP",
		HORIZONTAL_ALIGNMENT_CENTER, RADIUS * 2.0, 10,
		Color(0.38, 0.65, 1.0, 0.55))


# ── Koordinat dönüşümleri ──────────────────────────────────────────────────────

## Dünya koordinatını minimap piksel pozisyonuna çevirir.
func _wm(world_pos: Vector2, c: Vector2) -> Vector2:
	if _world_size.x <= 0.0 or _world_size.y <= 0.0:
		return c
	var scale    := minf(RADIUS * 2.0 / _world_size.x, RADIUS * 2.0 / _world_size.y)
	var centered := (world_pos / _world_size) - Vector2(0.5, 0.5)
	return c + centered * _world_size * scale


func _wmx(wx: float, c: Vector2) -> float:
	var scale := minf(RADIUS * 2.0 / _world_size.x, RADIUS * 2.0 / _world_size.y)
	return c.x + (wx / _world_size.x - 0.5) * _world_size.x * scale


func _wmy(wy: float, c: Vector2) -> float:
	var scale := minf(RADIUS * 2.0 / _world_size.x, RADIUS * 2.0 / _world_size.y)
	return c.y + (wy / _world_size.y - 0.5) * _world_size.y * scale


## Konumu daire sınırı içinde tutar; dışarıysa kenara yapıştırır.
func _clamp_to_edge(pos: Vector2, c: Vector2, edge_margin: float) -> Vector2:
	var to := pos - c
	var max_r := RADIUS - edge_margin
	if to.length() > max_r:
		return c + to.normalized() * max_r
	return pos


# ── Node keşfi ─────────────────────────────────────────────────────────────────

func _refresh_player() -> void:
	if is_instance_valid(_player):
		return
	var node := get_tree().get_first_node_in_group("player")
	_player = node as Node2D


func _refresh_world_size() -> void:
	# Bu Control → HUD (CanvasLayer) → World (Node2D)
	var hud   := get_parent()
	var world : Node = hud.get_parent() if hud != null else null
	if world == null:
		return
	var zm := world.get_node_or_null("ZoneManager")
	if zm == null:
		return
	var ws: Variant = zm.get("world_size")
	if ws is Vector2 and (ws as Vector2).x > 0.0:
		_world_size = ws as Vector2
