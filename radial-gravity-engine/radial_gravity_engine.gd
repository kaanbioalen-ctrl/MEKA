extends Node2D
class_name RadialGravityEngine

## Ocak ekranı radyal yerçekimi motoru.
##
## Görevler:
##   1. Karadelik merkezi tüm drop'ları kendine çeker (r² yasası).
##   2. Grid sektörleri fiziksel duvar olarak davranır — iç/dış halka + açısal bölücüler.
##   3. Her sektörde en fazla 1 drop bulunabilir; doluysa yeni gelen geri sektirilir.
##   4. Drop hücreye girince çevresindeki hücreleri iter (hafif dalga).
##   5. Pattern ID'si verilen hücre grubu eşleşince tüm grup aynı anda açılır.
##   6. Karadelik yuttuğu dropu sinyal ile bildirir (kaynak eklenebilir).

# ── Grid sabitleri (ocak_grid.gd ile senkron) ─────────────────────────────────
const CENTER_R:   float = 20.0
const R_START:    float = 80.0
const DR:         float = 90.0
const LAYERS:     int   = 3
const SEG_COUNTS: Array[int] = [4, 8, 16]

# ── Fizik sabitleri ───────────────────────────────────────────────────────────
const BLACK_HOLE_STRENGTH: float = 22000.0  # G*M (kuvvet = BH_STR / r²)
const MAX_SPEED:           float = 460.0    # drop maksimum hızı
const WALL_BOUNCE:         float = 0.38     # radyal duvar sekme katsayısı
const WALL_FRICTION:       float = 0.68     # teğet yön sürtünme katsayısı
const CELL_SNAP_SPEED:     float = 5.0      # hücre içinde merkeze kayma hızı (px/s)
const REPULSE_RADIUS:      float = 50.0     # girişte çevreye itme menzili (px)
const REPULSE_IMPULSE:     float = 3200.0   # tek seferlik itme kuvveti
const BH_ABSORB_RADIUS:    float = CENTER_R + 4.0  # bu mesafeye giren drop yutulur
const SETTLE_SPEED_SQ:     float = 36.0     # bu hız²'nin altında "yerleşti" sayılır

# ── Sinyaller ────────────────────────────────────────────────────────────────
## Karadelik bir drop yuttu.
signal drop_absorbed(resource_kind: StringName, value: int)
## Bir drop hücreye oturdu.
signal drop_settled(layer: int, segment: int, resource_kind: StringName)
## Hücre mühürlendi (doldu).
signal cell_sealed(layer: int, segment: int)
## Hücre açıldı (boşaldı veya pattern açtı).
signal cell_unsealed(layer: int, segment: int)
## Pattern eşleşti — pattern_id ve eşleşen hücre listesi.
signal pattern_matched(pattern_id: StringName, cells: Array)

# ── Drop veri yapısı ──────────────────────────────────────────────────────────
class DropState:
	var pos:           Vector2    = Vector2.ZERO
	var vel:           Vector2    = Vector2.ZERO
	var resource_kind: StringName = &"iron"
	var value:         int        = 1
	var node:          Node2D     = null   # sahnedeki görsel node (opsiyonel)
	var cell_layer:    int        = -1     # şu an hangi hücrede — -1 = serbest
	var cell_segment:  int        = -1
	var settled:       bool       = false  # hücreye tam oturdu mu
	var absorb_timer:  float      = 0.0   # karadeliğe değince kısa gecikme

# ── Hücre veri yapısı ─────────────────────────────────────────────────────────
class CellState:
	var layer:      int        = 0
	var segment:    int        = 0
	var center:     Vector2    = Vector2.ZERO  # hücre merkezi (dünya uzayı)
	var r_inner:    float      = 0.0
	var r_outer:    float      = 0.0
	var a_start:    float      = 0.0
	var a_end:      float      = 0.0
	var sealed:     bool       = false     # dolu mu
	var occupant:   DropState  = null      # içindeki drop
	var pattern_id: StringName = &""       # hangi pattern grubuna ait

# ── Runtime ───────────────────────────────────────────────────────────────────
var _drops: Array[DropState]  = []
var _cells: Array[CellState]  = []        # toplam 4+8+16 = 28 hücre
var _patterns: Dictionary     = {}        # pattern_id → Array[CellState]

# Görsel debug (false = production)
@export var debug_draw: bool = false

# Gravity ölçeği — çalışma zamanında ayarlanabilir
@export_range(0.1, 5.0, 0.05) var gravity_scale: float = 1.0


func _ready() -> void:
	_build_cells()


# ── Hücre inşası ──────────────────────────────────────────────────────────────

