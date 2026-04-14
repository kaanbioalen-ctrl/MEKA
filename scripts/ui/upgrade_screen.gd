extends CanvasLayer
## UpgradeScreen — Professional UI skill panel.
##
## GHOST-UI FIX: _purge_legacy_scene_children() removes every node inherited
## from the old .tscn (SubViewport, old Buttons, Labels, etc.) before the new
## programmatic UI is built.  Without this, those nodes render as transparent
## "ghost" overlays behind the new panel.
##
## All new children are Control-based on a CanvasLayer → immune to Camera2D zoom.
## Wheel input is detected but NOT consumed → world zoom continues normally.
## Developer mode button is preserved.

const UpgradeDefinitions = preload("res://scripts/upgrades/upgrade_definitions.gd")
const UpgradeEffects     = preload("res://scripts/upgrades/upgrade_effects.gd")

signal close_requested

# ── Orbital ring layout (atom diagram) ───────────────────────────────────────
# energy_field at center; ring-1 (r=155) has 3 skills evenly at 120° each;
# ring-2 (r=285) has 2 skills evenly at 180° each.
const SKILL_OFFSETS: Dictionary = {
	"energy_field":    Vector2(   0.0,    0.0),
	"mining":          Vector2(   0.0, -155.0),
	"damage_aura":     Vector2( 134.2,   77.5),
	"mining_speed":    Vector2(-134.2,   77.5),
	"orbit_mode":      Vector2( 285.0,    0.0),
	"drop_collection": Vector2(-285.0,    0.0),
		"energy_orb_magnet": Vector2( 297.0, -297.0),
		"crit_chance": Vector2( 297.0,  297.0),
	# Ring 3 (r=420) — placeholder slots, equally spaced at 45° offset
	"laser_duration":  Vector2(-297.0,  297.0),
	"dual_laser":      Vector2(-297.0, -297.0),
	"placeholder_d":   Vector2( 420.0,    0.0),
}

const ORBIT_FLATTEN: float = 0.56
const GALAXY_TILT_Y: float = -24.0
const GALAXY_DRIFT_SPEED: float = 0.18
const GALAXY_FOCUS_SPEED: float = 0.06
const ORBIT_LAYOUTS: Dictionary = {
	"energy_field": {
		"radius": 0.0, "base_angle": 0.0, "speed": 0.0, "flatten": 1.0, "ring_key": "core",
	},
	"mining": {
		"radius": 170.0, "base_angle": -PI * 0.52, "speed": 1.10, "flatten": ORBIT_FLATTEN, "ring_key": "inner",
	},
	"damage_aura": {
		"radius": 170.0, "base_angle": -PI * 0.08, "speed": 1.10, "flatten": ORBIT_FLATTEN, "ring_key": "inner",
	},
	"mining_speed": {
		"radius": 170.0, "base_angle": PI * 0.34, "speed": 1.10, "flatten": ORBIT_FLATTEN, "ring_key": "inner",
	},
	"drop_collection": {
		"radius": 295.0, "base_angle": PI * 0.92, "speed": 0.62, "flatten": ORBIT_FLATTEN, "ring_key": "mid",
	},
	"orbit_mode": {
		"radius": 295.0, "base_angle": -PI * 0.02, "speed": 0.62, "flatten": ORBIT_FLATTEN, "ring_key": "mid",
	},
	"energy_orb_magnet": {
		"radius": 295.0, "base_angle": -PI * 0.88, "speed": 0.62, "flatten": ORBIT_FLATTEN, "ring_key": "mid",
	},
	"crit_chance": {
		"radius": 295.0, "base_angle": PI * 0.54, "speed": 0.62, "flatten": ORBIT_FLATTEN, "ring_key": "mid",
	},
	"laser_duration": {
		"radius": 420.0, "base_angle": PI * 0.62, "speed": 0.34, "flatten": ORBIT_FLATTEN, "ring_key": "outer",
	},
	"dual_laser": {
		"radius": 420.0, "base_angle": -PI * 0.62, "speed": 0.34, "flatten": ORBIT_FLATTEN, "ring_key": "outer",
	},
	"placeholder_d": {
		"radius": 420.0, "base_angle": 0.0, "speed": 0.34, "flatten": ORBIT_FLATTEN, "ring_key": "outer",
	},
}

const BLACK_HOLE_ORBIT_LAYOUTS: Dictionary = {
	# Merkez
	"bh_core": {"radius": 0.0, "base_angle": 0.0, "speed": 0.0, "flatten": 1.0, "ring_key": "core"},
	# Halka 1 — r=430, 4 eşit açı (0°, 90°, 180°, 270°)
	"bh_r1_a": {"radius": 430.0, "base_angle":  0.0,       "speed": 0.42, "flatten": 0.62, "ring_key": "inner"},
	"bh_r1_b": {"radius": 430.0, "base_angle":  PI * 0.5,  "speed": 0.42, "flatten": 0.62, "ring_key": "inner"},
	"bh_r1_c": {"radius": 430.0, "base_angle": -PI,        "speed": 0.42, "flatten": 0.62, "ring_key": "inner"},
	"bh_r1_d": {"radius": 430.0, "base_angle": -PI * 0.5,  "speed": 0.42, "flatten": 0.62, "ring_key": "inner"},
	# Halka 2 — r=700, 45° offset (22.5°, 112.5°, 202.5°, 292.5°)
	"bh_r2_a": {"radius": 700.0, "base_angle":  PI * 0.25, "speed": 0.28, "flatten": 0.60, "ring_key": "mid"},
	"bh_r2_b": {"radius": 700.0, "base_angle":  PI * 0.75, "speed": 0.28, "flatten": 0.60, "ring_key": "mid"},
	"bh_r2_c": {"radius": 700.0, "base_angle": -PI * 0.75, "speed": 0.28, "flatten": 0.60, "ring_key": "mid"},
	"bh_r2_d": {"radius": 700.0, "base_angle": -PI * 0.25, "speed": 0.28, "flatten": 0.60, "ring_key": "mid"},
	# Halka 3 — r=980, ring 1 ile hizalı
	"bh_r3_a": {"radius": 980.0, "base_angle":  0.0,       "speed": 0.16, "flatten": 0.58, "ring_key": "outer"},
	"bh_r3_b": {"radius": 980.0, "base_angle":  PI * 0.5,  "speed": 0.16, "flatten": 0.58, "ring_key": "outer"},
	"bh_r3_c": {"radius": 980.0, "base_angle": -PI,        "speed": 0.16, "flatten": 0.58, "ring_key": "outer"},
	"bh_r3_d": {"radius": 980.0, "base_angle": -PI * 0.5,  "speed": 0.16, "flatten": 0.58, "ring_key": "outer"},
	# Halka 4 — r=1250, ring 2 ile hizalı
	"bh_r4_a": {"radius": 1250.0, "base_angle":  PI * 0.25, "speed": 0.10, "flatten": 0.56, "ring_key": "outer"},
	"bh_r4_b": {"radius": 1250.0, "base_angle":  PI * 0.75, "speed": 0.10, "flatten": 0.56, "ring_key": "outer"},
	"bh_r4_c": {"radius": 1250.0, "base_angle": -PI * 0.75, "speed": 0.10, "flatten": 0.56, "ring_key": "outer"},
	"bh_r4_d": {"radius": 1250.0, "base_angle": -PI * 0.25, "speed": 0.10, "flatten": 0.56, "ring_key": "outer"},
}