func _build_cells() -> void:
	_cells.clear()
	for l in LAYERS:
		var r_in  := R_START + l * DR
		var r_out := r_in + DR
		var count := SEG_COUNTS[l]
		var step  := TAU / float(count)
		for s in count:
			var a0 := float(s) * step - PI * 0.5
			var a1 := a0 + step
			var a_mid := (a0 + a1) * 0.5
			var r_mid := (r_in + r_out) * 0.5
			var c          := CellState.new()
			c.layer        = l
			c.segment      = s
			c.r_inner      = r_in
			c.r_outer      = r_out
			c.a_start      = a0
			c.a_end        = a1
			c.center       = Vector2(cos(a_mid), sin(a_mid)) * r_mid
			_cells.append(c)


# ── Public API ────────────────────────────────────────────────────────────────

## Drop ekle. node opsiyoneldir (görsel senkronizasyon için).
func add_drop(pos: Vector2, vel: Vector2,
		resource_kind: StringName = &"iron", value: int = 1,
		node: Node2D = null) -> DropState:
	var d          := DropState.new()
	d.pos          = pos
	d.vel          = vel
	d.resource_kind = resource_kind
	d.value        = value
	d.node         = node
	_drops.append(d)
	return d


## Drop kaldır (manuel temizlik).
func remove_drop(d: DropState) -> void:
	_eject_from_cell(d)
	_drops.erase(d)
	if is_instance_valid(d.node):
		d.node.queue_free()


## Pattern tanımla: pattern_id → hücre indeksleri listesi [(layer,seg), ...]
## Tüm hücreler dolduğunda pattern sinyal verir ve tüm hücreleri açar.
func register_pattern(pattern_id: StringName, cell_coords: Array) -> void:
	var cell_list: Array[CellState] = []
	for coord in cell_coords:
		var c := _get_cell(coord[0], coord[1])
		if c != null:
			c.pattern_id = pattern_id
			cell_list.append(c)
	_patterns[pattern_id] = cell_list


## Belirli bir hücreyi zorla boşalt.
func unseal_cell(layer: int, segment: int) -> void:
	var c := _get_cell(layer, segment)
	if c == null or not c.sealed:
		return
	if c.occupant != null:
		remove_drop(c.occupant)
		c.occupant = null
	c.sealed = false
	cell_unsealed.emit(layer, segment)


# ── Fizik güncelleme ─────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	for d in _drops.duplicate():   # duplicate: iterate güvenli (içeriden erase olabilir)
		if not _drops.has(d):
			continue
		_step_drop(d, delta)
	if debug_draw:
		queue_redraw()


func _step_drop(d: DropState, delta: float) -> void:
	# ── 0. Karadelik yutma gecikmesi ────────────────────────────────────────────
	if d.absorb_timer > 0.0:
		d.absorb_timer -= delta
		if d.absorb_timer <= 0.0:
			drop_absorbed.emit(d.resource_kind, d.value)
			_drops.erase(d)
			if is_instance_valid(d.node):
				d.node.queue_free()
		return

	# ── 1. Yerleşmiş drop — sadece görsel senkronizasyon ────────────────────────
	if d.settled:
		_sync_node(d)
		return

	# ── 2. Yerçekimi ────────────────────────────────────────────────────────────
	var r_sq := d.pos.length_squared()
	if r_sq > 0.01:
		var r    := sqrt(r_sq)
		var grav := -(d.pos / r) * (BLACK_HOLE_STRENGTH * gravity_scale / r_sq)
		d.vel += grav * delta

	# Hız sınırı
	var spd_sq := d.vel.length_squared()
	if spd_sq > MAX_SPEED * MAX_SPEED:
		d.vel = d.vel.normalized() * MAX_SPEED

	# ── 3. Hücre duvarı çarpışmaları ────────────────────────────────────────────
	_resolve_walls(d, delta)

	# ── 4. Konum güncelle ───────────────────────────────────────────────────────
	d.pos += d.vel * delta

	# ── 5. Karadelik yutma ──────────────────────────────────────────────────────
	if d.pos.length() <= BH_ABSORB_RADIUS:
		d.absorb_timer = 0.08   # kısa gecikme — görsel flash için
		d.vel          = Vector2.ZERO
		_eject_from_cell(d)
		_sync_node(d)
		return

	# ── 6. Hücre girişi / yerleşme ──────────────────────────────────────────────
	_check_cell_entry(d)

	# ── 7. Görsel senkronizasyon ────────────────────────────────────────────────
	_sync_node(d)


# ── Duvar çözümü ──────────────────────────────────────────────────────────────