# Large = 50px radius (100px diameter), Small = 20px radius (40px diameter)
const LARGE_DIAMETER: float = 100.0
const SMALL_DIAMETER: float =  40.0

const CONNECTIONS: Array = [
	["energy_field", "mining"],
	["energy_field", "mining_speed"],
	["energy_field", "damage_aura"],
	["energy_field", "drop_collection"],
	["energy_field", "orbit_mode"],
	["energy_field", "energy_orb_magnet"],
	["energy_field", "crit_chance"],
	["energy_field", "laser_duration"],
	["energy_field", "dual_laser"],
]

const BLACK_HOLE_CONNECTIONS: Array = [
	# Merkez → Halka 1
	["bh_core", "bh_r1_a"],
	["bh_core", "bh_r1_b"],
	["bh_core", "bh_r1_c"],
	["bh_core", "bh_r1_d"],
	# Halka 1 → Halka 2 (her dal bağımsız)
	["bh_r1_a", "bh_r2_a"],
	["bh_r1_b", "bh_r2_b"],
	["bh_r1_c", "bh_r2_c"],
	["bh_r1_d", "bh_r2_d"],
	# Halka 2 → Halka 3
	["bh_r2_a", "bh_r3_a"],
	["bh_r2_b", "bh_r3_b"],
	["bh_r2_c", "bh_r3_c"],
	["bh_r2_d", "bh_r3_d"],
	# Halka 3 → Halka 4
	["bh_r3_a", "bh_r4_a"],
	["bh_r3_b", "bh_r4_b"],
	["bh_r3_c", "bh_r4_c"],
	["bh_r3_d", "bh_r4_d"],
]

const SKILL_CONFIGS: Dictionary = {
	# ENERGY / FORCE — çekim, manyetik alan, enerji akışı
	"energy_field": {
		"label": "Cekim Kuvveti", "short": "", "is_root": true, "large": true,
		"skill_class": "ENERGY",
		"buy_method": "buy_energy_field_upgrade", "can_method": "can_buy_energy_field_upgrade",
	},
	"drop_collection": {
		"label": "Drop\nCekimi",  "short": "P", "is_root": false, "large": false,
		"skill_class": "ENERGY",
		"buy_method": "unlock_drop_collection_skill", "can_method": "can_unlock_drop_collection_skill",
	},
	"energy_orb_magnet": {
		"label": "Enerji Orb\nCekimi", "short": "E", "is_root": false, "large": false,
		"skill_class": "ENERGY",
		"buy_method": "buy_energy_orb_magnet_upgrade", "can_method": "can_buy_energy_orb_magnet_upgrade",
	},
	# MINING / RESOURCE — toplama, verimlilik, kaynak kazancı
	"mining": {
		"label": "Mining\n+1",   "short": "M", "is_root": false, "large": false,
		"skill_class": "MINING",
		"buy_method": "buy_mining_upgrade", "can_method": "can_buy_mining_upgrade",
	},
	"mining_speed": {
		"label": "Mining\nSpeed", "short": "S", "is_root": false, "large": false,
		"skill_class": "MINING",
		"buy_method": "buy_mining_speed_upgrade", "can_method": "can_buy_mining_speed_upgrade",
	},
	# COMBAT / DAMAGE — patlama, saldırı, kritik
	"damage_aura": {
		"label": "Damage\nArea",  "short": "D", "is_root": false, "large": false,
		"skill_class": "COMBAT",
		"buy_method": "buy_damage_aura_upgrade", "can_method": "can_buy_damage_aura_upgrade",
	},
	"crit_chance": {
		"label": "Kritik\nSans", "short": "K", "is_root": false, "large": false,
		"skill_class": "COMBAT",
		"buy_method": "buy_crit_chance_upgrade", "can_method": "can_buy_crit_chance_upgrade",
	},
	# UTILITY / CONTROL — kontrol, yönlendirme, mekanik hakimiyet
	"orbit_mode": {
		"label": "Orbit\nModu",   "short": "O", "is_root": false, "large": true,
		"skill_class": "UTILITY",
		"buy_method": "buy_orbit_mode_upgrade", "can_method": "can_buy_orbit_mode_upgrade",
	},
	# Placeholder — gelecek skill slotları
	"laser_duration": {
		"label": "Lazer\nSuresi", "short": "L", "is_root": false, "large": false,
		"skill_class": "COMBAT",
		"buy_method": "buy_laser_duration_upgrade", "can_method": "can_buy_laser_duration_upgrade",
	},
	"dual_laser": {
		"label": "Cift\nLazer", "short": "2L", "is_root": false, "large": false,
		"skill_class": "COMBAT",
		"buy_method": "buy_dual_laser_upgrade", "can_method": "can_buy_dual_laser_upgrade",
	},
	"placeholder_d": {
		"label": "???", "short": "", "is_root": false, "large": false, "placeholder": true,
		"skill_class": "DEFAULT",
		"buy_method": "", "can_method": "",
	},
	"bh_core": {
		"label": "KaraDelik\nCekirdegi", "short": "BH", "is_root": true, "large": true,
		"skill_class": "UTILITY", "domain": "black_hole",
	},
	# Halka 1 — 4 slot
	"bh_r1_a": {"label": "???", "short": "", "is_root": false, "large": false, "placeholder": true, "skill_class": "DEFAULT", "domain": "black_hole"},
	"bh_r1_b": {"label": "???", "short": "", "is_root": false, "large": false, "placeholder": true, "skill_class": "DEFAULT", "domain": "black_hole"},
	"bh_r1_c": {"label": "???", "short": "", "is_root": false, "large": false, "placeholder": true, "skill_class": "DEFAULT", "domain": "black_hole"},
	"bh_r1_d": {"label": "???", "short": "", "is_root": false, "large": false, "placeholder": true, "skill_class": "DEFAULT", "domain": "black_hole"},
	# Halka 2 — 4 slot
	"bh_r2_a": {"label": "???", "short": "", "is_root": false, "large": false, "placeholder": true, "skill_class": "DEFAULT", "domain": "black_hole"},
	"bh_r2_b": {"label": "???", "short": "", "is_root": false, "large": false, "placeholder": true, "skill_class": "DEFAULT", "domain": "black_hole"},
	"bh_r2_c": {"label": "???", "short": "", "is_root": false, "large": false, "placeholder": true, "skill_class": "DEFAULT", "domain": "black_hole"},
	"bh_r2_d": {"label": "???", "short": "", "is_root": false, "large": false, "placeholder": true, "skill_class": "DEFAULT", "domain": "black_hole"},
	# Halka 3 — 4 slot
	"bh_r3_a": {"label": "???", "short": "", "is_root": false, "large": false, "placeholder": true, "skill_class": "DEFAULT", "domain": "black_hole"},
	"bh_r3_b": {"label": "???", "short": "", "is_root": false, "large": false, "placeholder": true, "skill_class": "DEFAULT", "domain": "black_hole"},
	"bh_r3_c": {"label": "???", "short": "", "is_root": false, "large": false, "placeholder": true, "skill_class": "DEFAULT", "domain": "black_hole"},
	"bh_r3_d": {"label": "???", "short": "", "is_root": false, "large": false, "placeholder": true, "skill_class": "DEFAULT", "domain": "black_hole"},
	# Halka 4 — 4 slot
	"bh_r4_a": {"label": "???", "short": "", "is_root": false, "large": false, "placeholder": true, "skill_class": "DEFAULT", "domain": "black_hole"},
	"bh_r4_b": {"label": "???", "short": "", "is_root": false, "large": false, "placeholder": true, "skill_class": "DEFAULT", "domain": "black_hole"},
	"bh_r4_c": {"label": "???", "short": "", "is_root": false, "large": false, "placeholder": true, "skill_class": "DEFAULT", "domain": "black_hole"},
	"bh_r4_d": {"label": "???", "short": "", "is_root": false, "large": false, "placeholder": true, "skill_class": "DEFAULT", "domain": "black_hole"},
}