func _resolve_walls(d: DropState, _delta: float) -> void:
	var r     := d.pos.length()
	var radial: Vector2 = d.pos.normalized() if r > 0.001 else Vector2.RIGHT
	var tang:  Vector2  = Vector2(-radial.y, radial.x)

	var v_rad  := d.vel.dot(radial)
	var v_tang := d.vel.dot(tang)

	# ── İç halka: CENTER_R ────────────────────────────────────────────────────
	if r < CENTER_R and v_rad < 0.0:
		d.vel -= radial * v_rad * (1.0 + WALL_BOUNCE)
		d.vel  = d.vel.normalized() * d.vel.length() * WALL_FRICTION if d.vel.length() > 0.1 else d.vel

	# ── Halka sınırları ───────────────────────────────────────────────────────
	for l in LAYERS + 1:
		var ring_r := R_START + l * DR
		var inside := r < ring_r
		# Drop dışarıdan içe girmeye çalışıyor (v_rad < 0 = merkeze doğru)
		# Sadece en dış halkanın dışına çıkışı engelle
		if l == LAYERS and not inside and v_rad > 0.0:
			# Dışarı çıkmayı engelle — geri yansıt
			d.pos  = radial * (ring_r - 0.5)
			d.vel -= radial * v_rad * (1.0 + WALL_BOUNCE)
			d.vel  = tang * v_tang * WALL_FRICTION + radial * d.vel.dot(radial)

	# ── Açısal duvarlar: sektör sınırları ─────────────────────────────────────
	var angle := atan2(d.pos.y, d.pos.x)
	var cell  := _cell_at_pos(d.pos)
	if cell == null:
		return
	var count     := SEG_COUNTS[cell.layer]
	var ang_step  := TAU / float(count)

	# Sektör sınırlarına mesafe
	var da_start := _angle_diff(angle, cell.a_start)
	var da_end   := _angle_diff(angle, cell.a_end)
	var border   := 1.8   # piksel toleransı

	if absf(da_start) < deg_to_rad(border):
		# Sol açısal duvara yakın — teğet bileşeni sınırın içine doğruysa yansıt
		var wall_n: Vector2 = Vector2(cos(cell.a_start + PI * 0.5),
		                               sin(cell.a_start + PI * 0.5))
		var vn := d.vel.dot(wall_n)
		if vn < 0.0:
			d.vel -= wall_n * vn * (1.0 + WALL_BOUNCE)
	elif absf(da_end) < deg_to_rad(border):
		var wall_n: Vector2 = Vector2(cos(cell.a_end - PI * 0.5),
		                               sin(cell.a_end - PI * 0.5))
		var vn := d.vel.dot(wall_n)
		if vn < 0.0:
			d.vel -= wall_n * vn * (1.0 + WALL_BOUNCE)

	# ── Dolu hücre duvarı: sektörün tüm sınırları ────────────────────────────
	if cell.sealed and cell.occupant != d:
		# Drop dolu hücreye girmeye çalışıyor — hücre merkezinden uzaklaştır
		var to_center := cell.center.normalized()
		if d.vel.dot(to_center) > 0.0:
			d.vel -= to_center * d.vel.dot(to_center) * (1.0 + WALL_BOUNCE)
			_apply_repulse_wave(d, cell)


# ── Hücre girişi ─────────────────────────────────────────────────────────────

func _check_cell_entry(d: DropState) -> void:
	var cell := _cell_at_pos(d.pos)
	if cell == null:
		_eject_from_cell(d)
		return

	var same := (d.cell_layer == cell.layer and d.cell_segment == cell.segment)
	if same:
		# Aynı hücredeyiz — yerleşme kontrolü
		if not d.settled and d.vel.length_squared() < SETTLE_SPEED_SQ:
			_settle_drop(d, cell)
		return

	# Farklı hücreye geçiş
	_eject_from_cell(d)

	if cell.sealed:
		# Dolu hücre — geri sektirilir (duvar çözümü halleder, burası reserve)
		return

	# Hücreye giriş
	d.cell_layer   = cell.layer
	d.cell_segment = cell.segment

	# Çevre itme dalgası
	_apply_repulse_wave(d, cell)


func _settle_drop(d: DropState, cell: CellState) -> void:
	if cell.sealed:
		return
	d.settled      = true
	d.vel          = Vector2.ZERO
	d.pos          = to_local(to_global(cell.center))   # hücre merkezine snap
	cell.sealed    = true
	cell.occupant  = d
	drop_settled.emit(cell.layer, cell.segment, d.resource_kind)
	cell_sealed.emit(cell.layer, cell.segment)
	_check_pattern(cell)