# ── Zoom ──────────────────────────────────────────────────────────────────────
# Initial zoom opens on the black hole scale first.
# Scroll in to dive toward the player core, scroll out for the larger cosmic layer.
const ZOOM_MIN:  float = 0.50
const ZOOM_MAX:  float = 2.20
const ZOOM_STEP: float = 0.12
const OPENING_ZOOM: float = 0.56

# ── BH Node Sub-panel ─────────────────────────────────────────────────────────
# Her BH node açıldığında player paneli ile aynı yapıda 7 skill orbiti gösterir.
# İç halka (r=170): 3 skill   |   Orta halka (r=295): 4 skill
const BH_SUBPANEL_TEMPLATE: Array = [
	{"r": 170.0, "angle": -PI * 0.52, "speed": 1.10, "flatten": ORBIT_FLATTEN, "ring_key": "inner"},
	{"r": 170.0, "angle": -PI * 0.08, "speed": 1.10, "flatten": ORBIT_FLATTEN, "ring_key": "inner"},
	{"r": 170.0, "angle":  PI * 0.34, "speed": 1.10, "flatten": ORBIT_FLATTEN, "ring_key": "inner"},
	{"r": 295.0, "angle":  PI * 0.92, "speed": 0.62, "flatten": ORBIT_FLATTEN, "ring_key": "mid"},
	{"r": 295.0, "angle": -PI * 0.02, "speed": 0.62, "flatten": ORBIT_FLATTEN, "ring_key": "mid"},
	{"r": 295.0, "angle": -PI * 0.88, "speed": 0.62, "flatten": ORBIT_FLATTEN, "ring_key": "mid"},
	{"r": 295.0, "angle":  PI * 0.54, "speed": 0.62, "flatten": ORBIT_FLATTEN, "ring_key": "mid"},
]
const BH_MAIN_NODE_IDS: Array = [
	"bh_r1_a", "bh_r1_b", "bh_r1_c", "bh_r1_d",
	"bh_r2_a", "bh_r2_b", "bh_r2_c", "bh_r2_d",
	"bh_r3_a", "bh_r3_b", "bh_r3_c", "bh_r3_d",
	"bh_r4_a", "bh_r4_b", "bh_r4_c", "bh_r4_d",
]
# BH sub-panel zoom: OPENING_ZOOM = kapalı başlangıç, ZOOM_MAX = tam açık
const BH_SUB_ENTER_THRESHOLD: float = 0.60  # bu zoom altında BH panelindeyiz
const ZOOM_TRAVEL_SPEED: float = 0.72
const BACKGROUND_ORBIT_COUNT: int = 7
const TOPDOWN_BLEND_SPEED: float = 2.4
const BLACK_HOLE_FADE_OUT_END: float = 0.42
const PLAYER_FADE_IN_START: float = 0.58
const DRAG_ROTATION_SPEED: float = 0.0085
const DRAG_INERTIA_DAMP: float = 4.0
const SCREEN_TILT_MAX: float = 0.085
const SCREEN_TILT_RESPONSE: float = 0.0038
const SCREEN_SWAY_RESPONSE: float = 12.0
const SCREEN_SWAY_MAX: float = 36.0
var _zoom_scale: float = OPENING_ZOOM

# ── Runtime nodes ──────────────────────────────────────────────────────────────
var _panel_root:      Control        = null
var _zoom_container:  Control        = null
var _star_bg:         StarBackground = null
var _conn_lines:      ConnectionLines = null
var _resource_panel:  ResourcePanel  = null
var _tooltip:         SkillTooltip   = null
var _close_hint:      Label          = null
var _dev_button:      Button         = null
var _dev_label:       Label          = null
var _skill_nodes:     Dictionary     = {}   # skill_id -> SkillNodeUI
var _node_centers:    Dictionary     = {}
var _node_depths:     Dictionary     = {}
var _galaxy_time:     float          = 0.0
var _hovered_skill_id: String        = ""
var _manual_rotation: float          = 0.0
var _rotation_velocity: float        = 0.0
var _is_drag_rotating: bool          = false
var _drag_last_mouse_pos: Vector2    = Vector2.ZERO
var _screen_tilt: float              = 0.0
var _screen_sway: Vector2            = Vector2.ZERO
var _zoom_target: float              = OPENING_ZOOM
var _topdown_blend: float            = 0.0
var _topdown_target: float           = 0.0

# BH sub-panel state
var _focused_bh_node: String         = ""
var _bh_sub_zoom: float              = 0.0
var _bh_sub_zoom_target: float       = 0.0
var _bh_sub_nodes: Dictionary        = {}   # bh_node_id -> Array[SkillNodeUI]

# Guard against double-building (e.g. if _ready() is somehow called twice)
var _ui_built: bool = false


func _ready() -> void:
	layer   = 10
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	# ── KEY FIX: remove every node left over from the old .tscn ──────────────
	# Old scene had SubViewportContainer, SubViewport, UpgradeMap + Camera2D,
	# and direct Button/Label children.  Those render as ghost UI if not freed.
	_purge_legacy_scene_children()
	_build_ui()


# ── Public API ─────────────────────────────────────────────────────────────────

func open_screen() -> void:
	visible = true
	_hovered_skill_id = ""
	_galaxy_time = 0.0
	_zoom_scale = OPENING_ZOOM
	_zoom_target = OPENING_ZOOM
	_manual_rotation = 0.0
	_rotation_velocity = 0.0
	_is_drag_rotating = false
	_screen_tilt = 0.0
	_screen_sway = Vector2.ZERO
	_topdown_blend = 0.0
	_topdown_target = 0.0
	_focused_bh_node = ""
	_bh_sub_zoom = 0.0
	_bh_sub_zoom_target = 0.0
	_layout_nodes()
	_update_all()
	if _star_bg != null:
		_star_bg.on_panel_opened()


func close_screen() -> void:
	visible = false
	_hide_tooltip()