func _eject_from_cell(d: DropState) -> void:
	if d.cell_layer < 0:
		return
	var old := _get_cell(d.cell_layer, d.cell_segment)
	if old != null and old.occupant == d:
		old.occupant = null
		old.sealed   = false
		cell_unsealed.emit(old.layer, old.segment)
	d.cell_layer   = -1
	d.cell_segment = -1
	d.settled      = false


# ── İtme dalgası ─────────────────────────────────────────────────────────────

func _apply_repulse_wave(source: DropState, _cell: CellState) -> void:
	for other in _drops:
		if other == source or other.settled:
			continue
		var diff := other.pos - source.pos
		var dist := diff.length()
		if dist < 0.01 or dist > REPULSE_RADIUS:
			continue
		var t   := 1.0 - dist / REPULSE_RADIUS
		var imp := diff.normalized() * REPULSE_IMPULSE * t * t
		other.vel += imp


# ── Pattern kontrolü ─────────────────────────────────────────────────────────

func _check_pattern(filled_cell: CellState) -> void:
	var pid := filled_cell.pattern_id
	if pid == &"":
		return
	if not _patterns.has(pid):
		return
	var group: Array = _patterns[pid]
	for c in group:
		if not c.sealed:
			return
	# Tüm hücreler dolu — pattern eşleşti
	pattern_matched.emit(pid, group.duplicate())
	# Pattern hücrelerini gecikmeyle aç
	for c in group:
		_schedule_unseal(c, 0.6)


func _schedule_unseal(cell: CellState, delay: float) -> void:
	var t := get_tree().create_timer(delay)
	t.timeout.connect(func():
		if cell.occupant != null:
			remove_drop(cell.occupant)
		cell.occupant = null
		cell.sealed   = false
		cell_unsealed.emit(cell.layer, cell.segment)
	)


# ── Yardımcı sorgular ────────────────────────────────────────────────────────

func _cell_at_pos(pos: Vector2) -> CellState:
	var r     := pos.length()
	var angle := atan2(pos.y, pos.x)
	for l in LAYERS:
		var r_in  := R_START + l * DR
		var r_out := r_in + DR
		if r < r_in or r >= r_out:
			continue
		var count    := SEG_COUNTS[l]
		var ang_step := TAU / float(count)
		# Normalize angle to [0, TAU), offset -PI/2
		var a_norm := fmod(angle + PI * 0.5 + TAU, TAU)
		var seg    := int(a_norm / ang_step) % count
		return _get_cell(l, seg)
	return null


func _get_cell(layer: int, segment: int) -> CellState:
	for c in _cells:
		if c.layer == layer and c.segment == segment:
			return c
	return null


## Konuma göre hücrenin dolu olup olmadığını döner.
func is_cell_sealed(layer: int, segment: int) -> bool:
	var c := _get_cell(layer, segment)
	return c != null and c.sealed


## Tüm hücre durumlarını döner (UI için).
func get_cells() -> Array[CellState]:
	return _cells


## Aktif drop sayısı.
func drop_count() -> int:
	return _drops.size()


# ── Görsel senkronizasyon ────────────────────────────────────────────────────

func _sync_node(d: DropState) -> void:
	if not is_instance_valid(d.node):
		return
	d.node.global_position = to_global(d.pos)


# ── Debug çizim ──────────────────────────────────────────────────────────────

func _draw() -> void:
	if not debug_draw:
		return
	for c in _cells:
		var col := Color(0.0, 1.0, 0.4, 0.12) if not c.sealed else Color(1.0, 0.4, 0.0, 0.22)
		# Sektör yayı
		draw_arc(Vector2.ZERO, c.r_inner, c.a_start - PI * 0.5, c.a_end - PI * 0.5,
			8, col, 0.8, true)
		draw_arc(Vector2.ZERO, c.r_outer, c.a_start - PI * 0.5, c.a_end - PI * 0.5,
			8, col, 0.8, true)
		# Radyal çizgiler
		var p0_in  := Vector2(cos(c.a_start - PI * 0.5), sin(c.a_start - PI * 0.5)) * c.r_inner
		var p0_out := Vector2(cos(c.a_start - PI * 0.5), sin(c.a_start - PI * 0.5)) * c.r_outer
		draw_line(p0_in, p0_out, col, 0.8, true)
		# Hücre merkezi
		draw_circle(c.center, 2.0, col)

	for d in _drops:
		draw_circle(d.pos, 3.5, Color(1.0, 0.9, 0.2, 0.85))
		draw_line(d.pos, d.pos + d.vel * 0.04, Color(1.0, 1.0, 1.0, 0.5), 1.0, true)


# ── Açı yardımcısı ───────────────────────────────────────────────────────────

static func _angle_diff(a: float, b: float) -> float:
	var d := fmod(a - b + TAU, TAU)
	if d > PI:
		d -= TAU
	return d