# ── Input ──────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.is_pressed() and not event.is_echo() and (event as InputEventKey).keycode == KEY_K):
		close_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_G:
			_on_dev_pressed()
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _is_drag_rotating:
			var drag_delta := motion.position - _drag_last_mouse_pos
			_drag_last_mouse_pos = motion.position
			var angle_delta := (drag_delta.x + drag_delta.y * 0.35) * DRAG_ROTATION_SPEED
			_manual_rotation += angle_delta
			_rotation_velocity = angle_delta / maxf(get_process_delta_time(), 0.0001)
			_screen_tilt = clampf(_screen_tilt + drag_delta.x * SCREEN_TILT_RESPONSE, -SCREEN_TILT_MAX, SCREEN_TILT_MAX)
			_screen_sway += Vector2(drag_delta.x, drag_delta.y) * 0.45
			_screen_sway = _screen_sway.limit_length(SCREEN_SWAY_MAX)
			_update_galaxy_layout()
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.pressed and _dev_button != null and _dev_button.get_global_rect().has_point(mb.position):
		return
	if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_MIDDLE:
		var can_drag := mb.button_index == MOUSE_BUTTON_MIDDLE or _hovered_skill_id.is_empty()
		if can_drag:
			var was_dragging := _is_drag_rotating
			_is_drag_rotating = mb.pressed
			_drag_last_mouse_pos = mb.position
			if mb.pressed:
				_rotation_velocity = 0.0
				get_viewport().set_input_as_handled()
			elif was_dragging:
				get_viewport().set_input_as_handled()
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		if mb.pressed:
			if not _hovered_skill_id.is_empty():
				_on_skill_downgraded(_hovered_skill_id)
				get_viewport().set_input_as_handled()
				return
			_topdown_target = 0.0 if _topdown_target >= 0.5 else 1.0
			get_viewport().set_input_as_handled()
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		if not _focused_bh_node.is_empty():
			# Inside sub-panel — open further
			_bh_sub_zoom_target = minf(_bh_sub_zoom_target + ZOOM_STEP * 2.0, 1.0)
		elif _zoom_scale <= BH_SUB_ENTER_THRESHOLD and _is_bh_main_node(_hovered_skill_id):
			# Hovering a BH node while in BH zoom range — enter its sub-panel
			_focused_bh_node = _hovered_skill_id
			_bh_sub_zoom = 0.0
			_bh_sub_zoom_target = ZOOM_STEP * 2.0
		else:
			_zoom_target = clampf(_zoom_target + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
		get_viewport().set_input_as_handled()
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if not _focused_bh_node.is_empty():
			_bh_sub_zoom_target = maxf(_bh_sub_zoom_target - ZOOM_STEP * 2.0, 0.0)
			if _bh_sub_zoom_target <= 0.0:
				# Collapsed — exit sub-panel
				_focused_bh_node = ""
		else:
			_zoom_target = clampf(_zoom_target - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
		get_viewport().set_input_as_handled()


func _apply_zoom(center: Vector2) -> void:
	if _zoom_container == null:
		return
	# When focused on a BH sub-panel, shift the pivot toward that node so
	# the zoom-in effect centres on it rather than on the screen centre.
	var pivot := center
	if not _focused_bh_node.is_empty() and _node_centers.has(_focused_bh_node):
		pivot = pivot.lerp(_node_centers[_focused_bh_node], _bh_sub_zoom)
	_zoom_container.pivot_offset = pivot
	_zoom_container.scale        = Vector2(_zoom_scale, _zoom_scale)
	_zoom_container.rotation     = _screen_tilt
	_zoom_container.position     = _screen_sway
	if _star_bg != null:
		_star_bg.position = _screen_sway * -0.20



# ── Legacy cleanup ─────────────────────────────────────────────────────────────

func _purge_legacy_scene_children() -> void:
	## Removes all nodes that existed in the old .tscn scene structure.
	## This prevents ghost rendering of the old SubViewport/Button/Label tree.
	var legacy := get_children()
	if legacy.is_empty():
		return
	print("[UpgradeScreen] Purging %d legacy scene node(s)." % legacy.size())
	for child in legacy:
		# Disable processing + rendering immediately, then queue for deletion.
		child.process_mode = Node.PROCESS_MODE_DISABLED
		child.visible      = false
		child.queue_free()


# ── UI construction ────────────────────────────────────────────────────────────

func _build_ui() -> void:
	if _ui_built:
		return
	_ui_built = true

	# ── Full-screen root ──────────────────────────────────────────────────────
	_panel_root = Control.new()
	_panel_root.name = "PanelRoot"
	_panel_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_panel_root)

	# ── Dark background ───────────────────────────────────────────────────────
	var bg_rect := ColorRect.new()
	bg_rect.name         = "DarkBg"
	bg_rect.color        = Color(0.004, 0.005, 0.008, 0.98)
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(bg_rect)

	# ── Star field (full-screen, not zoomed) ──────────────────────────────────
	_star_bg = StarBackground.new()
	_star_bg.name = "StarBg"
	_star_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_root.add_child(_star_bg)

	# ── Zoom container — rings + skills scale together ─────────────────────────
	# Star bg, resource panel, tooltip stay in _panel_root (unzoomed).
	_zoom_container = Control.new()
	_zoom_container.name         = "ZoomContainer"
	_zoom_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_zoom_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel_root.add_child(_zoom_container)

	# ── Rings + connection lines (inside zoom container) ──────────────────────
	_conn_lines = ConnectionLines.new()
	_conn_lines.name = "ConnectionLines"
	_conn_lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	_zoom_container.add_child(_conn_lines)

	# ── Skill node UIs (inside zoom container) ────────────────────────────────
	for skill_id in SKILL_CONFIGS:
		var cfg: Dictionary = SKILL_CONFIGS[skill_id]
		var node := SkillNodeUI.new()
		node.name = "SkillNode_" + skill_id
		_zoom_container.add_child(node)
		node.setup(skill_id, cfg)
		node.hover_entered.connect(_on_hover_entered)
		node.hover_exited.connect(_on_hover_exited)
		node.skill_pressed.connect(_on_skill_pressed)
		node.skill_downgraded.connect(_on_skill_downgraded)
		_skill_nodes[skill_id] = node

	# ── Resource panel (top-left) ─────────────────────────────────────────────
	_resource_panel = ResourcePanel.new()
	_resource_panel.name = "ResourcePanel"
	_panel_root.add_child(_resource_panel)

	# ── Developer mode button (below resource panel) ──────────────────────────
	_dev_button = Button.new()
	_dev_button.name = "DevButton"
	_dev_button.text = "[G] Dev Mode"
	_dev_button.flat = false
	_dev_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_dev_button.focus_mode = Control.FOCUS_ALL
	_dev_button.add_theme_font_size_override("font_size", 12)
	var dev_style := StyleBoxFlat.new()
	dev_style.bg_color       = Color(0.18, 0.14, 0.08, 0.90)
	dev_style.set_border_width_all(1)
	dev_style.border_color   = Color(0.70, 0.60, 0.28, 0.70)
	dev_style.set_corner_radius_all(6)
	_dev_button.add_theme_stylebox_override("normal", dev_style)
	_dev_button.add_theme_color_override("font_color", Color(1.0, 0.88, 0.44, 1.0))
	_dev_button.pressed.connect(_on_dev_pressed)
	_panel_root.add_child(_dev_button)

	_dev_label = Label.new()
	_dev_label.name = "DevLabel"
	_dev_label.add_theme_font_size_override("font_size", 11)
	_dev_label.add_theme_color_override("font_color", Color(0.75, 0.68, 0.42, 0.80))
	_panel_root.add_child(_dev_label)

	# ── BH sub-panel skill nodes (7 per main BH node, inside zoom container) ──
	for bh_node_id in BH_MAIN_NODE_IDS:
		var sub_list: Array = []
		for i in BH_SUBPANEL_TEMPLATE.size():
			var sub_id: String = String(bh_node_id) + "_sub_" + str(i)
			var sub_node := SkillNodeUI.new()
			sub_node.name = "SkillNode_" + sub_id
			_zoom_container.add_child(sub_node)
			sub_node.setup(sub_id, {
				"label": "???", "short": "", "is_root": false, "large": false,
				"placeholder": true, "skill_class": "DEFAULT", "domain": "black_hole_sub"
			})
			sub_node.visible  = false
			sub_node.modulate = Color(1.0, 1.0, 1.0, 0.0)
			sub_list.append(sub_node)
		_bh_sub_nodes[bh_node_id] = sub_list

	# ── Tooltip (rendered on top) ─────────────────────────────────────────────
	_tooltip = SkillTooltip.new()
	_tooltip.name = "SkillTooltip"
	_panel_root.add_child(_tooltip)

	# ── Close hint (bottom center) ────────────────────────────────────────────
	_close_hint = Label.new()
	_close_hint.name = "CloseHint"
	_close_hint.text = "ESC — Kapat"
	_close_hint.add_theme_font_size_override("font_size", 17)
	_close_hint.add_theme_color_override("font_color", Color(0.48, 0.60, 0.80, 0.60))
	_close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_close_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_close_hint.offset_bottom = -16.0
	_close_hint.offset_top    = -48.0
	_panel_root.add_child(_close_hint)


# ── Layout ────────────────────────────────────────────────────────────────────

func _layout_nodes() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		vp_size = Vector2(1920.0, 1080.0)
	var center := vp_size * 0.5

	if _panel_root != null:
		_panel_root.size = vp_size
	if _zoom_container != null:
		_zoom_container.size = vp_size

	for skill_id in SKILL_CONFIGS:
		var node: SkillNodeUI = _skill_nodes.get(skill_id)
		if node == null:
			continue
		var cfg: Dictionary = SKILL_CONFIGS[skill_id]
		var is_large: bool  = bool(cfg.get("large", true))
		var node_sz: float  = LARGE_DIAMETER if is_large else SMALL_DIAMETER
		if skill_id == "energy_field":
			node_sz *= 0.5
		node.size           = Vector2(node_sz, node_sz)

	if _star_bg != null:
		_star_bg.size = vp_size
	if _conn_lines != null:
		_conn_lines.size = vp_size

	_apply_zoom(center)
	_update_galaxy_layout()

	# Resource panel — top-left
	if _resource_panel != null:
		_resource_panel.position = Vector2(24.0, 24.0)

	# Developer button — below resource panel
	if _dev_button != null and _resource_panel != null:
		var rp_bottom: float = _resource_panel.position.y + _resource_panel.custom_minimum_size.y + 12.0
		_dev_button.position = Vector2(24.0, rp_bottom)
		_dev_button.size     = Vector2(180.0, 34.0)
	if _dev_label != null and _dev_button != null:
		_dev_label.position = Vector2(24.0, _dev_button.position.y + _dev_button.size.y + 4.0)
		_dev_label.size     = Vector2(220.0, 60.0)


func _update_galaxy_layout() -> void:
	if _zoom_container == null:
		return
	var vp_size := _zoom_container.size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return
	var center := vp_size * 0.5 + Vector2(0.0, lerpf(GALAXY_TILT_Y, 0.0, _topdown_blend))
	_node_centers.clear()
	_node_depths.clear()
	var orbit_defs: Array = []
	var visible_connections: Array = []
	var zoom_t := _get_zoom_blend_t()
	orbit_defs.append_array(_build_background_orbits(zoom_t))

	for skill_id in SKILL_CONFIGS:
		var node: SkillNodeUI = _skill_nodes.get(skill_id)
		if node == null:
			continue
		var cfg: Dictionary = SKILL_CONFIGS[skill_id]
		var domain := str(cfg.get("domain", "player"))
		var orbit: Dictionary = _get_orbit_layout(skill_id, domain)
		var domain_weight := _get_domain_weight(domain, zoom_t)
		var radius := float(orbit.get("radius", 0.0))
		var flatten := lerpf(float(orbit.get("flatten", ORBIT_FLATTEN)), 1.0, _topdown_blend)
		var base_angle := float(orbit.get("base_angle", 0.0))
		var speed_mul := float(orbit.get("speed", 0.0))
		var angle := base_angle + _manual_rotation + _galaxy_time * GALAXY_DRIFT_SPEED * speed_mul
		var offset := Vector2(cos(angle) * radius, sin(angle) * radius * flatten)
		var pos_center := center + offset
		var depth_t := 1.0 if radius <= 0.0 else clampf((sin(angle) + 1.0) * 0.5, 0.0, 1.0)
		var front_boost := 0.0
		if skill_id == _hovered_skill_id:
			front_boost = 1.0
			pos_center.y -= 18.0
		var node_sz: float = LARGE_DIAMETER if bool(cfg.get("large", true)) else SMALL_DIAMETER
		if skill_id == "energy_field":
			node_sz *= 0.5
		node.position = pos_center - Vector2(node_sz * 0.5, node_sz * 0.5)
		var visible_depth := clampf(depth_t * domain_weight, 0.0, 1.0)
		node.visible = domain_weight > 0.03
		node.z_index = int(round(lerpf(10.0, 200.0, visible_depth + front_boost * 0.2)))
		node.set_depth_visual(visible_depth, lerpf(0.70, 1.18, depth_t) * lerpf(0.75, 1.0, domain_weight) + front_boost * 0.08, front_boost)
		if node.visible:
			_node_centers[skill_id] = pos_center
			_node_depths[skill_id] = clampf(visible_depth + front_boost * 0.2, 0.0, 1.0)
		if radius > 0.0 and domain_weight > 0.08:
			orbit_defs.append({
				"radius": radius,
				"flatten": flatten,
				"ring_key": str(orbit.get("ring_key", "mid")),
			})

	# ── BH sub-panel node layout ──────────────────────────────────────────────
	for bh_id_v in _bh_sub_nodes:
		var bh_id: String = String(bh_id_v)
		var sub_list: Array = _bh_sub_nodes[bh_id]
		var is_focused: bool = bh_id == _focused_bh_node
		var sub_alpha: float = _bh_sub_zoom if is_focused else 0.0
		var focus_center: Vector2 = _node_centers.get(bh_id, center)
		for i in sub_list.size():
			var sub_node: SkillNodeUI = sub_list[i]
			if sub_node == null:
				continue
			sub_node.visible = sub_alpha > 0.02
			if not sub_node.visible:
				sub_node.modulate = Color(1.0, 1.0, 1.0, 0.0)
				continue
			var tmpl: Dictionary = BH_SUBPANEL_TEMPLATE[i]
			var r     := float(tmpl.get("r",       170.0)) * sub_alpha
			var flat  := lerpf(float(tmpl.get("flatten", ORBIT_FLATTEN)), 1.0, _topdown_blend)
			var spd   := float(tmpl.get("speed",   1.10))
			var ang   := float(tmpl.get("angle",   0.0)) + _manual_rotation + _galaxy_time * GALAXY_DRIFT_SPEED * spd
			var offs  := Vector2(cos(ang) * r, sin(ang) * r * flat)
			var depth_t := clampf((sin(ang) + 1.0) * 0.5, 0.0, 1.0)
			sub_node.position = focus_center + offs - Vector2(SMALL_DIAMETER * 0.5, SMALL_DIAMETER * 0.5)
			sub_node.size     = Vector2(SMALL_DIAMETER, SMALL_DIAMETER)
			sub_node.modulate = Color(1.0, 1.0, 1.0, sub_alpha)
			sub_node.z_index  = int(round(lerpf(110.0, 300.0, depth_t)))
			sub_node.set_depth_visual(depth_t * sub_alpha, lerpf(0.70, 1.18, depth_t), 0.0)

	if _conn_lines != null:
		for pair in CONNECTIONS:
			if _node_centers.has(str(pair[0])) and _node_centers.has(str(pair[1])):
				visible_connections.append(pair)
		for pair in BLACK_HOLE_CONNECTIONS:
			if _node_centers.has(str(pair[0])) and _node_centers.has(str(pair[1])):
				visible_connections.append(pair)
		_conn_lines.set_data(_node_centers, _node_depths, visible_connections, _dedupe_orbits(orbit_defs))


func _dedupe_orbits(orbit_defs: Array) -> Array:
	var unique: Dictionary = {}
	var deduped: Array = []
	for orbit_v in orbit_defs:
		if not (orbit_v is Dictionary):
			continue
		var orbit := orbit_v as Dictionary
		var key := "%s|%.2f|%.3f|%.3f" % [
			str(orbit.get("ring_key", "mid")),
			float(orbit.get("radius", 0.0)),
			float(orbit.get("flatten", ORBIT_FLATTEN)),
			float(orbit.get("alpha", 0.0)),
		]
		if unique.has(key):
			continue
		unique[key] = true
		deduped.append(orbit)
	return deduped

func _get_zoom_blend_t() -> float:
	return clampf((_zoom_scale - 0.65) / 0.95, 0.0, 1.0)


func _get_domain_weight(domain: String, zoom_t: float) -> float:
	if domain == "black_hole":
		return 1.0 - _smooth_blend(zoom_t, 0.0, BLACK_HOLE_FADE_OUT_END)
	return _smooth_blend(zoom_t, PLAYER_FADE_IN_START, 1.0)


func _smooth_blend(value: float, edge0: float, edge1: float) -> float:
	if is_equal_approx(edge0, edge1):
		return 1.0 if value >= edge1 else 0.0
	var t := clampf((value - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _get_orbit_layout(skill_id: String, domain: String) -> Dictionary:
	var orbit: Dictionary = {}
	if domain == "black_hole":
		orbit = BLACK_HOLE_ORBIT_LAYOUTS.get(skill_id, {})
	else:
		orbit = ORBIT_LAYOUTS.get(skill_id, {})
	return _snap_orbit_to_background(domain, orbit)


func _build_background_orbits(zoom_t: float) -> Array:
	var orbits: Array = []
	var player_weight := _get_domain_weight("player", zoom_t)
	var black_hole_weight := _get_domain_weight("black_hole", zoom_t)
	for orbit_data_v in _get_background_orbit_samples("player"):
		var orbit_data := orbit_data_v as Dictionary
		orbits.append({
			"radius": float(orbit_data.get("radius", 0.0)),
			"flatten": lerpf(float(orbit_data.get("flatten", ORBIT_FLATTEN)), 1.0, _topdown_blend),
			"ring_key": "player_bg",
			"alpha": float(orbit_data.get("alpha", 0.0)) * player_weight,
			"width": float(orbit_data.get("width", 1.0)),
		})
	for orbit_data_v in _get_background_orbit_samples("black_hole"):
		var orbit_data := orbit_data_v as Dictionary
		orbits.append({
			"radius": float(orbit_data.get("radius", 0.0)),
			"flatten": lerpf(float(orbit_data.get("flatten", 0.62)), 1.0, _topdown_blend),
			"ring_key": "black_hole_bg",
			"alpha": float(orbit_data.get("alpha", 0.0)) * black_hole_weight,
			"width": float(orbit_data.get("width", 1.0)),
		})
	return orbits


func _get_background_orbit_samples(domain: String) -> Array:
	var samples: Array = []
	for i in range(BACKGROUND_ORBIT_COUNT):
		var t := float(i) / float(maxi(BACKGROUND_ORBIT_COUNT - 1, 1))
		if domain == "black_hole":
			samples.append({
				"radius": lerpf(240.0, 1460.0, t),
				"flatten": lerpf(0.66, 0.56, t),
				"alpha": lerpf(0.14, 0.040, t),
				"width": lerpf(1.25, 0.72, t),
			})
		else:
			samples.append({
				"radius": lerpf(110.0, 560.0, t),
				"flatten": lerpf(0.58, 0.50, t),
				"alpha": lerpf(0.12, 0.035, t),
				"width": lerpf(1.15, 0.65, t),
			})
	return samples


func _snap_orbit_to_background(domain: String, orbit: Dictionary) -> Dictionary:
	if orbit.is_empty():
		return orbit
	var radius := float(orbit.get("radius", 0.0))
	if radius <= 0.0:
		return orbit
	var samples := _get_background_orbit_samples(domain)
	if samples.is_empty():
		return orbit
	var closest := samples[0] as Dictionary
	var best_diff := absf(radius - float(closest.get("radius", radius)))
	for sample_v in samples:
		var sample := sample_v as Dictionary
		var diff := absf(radius - float(sample.get("radius", radius)))
		if diff < best_diff:
			best_diff = diff
			closest = sample
	var snapped := orbit.duplicate()
	snapped["radius"] = float(closest.get("radius", radius))
	snapped["flatten"] = float(closest.get("flatten", orbit.get("flatten", ORBIT_FLATTEN)))
	return snapped


# State update

func _process(delta: float) -> void:
	if not visible:
		return
	if not is_equal_approx(_zoom_scale, _zoom_target):
		_zoom_scale = move_toward(_zoom_scale, _zoom_target, ZOOM_TRAVEL_SPEED * delta)
	if not is_equal_approx(_bh_sub_zoom, _bh_sub_zoom_target):
		_bh_sub_zoom = move_toward(_bh_sub_zoom, _bh_sub_zoom_target, ZOOM_TRAVEL_SPEED * delta)
	if not is_equal_approx(_topdown_blend, _topdown_target):
		_topdown_blend = move_toward(_topdown_blend, _topdown_target, TOPDOWN_BLEND_SPEED * delta)
	var drift_multiplier := GALAXY_FOCUS_SPEED / GALAXY_DRIFT_SPEED if not _hovered_skill_id.is_empty() else 1.0
	_galaxy_time += delta * drift_multiplier
	if not _is_drag_rotating and absf(_rotation_velocity) > 0.0001:
		_manual_rotation += _rotation_velocity * delta
		_rotation_velocity = move_toward(_rotation_velocity, 0.0, DRAG_INERTIA_DAMP * delta)
	_screen_tilt = move_toward(_screen_tilt, clampf(_rotation_velocity * 0.02, -SCREEN_TILT_MAX, SCREEN_TILT_MAX), 0.12 * delta)
	_screen_sway = _screen_sway.move_toward(Vector2.ZERO, SCREEN_SWAY_RESPONSE * delta)
	_apply_zoom(_zoom_container.size * 0.5)
	_update_galaxy_layout()
	_update_all()


func _update_all() -> void:
	var rs := get_node_or_null("/root/RunState")
	var um := get_node_or_null("/root/UpgradeManager")
	for skill_id in _skill_nodes:
		var node: SkillNodeUI = _skill_nodes[skill_id]
		if node == null:
			continue
		node.update_state(_build_state(skill_id, rs, um))
	# Sub-panel placeholder state — all "Yakinda" for now
	var sub_placeholder := {
		"locked": true, "level": 0, "max_level": 1,
		"can_buy": false, "cost_text": "", "status_text": "Yakinda"
	}
	for bh_id_v in _bh_sub_nodes:
		var bh_id: String = String(bh_id_v)
		for sub_node_v in _bh_sub_nodes[bh_id]:
			var sub_node: SkillNodeUI = sub_node_v
			if sub_node != null:
				sub_node.update_state(sub_placeholder)
	_update_resources(rs)
	_update_dev_button(rs, um)


func _build_state(skill_id: String, rs: Node, um: Node) -> Dictionary:
	var st := {
		"locked": true, "level": 0, "max_level": 1,
		"can_buy": false, "cost_text": "", "status_text": "Kilitli"
	}
	if rs == null:
		return st

	var is_black_hole_skill := skill_id.begins_with("bh_")
	if not is_black_hole_skill and um == null:
		return st
	var black_hole := _get_black_hole_controller()
	if skill_id.begins_with("bh_placeholder_"):
		st["locked"] = true
		st["level"] = 0
		st["max_level"] = 1
		st["can_buy"] = false
		st["cost_text"] = ""
		st["status_text"] = "Yakinda"
		return st
	if is_black_hole_skill:
		if black_hole == null:
			return st
		var bh_level := int(black_hole.call("get_black_hole_upgrade_level", skill_id))
		var bh_max_level := int(black_hole.call("get_black_hole_upgrade_max_level", skill_id))
		var bh_can_buy := bool(black_hole.call("can_buy_black_hole_upgrade", skill_id))
		var bh_cost := float(black_hole.call("get_black_hole_upgrade_cost", skill_id))
		st["locked"] = false
		st["level"] = bh_level
		st["max_level"] = bh_max_level
		st["can_buy"] = bh_can_buy
		st["cost_text"] = "%.0f BH" % bh_cost if bh_cost > 0.0 and bh_level < bh_max_level else ""
		st["status_text"] = _level_str(bh_level, bh_max_level, true)
		if skill_id == "bh_core":
			st["status_text"] = "Lv %d  |  Enerji %.0f" % [int(rs.blackhole_level), float(rs.blackhole_energy)]
		return st
	match skill_id:
		"energy_field":
			var unlocked: bool = bool(rs.attraction_skill_unlocked)
			st["locked"]      = false
			st["level"]       = 1 if unlocked else 0
			st["max_level"]   = 1
			st["can_buy"]     = not unlocked and bool(um.call("can_buy_energy_field_upgrade"))
			st["cost_text"]   = "3 Fe" if not unlocked else ""
			st["status_text"] = "ACILDI" if unlocked else "3 Demir"
		"mining":
			var lvl: int    = int(rs.mining_upgrade_level)
			var max_l: int  = UpgradeDefinitions.MAX_MINING_UPGRADE_LEVEL
			var pre: bool   = bool(rs.attraction_skill_unlocked)
			st["locked"]      = not pre
			st["level"]       = lvl
			st["max_level"]   = max_l
			st["can_buy"]     = pre and lvl < max_l and bool(um.call("can_buy_mining_upgrade"))
			st["cost_text"]   = _fmt_cost(um.call("get_mining_upgrade_cost_info", lvl)) if (pre and lvl < max_l) else ""
			st["status_text"] = _level_str(lvl, max_l, pre)
		"mining_speed":
			var lvl: int    = int(rs.mining_speed_upgrade_level)
			var max_l: int  = UpgradeDefinitions.MAX_MINING_SPEED_UPGRADE_LEVEL
			var pre: bool   = bool(rs.attraction_skill_unlocked)
			st["locked"]      = not pre
			st["level"]       = lvl
			st["max_level"]   = max_l
			st["can_buy"]     = pre and lvl < max_l and bool(um.call("can_buy_mining_speed_upgrade"))
			st["cost_text"]   = _fmt_cost(um.call("get_mining_upgrade_cost_info", lvl)) if (pre and lvl < max_l) else ""
			st["status_text"] = _level_str(lvl, max_l, pre)
		"damage_aura":
			var lvl: int    = int(rs.damage_aura_upgrade_level)
			var max_l: int  = UpgradeDefinitions.MAX_DAMAGE_AURA_UPGRADE_LEVEL
			var pre: bool   = bool(rs.attraction_skill_unlocked)
			st["locked"]      = not pre
			st["level"]       = lvl
			st["max_level"]   = max_l
			st["can_buy"]     = pre and lvl < max_l and bool(um.call("can_buy_damage_aura_upgrade"))
			st["cost_text"]   = _fmt_cost(um.call("get_upgrade_cost_info", lvl)) if (pre and lvl < max_l) else ""
			st["status_text"] = _level_str(lvl, max_l, pre)
		"drop_collection":
			var unlocked: bool = bool(rs.drop_collection_skill_unlocked)
			var pre: bool      = bool(rs.attraction_skill_unlocked)
			st["locked"]      = not pre
			st["level"]       = 1 if unlocked else 0
			st["max_level"]   = 1
			st["can_buy"]     = pre and not unlocked and bool(um.call("can_unlock_drop_collection_skill"))
			st["cost_text"]   = "3 Au" if (pre and not unlocked) else ""
			st["status_text"] = "ACILDI" if unlocked else ("3 Altin" if pre else "Kilitli")
		"orbit_mode":
			var lvl: int    = int(rs.orbit_mode_upgrade_level)
			var max_l: int  = UpgradeDefinitions.MAX_ORBIT_MODE_UPGRADE_LEVEL
			var pre: bool   = bool(rs.attraction_skill_unlocked)
			st["locked"]      = not pre
			st["level"]       = lvl
			st["max_level"]   = max_l
			st["can_buy"]     = pre and lvl < max_l and bool(um.call("can_buy_orbit_mode_upgrade"))
			st["cost_text"]   = _fmt_cost(um.call("get_orbit_mode_upgrade_cost_info", lvl)) if (pre and lvl < max_l) else ""
			st["status_text"] = _level_str(lvl, max_l, pre)
		"energy_orb_magnet":
			var lvl: int    = int(rs.energy_orb_magnet_upgrade_level)
			var max_l: int  = UpgradeDefinitions.MAX_ENERGY_ORB_MAGNET_UPGRADE_LEVEL
			var pre: bool   = bool(rs.attraction_skill_unlocked)
			var cur_radius: int = roundi(140.0 * pow(1.5, float(lvl)))
			st["locked"]      = not pre
			st["level"]       = lvl
			st["max_level"]   = max_l
			st["can_buy"]     = pre and lvl < max_l and bool(um.call("can_buy_energy_orb_magnet_upgrade"))
			st["cost_text"]   = _fmt_cost(um.call("get_upgrade_cost_info", lvl)) if (pre and lvl < max_l) else ""
			st["status_text"] = _level_str(lvl, max_l, pre) + "\nCekim: %d px" % cur_radius
		"crit_chance":
			var lvl: int    = int(rs.crit_chance_upgrade_level)
			var max_l: int  = UpgradeDefinitions.MAX_CRIT_CHANCE_UPGRADE_LEVEL
			var pre: bool   = bool(rs.attraction_skill_unlocked)
			var crit_percent: int = roundi(UpgradeEffects.get_current_crit_chance(rs) * 100.0)
			st["locked"]      = not pre
			st["level"]       = lvl
			st["max_level"]   = max_l
			st["can_buy"]     = pre and lvl < max_l and bool(um.call("can_buy_crit_chance_upgrade"))
			st["cost_text"]   = _fmt_cost(um.call("get_upgrade_cost_info", lvl)) if (pre and lvl < max_l) else ""
			st["status_text"] = _level_str(lvl, max_l, pre) + "\nKritik: %%%d" % crit_percent
		"laser_duration":
			var lvl: int    = int(rs.laser_duration_upgrade_level)
			var max_l: int  = UpgradeDefinitions.MAX_LASER_DURATION_UPGRADE_LEVEL
			var pre: bool   = bool(rs.attraction_skill_unlocked)
			var duration_bonus: int = roundi((UpgradeEffects.get_laser_duration_multiplier(rs) - 1.0) * 100.0)
			st["locked"]      = not pre
			st["level"]       = lvl
			st["max_level"]   = max_l
			st["can_buy"]     = pre and lvl < max_l and bool(um.call("can_buy_laser_duration_upgrade"))
			st["cost_text"]   = _fmt_cost(um.call("get_upgrade_cost_info", lvl)) if (pre and lvl < max_l) else ""
			st["status_text"] = _level_str(lvl, max_l, pre) + "\nSure: +%%%d" % duration_bonus
		"dual_laser":
			var lvl: int    = int(rs.dual_laser_upgrade_level)
			var max_l: int  = UpgradeDefinitions.MAX_DUAL_LASER_UPGRADE_LEVEL
			var pre: bool   = bool(rs.attraction_skill_unlocked)
			var laser_count: int = UpgradeEffects.get_simultaneous_cluster_laser_count(rs)
			st["locked"]      = not pre
			st["level"]       = lvl
			st["max_level"]   = max_l
			st["can_buy"]     = pre and lvl < max_l and bool(um.call("can_buy_dual_laser_upgrade"))
			st["cost_text"]   = _fmt_cost(um.call("get_upgrade_cost_info", lvl)) if (pre and lvl < max_l) else ""
			st["status_text"] = _level_str(lvl, max_l, pre) + "\nEszamanli: %d" % laser_count
	return st


func _level_str(lvl: int, max_l: int, pre: bool) -> String:
	if not pre:     return "Kilitli"
	if lvl >= max_l: return "Lv %d/%d  MAX" % [lvl, max_l]
	return "Lv %d/%d" % [lvl, max_l]


func _fmt_cost(info_v: Variant) -> String:
	if not (info_v is Dictionary):
		return "?"
	var info  := info_v as Dictionary
	var parts: Array[String] = []
	var iron:    int = int(info.get("iron",    0))
	var gold:    int = int(info.get("gold",    0))
	var crystal: int = int(info.get("crystal", 0))
	if iron    > 0: parts.append("%d Fe"  % iron)
	if gold    > 0: parts.append("%d Au"  % gold)
	if crystal > 0: parts.append("%d Kr"  % crystal)
	return " + ".join(parts) if not parts.is_empty() else "0"


func _is_bh_main_node(skill_id: String) -> bool:
	return BH_MAIN_NODE_IDS.has(skill_id)


func _get_black_hole_controller() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("black_hole")


func _update_resources(rs: Node) -> void:
	if _resource_panel == null:
		return
	if rs == null:
		_resource_panel.update_resources(-1, -1, -1)
		return
	_resource_panel.update_resources(int(rs.iron), int(rs.gold), int(rs.crystal))


# ── Developer mode ─────────────────────────────────────────────────────────────

func _update_dev_button(rs: Node, um: Node) -> void:
	if _dev_button == null:
		return
	if rs == null or um == null:
		_dev_button.disabled = true
		if _dev_label != null:
			_dev_label.text = ""
		return
	var is_on:      bool = bool(rs.developer_mode_enabled)
	var can_toggle: bool = is_on or bool(um.call("can_toggle_developer_mode"))
	_dev_button.disabled = not can_toggle
	_dev_button.text = "[G] Dev: %s" % ("ON ★" if is_on else "OFF")
	if _dev_label != null:
		_dev_label.text = (
			"+100k Fe/Au/Kr\nOlumsuz mod aktif" if is_on
			else "Gelistirici modu"
		)


func _on_dev_pressed() -> void:
	var um := get_node_or_null("/root/UpgradeManager")
	if um == null or not um.has_method("toggle_developer_mode"):
		return
	um.call("toggle_developer_mode")
	_update_all()
	_auto_save()


# ── Signals from skill nodes ───────────────────────────────────────────────────

func _on_hover_entered(skill_id: String) -> void:
	_hovered_skill_id = skill_id
	_update_galaxy_layout()
	if _tooltip == null:
		return
	var rs  := get_node_or_null("/root/RunState")
	var um  := get_node_or_null("/root/UpgradeManager")
	var cfg: Dictionary = SKILL_CONFIGS.get(skill_id, {})
	var st  := _build_state(skill_id, rs, um)
	_tooltip.show_for(skill_id, cfg, st,
		get_viewport().get_mouse_position(),
		get_viewport().get_visible_rect().size)


func _on_hover_exited() -> void:
	_hovered_skill_id = ""
	_update_galaxy_layout()
	_hide_tooltip()


func _on_skill_pressed(skill_id: String) -> void:
	var cfg: Dictionary = SKILL_CONFIGS.get(skill_id, {})
	if str(cfg.get("domain", "player")) == "black_hole":
		var black_hole := _get_black_hole_controller()
		if black_hole == null or not black_hole.has_method("buy_black_hole_upgrade"):
			return
		black_hole.call("buy_black_hole_upgrade", skill_id)
		_update_all()
		_auto_save()
		return
	var um := get_node_or_null("/root/UpgradeManager")
	if um == null:
		return
	var method: String     = cfg.get("buy_method", "")
	if method.is_empty() or not um.has_method(method):
		return
	um.call(method)
	_update_all()
	_auto_save()


func _on_skill_downgraded(skill_id: String) -> void:
	var cfg: Dictionary = SKILL_CONFIGS.get(skill_id, {})
	if str(cfg.get("domain", "player")) == "black_hole":
		var black_hole := _get_black_hole_controller()
		if black_hole == null or not black_hole.has_method("downgrade_black_hole_upgrade"):
			return
		black_hole.call("downgrade_black_hole_upgrade", skill_id)
		_update_all()
		_auto_save()
		return
	var um := get_node_or_null("/root/UpgradeManager")
	if um == null:
		return
	var method := ""
	match skill_id:
		"mining":          method = "downgrade_mining_upgrade"
		"mining_speed":    method = "downgrade_mining_speed_upgrade"
		"damage_aura":     method = "downgrade_damage_aura_upgrade"
		"energy_orb_magnet": method = "downgrade_energy_orb_magnet_upgrade"
		"crit_chance":     method = "downgrade_crit_chance_upgrade"
		"laser_duration":  method = "downgrade_laser_duration_upgrade"
		"dual_laser":      method = "downgrade_dual_laser_upgrade"
		"orbit_mode":      method = "downgrade_orbit_mode_upgrade"
	if method.is_empty() or not um.has_method(method):
		return
	um.call(method)
	_update_all()
	_auto_save()


func _hide_tooltip() -> void:
	if _tooltip != null:
		_tooltip.hide_tooltip()


# ── Auto-save ──────────────────────────────────────────────────────────────────

func _auto_save() -> void:
	var save_mgr    := get_node_or_null("/root/SaveManager")
	var player_node := get_node_or_null("../Player")
	var run_state   := get_node_or_null("/root/RunState")
	if save_mgr == null or not save_mgr.has_method("build_save_data"):
		return
	var data: Dictionary = save_mgr.call("build_save_data", player_node, run_state)
	var died_flag := false
	if save_mgr.has_method("save_exists") and bool(save_mgr.call("save_exists")):
		if save_mgr.has_method("read_save"):
			var existing: Dictionary = save_mgr.call("read_save")
			died_flag = bool(existing.get("died", false))
	data["died"] = died_flag
	if save_mgr.has_method("has_progress") and bool(save_mgr.call("has_progress", data)):
		if save_mgr.has_method("write_save"):
			save_mgr.call("write_save", data)
