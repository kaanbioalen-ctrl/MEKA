class_name BlackHoleController
extends Node2D

# ─── Sinyaller ───────────────────────────────────────────────────────────────
signal panel_open_requested
signal panel_close_requested
signal leveled_up(new_level: int)

# ─── Sabitler ────────────────────────────────────────────────────────────────
const MAX_LEVEL        := 30
const BASE_RADIUS      := 46.0    ## Level 1 boyutu (eski storm_radius 93'ün yarısı)
const MAX_RADIUS       := 1012.0  ## Level 30 boyutu (~22× başlangıç = ~22× büyüme)
## Oyuncu karadeliğin görünür alanı içindeyken çift tık ile paneli açabilir

## Her seviye için gereken enerji eşikleri (level N → N+1)
## Toplam level 30 için ~490 milyon enerji gerekir.
## Normal run başına ~1300 enerji → Level 5 kolay, Level 10 zor, Level 20+ çok run.
## Dev mode (2.6 M enerji) → yaklaşık Level 19'a ulaşır.
const LEVEL_THRESHOLDS: Array[float] = [
	100.0,        # 1→2   (ilk birkaç dakika)
	250.0,        # 2→3
	500.0,        # 3→4
	1_000.0,      # 4→5   (~1750 toplam — bir run'da rahat)
	2_000.0,      # 5→6
	3_500.0,      # 6→7
	6_000.0,      # 7→8
	10_000.0,     # 8→9
	17_000.0,     # 9→10  (~41k toplam — mükemmel run gerekir)
	28_000.0,     # 10→11
	46_000.0,     # 11→12
	75_000.0,     # 12→13
	120_000.0,    # 13→14
	195_000.0,    # 14→15
	315_000.0,    # 15→16
	510_000.0,    # 16→17
	820_000.0,    # 17→18
	1_330_000.0,  # 18→19
	2_150_000.0,  # 19→20
	3_480_000.0,  # 20→21
	5_630_000.0,  # 21→22
	9_100_000.0,  # 22→23
	14_700_000.0, # 23→24
	23_800_000.0, # 24→25
	38_500_000.0, # 25→26
	62_200_000.0, # 26→27
	100_500_000.0,# 27→28
	162_500_000.0,# 28→29
	262_700_000.0,# 29→30
]

# ─── Export ──────────────────────────────────────────────────────────────────
const BH_MAX_LEVELS: Dictionary = {
	"bh_core": 1,
	"bh_gravity_well": 4,
	"bh_event_horizon": 4,
	"bh_accretion": 4,
	"bh_singularity_drive": 3,
}

const BH_COSTS: Dictionary = {
	"bh_core": [0.0],
	"bh_gravity_well": [150.0, 320.0, 620.0, 1100.0],
	"bh_event_horizon": [180.0, 360.0, 700.0, 1250.0],
	"bh_accretion": [220.0, 480.0, 860.0, 1500.0],
	"bh_singularity_drive": [260.0, 540.0, 980.0],
}

const PICKUP_PULL_ZONE_MULT: float = 1.35
const PICKUP_FORCE_COLLECT_MULT: float = 0.72
const PICKUP_SHAKE_DECAY: float = 5.2
const PICKUP_SHAKE_MAX: float = 6.0

@export var move_speed:             float = 60.0
@export var pull_strength:          float = 60.0   ## Düşük tutuldu — asteroid yığılması önlenir
@export var pull_radius_mult:       float = 1.8
@export var max_pull_speed:         float = 140.0  ## Asteroidler yavaş çekilsin
@export var velocity_blend:         float = 2.0
@export var double_click_threshold: float = 0.40   ## Çift tık için izin verilen süre (sn)
## Görünür çapın dışında kaç piksel daha gidince yaklaşma mesafesi
@export var approach_margin:        float = 350.0

@export_group("Dönüşüm Oranları")
@export var iron_to_energy:    float = 1.0
@export var gold_to_energy:    float = 5.0
@export var crystal_to_energy: float = 20.0

# ─── İç Durum ────────────────────────────────────────────────────────────────
var _level:            int   = 1
var _current_radius:   float = BASE_RADIUS
var _energy_bar:       float = 0.0   ## Mevcut seviyede biriken enerji
var _spendable_energy: float = 0.0   ## Skill almak için harcanabilir enerji
var _total_converted:  float = 0.0   ## Tüm zamanlardaki toplam (istatistik)

var _player:          Node2D                = null
var _world_bounds:    Rect2                 = Rect2()
var _velocity:        Vector2               = Vector2.RIGHT * 60.0
var _last_click_t:    float                 = -999.0
var _rng:             RandomNumberGenerator = RandomNumberGenerator.new()

var _vortex_layer: Node2D = null
var _glow_layer:   Node2D = null
var _base_move_speed: float = 0.0
var _base_pull_strength: float = 0.0
var _base_pull_radius_mult: float = 0.0
var _base_max_pull_speed: float = 0.0
var _base_approach_margin: float = 0.0
var _base_iron_to_energy: float = 0.0
var _base_gold_to_energy: float = 0.0
var _base_crystal_to_energy: float = 0.0
var _pickup_shake_strength: float = 0.0
var _pickup_shake_seed: float = 0.0

# ─── Yaşam Döngüsü ───────────────────────────────────────────────────────────
func _ready() -> void:
	_rng.randomize()
	_pickup_shake_seed = _rng.randf_range(0.0, TAU)
	_cache_base_stats()
	_create_visual_layers()
	_update_radius()


func _process(delta: float) -> void:
	if _player == null:
		return
	# Oyuncu tam ortada (olay ufku içinde) ise karadelik sabitlenir
	if not _is_player_at_center():
		_move(delta)
	_apply_gravity(delta)
	_collect_pickups()
	_update_visuals(delta)

# ─── Genel API ───────────────────────────────────────────────────────────────
func configure(p_player: Node2D, world_bounds: Rect2) -> void:
	_player       = p_player
	_world_bounds = world_bounds
	add_to_group("black_hole")
	_load_from_run_state()
	_pick_start_position()
	_pick_start_velocity()


func convert_resources(iron: int, gold: int, crystal: int) -> float:
	"""Kaynakları enerjiye çevirir, RunState'ten düşer. Üretilen enerjiyi döndürür."""
	var rs := _run_state()
	if rs == null:
		return 0.0
	iron    = mini(iron,    int(rs.iron))
	gold    = mini(gold,    int(rs.gold))
	crystal = mini(crystal, int(rs.crystal))
	if iron == 0 and gold == 0 and crystal == 0:
		return 0.0
	var energy := iron * iron_to_energy + gold * gold_to_energy + crystal * crystal_to_energy
	rs.iron    -= iron
	rs.gold    -= gold
	rs.crystal -= crystal
	_add_energy(energy)
	return energy


func spend_energy(amount: float) -> bool:
	"""Skill almak için enerji harcar. Yetmezse false döner."""
	if _spendable_energy < amount:
		return false
	_spendable_energy -= amount
	_sync_to_run_state()
	return true


func get_black_hole_upgrade_level(skill_id: String) -> int:
	var rs := _run_state()
	match skill_id:
		"bh_core":
			return 1
		"bh_gravity_well":
			return int(rs.blackhole_gravity_well_level) if rs != null else 0
		"bh_event_horizon":
			return int(rs.blackhole_event_horizon_level) if rs != null else 0
		"bh_accretion":
			return int(rs.blackhole_accretion_level) if rs != null else 0
		"bh_singularity_drive":
			return int(rs.blackhole_singularity_drive_level) if rs != null else 0
	return 0


func get_black_hole_upgrade_max_level(skill_id: String) -> int:
	return int(BH_MAX_LEVELS.get(skill_id, 1))


func get_black_hole_upgrade_cost(skill_id: String) -> float:
	var costs_v: Variant = BH_COSTS.get(skill_id, [])
	if not (costs_v is Array):
		return 0.0
	var costs := costs_v as Array
	var level := get_black_hole_upgrade_level(skill_id)
	if skill_id == "bh_core":
		return 0.0
	if level < 0 or level >= costs.size():
		return 0.0
	return float(costs[level])


func can_buy_black_hole_upgrade(skill_id: String) -> bool:
	if skill_id == "bh_core":
		return false
	var level := get_black_hole_upgrade_level(skill_id)
	if level >= get_black_hole_upgrade_max_level(skill_id):
		return false
	return _spendable_energy >= get_black_hole_upgrade_cost(skill_id)


func buy_black_hole_upgrade(skill_id: String) -> bool:
	if not can_buy_black_hole_upgrade(skill_id):
		return false
	var cost := get_black_hole_upgrade_cost(skill_id)
	if not spend_energy(cost):
		return false
	var rs := _run_state()
	if rs == null:
		return false
	match skill_id:
		"bh_gravity_well":
			rs.blackhole_gravity_well_level += 1
		"bh_event_horizon":
			rs.blackhole_event_horizon_level += 1
		"bh_accretion":
			rs.blackhole_accretion_level += 1
		"bh_singularity_drive":
			rs.blackhole_singularity_drive_level += 1
		_:
			return false
	_apply_black_hole_skill_modifiers()
	_sync_to_run_state()
	return true


func downgrade_black_hole_upgrade(skill_id: String) -> bool:
	var rs := _run_state()
	if rs == null:
		return false
	var level := get_black_hole_upgrade_level(skill_id)
	if skill_id == "bh_core" or level <= 0:
		return false
	var refund_idx := level - 1
	var costs_v: Variant = BH_COSTS.get(skill_id, [])
	if not (costs_v is Array):
		return false
	var costs := costs_v as Array
	if refund_idx < 0 or refund_idx >= costs.size():
		return false
	_spendable_energy += float(costs[refund_idx]) * 0.70
	match skill_id:
		"bh_gravity_well":
			rs.blackhole_gravity_well_level -= 1
		"bh_event_horizon":
			rs.blackhole_event_horizon_level -= 1
		"bh_accretion":
			rs.blackhole_accretion_level -= 1
		"bh_singularity_drive":
			rs.blackhole_singularity_drive_level -= 1
		_:
			return false
	_apply_black_hole_skill_modifiers()
	_sync_to_run_state()
	return true

# ─── Getter'lar ──────────────────────────────────────────────────────────────
func get_level()            -> int:   return _level
func get_spendable_energy() -> float: return _spendable_energy
func get_radius()           -> float: return _current_radius
func get_collect_radius()   -> float: return _current_radius * 0.48
func get_iron_rate()        -> float: return iron_to_energy
func get_gold_rate()        -> float: return gold_to_energy
func get_crystal_rate()     -> float: return crystal_to_energy


func add_iron(amount: int) -> void:
	if amount <= 0:
		return
	_grant_player_resource("iron", amount)
	_trigger_pickup_anger()


func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	_grant_player_resource("gold", amount)
	_trigger_pickup_anger()


func add_crystal(amount: int) -> void:
	if amount <= 0:
		return
	_grant_player_resource("crystal", amount)
	_trigger_pickup_anger()


func add_uranium(amount: int) -> void:
	if amount <= 0:
		return
	_grant_player_resource("uranium", amount)
	_trigger_pickup_anger()


func add_energy_percent(percent: float) -> void:
	if percent <= 0.0:
		return
	var player_node := _get_player_target()
	if player_node != null and player_node.has_method("add_energy_percent"):
		player_node.call("add_energy_percent", percent)
		_trigger_pickup_anger()


func _grant_player_resource(kind: String, amount: int) -> void:
	if amount <= 0:
		return
	var rs := _run_state()
	var player_node := _get_player_target()
	match kind:
		"iron":
			if player_node != null and player_node.has_method("add_iron"):
				player_node.call("add_iron", amount)
			elif rs != null:
				rs.iron = int(rs.iron) + amount
		"gold":
			if player_node != null and player_node.has_method("add_gold"):
				player_node.call("add_gold", amount)
			elif rs != null:
				rs.gold = int(rs.gold) + amount
		"crystal":
			if player_node != null and player_node.has_method("add_crystal"):
				player_node.call("add_crystal", amount)
			elif rs != null:
				rs.crystal = int(rs.crystal) + amount
		"uranium":
			if player_node != null and player_node.has_method("add_uranium"):
				player_node.call("add_uranium", amount)
			elif rs != null:
				rs.uranium = int(rs.uranium) + amount


func _get_player_target() -> Node2D:
	if _player != null and is_instance_valid(_player):
		return _player
	var tree := get_tree()
	if tree == null:
		return null
	var maybe_player := tree.get_first_node_in_group("player")
	if maybe_player is Node2D:
		return maybe_player as Node2D
	maybe_player = tree.get_first_node_in_group("Player")
	if maybe_player is Node2D:
		return maybe_player as Node2D
	return null


func _trigger_pickup_anger() -> void:
	_pickup_shake_strength = minf(PICKUP_SHAKE_MAX, _pickup_shake_strength + 1.2)


func get_energy_bar_ratio() -> float:
	if _level >= MAX_LEVEL:
		return 1.0
	var thr := _threshold_for(_level)
	return clampf(_energy_bar / thr, 0.0, 1.0) if thr > 0.0 else 1.0


func get_energy_bar_text() -> String:
	if _level >= MAX_LEVEL:
		return "MAX SEVİYE"
	return "%d / %d" % [int(_energy_bar), int(_threshold_for(_level))]


func reload_from_run_state() -> void:
	_load_from_run_state()


func is_player_in_interaction_zone() -> bool:
	## Karadelik + approach_margin mesafesindeyse çift tık açılır
	if _player == null:
		return false
	var zone := _current_radius + approach_margin
	return global_position.distance_to(_player.global_position) <= zone


func _is_player_at_center() -> bool:
	## Oyuncu olay ufku içindeyse (çok yakın) → karadelik donsun
	if _player == null:
		return false
	var event_horizon := _current_radius * 0.40
	return global_position.distance_to(_player.global_position) <= event_horizon

# ─── Özel: Çift Tık Etkileşimi ───────────────────────────────────────────────
## _input kullanıyoruz; _unhandled_input HUD CanvasLayer tarafından yutulabilir.
func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_handle_click()


func _handle_click() -> void:
	var now        := Time.get_ticks_msec() / 1000.0
	var since_last := now - _last_click_t

	if since_last <= double_click_threshold:
		_last_click_t = -999.0
		if is_player_in_interaction_zone():
			panel_open_requested.emit()
			get_viewport().set_input_as_handled()
	else:
		_last_click_t = now

# ─── Özel: Enerji & Seviye ───────────────────────────────────────────────────
func _add_energy(amount: float) -> void:
	_spendable_energy += amount
	_total_converted  += amount
	# Max level'da bar dolmaya devam etmesin
	if _level < MAX_LEVEL:
		_energy_bar += amount
	_sync_to_run_state()
	_check_level_up()


func _check_level_up() -> void:
	while _level < MAX_LEVEL:
		var thr := _threshold_for(_level)
		if _energy_bar < thr:
			break
		_energy_bar -= thr
		_level      += 1
		_update_radius()
		_sync_to_run_state()
		leveled_up.emit(_level)


func _threshold_for(lvl: int) -> float:
	var idx := lvl - 1
	if idx < 0 or idx >= LEVEL_THRESHOLDS.size():
		return 9_999_999.0
	return LEVEL_THRESHOLDS[idx]


func _sync_to_run_state() -> void:
	var rs := _run_state()
	if rs == null:
		return
	rs.blackhole_level        = _level
	rs.blackhole_progress     = _energy_bar
	rs.blackhole_energy       = _spendable_energy
	rs.blackhole_total_energy = _total_converted
	rs.blackhole_gravity_well_level = get_black_hole_upgrade_level("bh_gravity_well")
	rs.blackhole_event_horizon_level = get_black_hole_upgrade_level("bh_event_horizon")
	rs.blackhole_accretion_level = get_black_hole_upgrade_level("bh_accretion")
	rs.blackhole_singularity_drive_level = get_black_hole_upgrade_level("bh_singularity_drive")


func _cache_base_stats() -> void:
	_base_move_speed = move_speed
	_base_pull_strength = pull_strength
	_base_pull_radius_mult = pull_radius_mult
	_base_max_pull_speed = max_pull_speed
	_base_approach_margin = approach_margin
	_base_iron_to_energy = iron_to_energy
	_base_gold_to_energy = gold_to_energy
	_base_crystal_to_energy = crystal_to_energy


func _load_from_run_state() -> void:
	var rs := _run_state()
	if rs != null:
		_level = maxi(1, int(rs.blackhole_level))
		_energy_bar = maxf(0.0, float(rs.blackhole_progress))
		_spendable_energy = maxf(0.0, float(rs.blackhole_energy))
		_total_converted = maxf(_spendable_energy, float(rs.blackhole_total_energy))
	_apply_black_hole_skill_modifiers()
	_update_radius()


func _apply_black_hole_skill_modifiers() -> void:
	var rs := _run_state()
	var grav_lvl := int(rs.blackhole_gravity_well_level) if rs != null else 0
	var horizon_lvl := int(rs.blackhole_event_horizon_level) if rs != null else 0
	var accretion_lvl := int(rs.blackhole_accretion_level) if rs != null else 0
	var drive_lvl := int(rs.blackhole_singularity_drive_level) if rs != null else 0
	pull_strength = _base_pull_strength + grav_lvl * 48.0
	pull_radius_mult = _base_pull_radius_mult + horizon_lvl * 0.22
	approach_margin = _base_approach_margin + horizon_lvl * 65.0
	move_speed = _base_move_speed + drive_lvl * 16.0
	max_pull_speed = _base_max_pull_speed + drive_lvl * 24.0
	iron_to_energy = _base_iron_to_energy * (1.0 + accretion_lvl * 0.20)
	gold_to_energy = _base_gold_to_energy * (1.0 + accretion_lvl * 0.24)
	crystal_to_energy = _base_crystal_to_energy * (1.0 + accretion_lvl * 0.30)


func _run_state() -> Node:
	return get_node_or_null("/root/RunState")

# ─── Özel: Hareket ───────────────────────────────────────────────────────────
func _pick_start_position() -> void:
	if _world_bounds.size == Vector2.ZERO:
		return
	global_position = _world_bounds.get_center() + Vector2(
		_rng.randf_range(-_world_bounds.size.x * 0.25, _world_bounds.size.x * 0.25),
		_rng.randf_range(-_world_bounds.size.y * 0.25, _world_bounds.size.y * 0.25)
	)


func _pick_start_velocity() -> void:
	var angle := _rng.randf_range(0.0, TAU)
	_velocity  = Vector2(cos(angle), sin(angle)) * move_speed


func _move(delta: float) -> void:
	if _world_bounds.size == Vector2.ZERO:
		return
	global_position += _velocity * delta
	var margin := _current_radius * 0.4
	var bounds := _world_bounds.grow(-margin)
	if global_position.x < bounds.position.x or global_position.x > bounds.end.x:
		_velocity.x      = -_velocity.x
		global_position.x = clampf(global_position.x, bounds.position.x, bounds.end.x)
	if global_position.y < bounds.position.y or global_position.y > bounds.end.y:
		_velocity.y      = -_velocity.y
		global_position.y = clampf(global_position.y, bounds.position.y, bounds.end.y)

# ─── Özel: Yerçekimi ─────────────────────────────────────────────────────────
func _apply_gravity(delta: float) -> void:
	var pull_zone     := _current_radius * pull_radius_mult
	var event_horizon := _current_radius * 0.40  ## Görsel olay ufkuyla aynı

	for ast in get_tree().get_nodes_in_group("asteroid"):
		if not is_instance_valid(ast):
			continue
		if not ast is Node2D:
			continue
		var ast_node := ast as Node2D
		var dist := global_position.distance_to(ast_node.global_position)

		# Olay ufkuna giren asteroidi normal ölüm yoluyla yok et
		# (queue_free direkt çağrılırsa spawner habersiz kalır → crash)
		if dist <= event_horizon:
			if ast.has_method("take_mining_damage"):
				ast.call("take_mining_damage", 99999.0)
			continue

		if dist > pull_zone:
			continue

		# Doğru imza: target_pos, field_radius, pull_strength, min_pull,
		#             max_pull_speed, velocity_blend, side_damping,
		#             commit_distance, delta
		if ast.has_method("apply_storm_pull"):
			ast.call("apply_storm_pull",
				global_position,   ## target_pos
				pull_zone,         ## field_radius
				pull_strength,     ## pull_strength
				5.0,               ## storm_min_pull
				max_pull_speed,    ## storm_max_pull_speed
				velocity_blend,    ## storm_velocity_blend
				1.0,               ## storm_side_damping
				0.0,               ## storm_commit_distance
				delta              ## delta
			)

# ─── Özel: Görsel Katmanlar ──────────────────────────────────────────────────
func _collect_pickups() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var pull_zone := maxf(_current_radius * PICKUP_PULL_ZONE_MULT, get_collect_radius() + 120.0)
	var collect_radius := get_collect_radius() * PICKUP_FORCE_COLLECT_MULT
	for pickup in tree.get_nodes_in_group("energy_pickup"):
		if not (pickup is Node2D):
			continue
		var pickup_node := pickup as Node2D
		if not is_instance_valid(pickup_node):
			continue
		var dist := global_position.distance_to(pickup_node.global_position)
		if dist > pull_zone:
			continue
		if pickup.has_method("set_collect_target"):
			pickup.call("set_collect_target", self)
		if dist <= collect_radius and pickup.has_method("force_collect"):
			pickup.call("force_collect")


func _update_radius() -> void:
	if _level >= MAX_LEVEL:
		_current_radius = MAX_RADIUS
	else:
		var t := float(_level - 1) / float(MAX_LEVEL - 1)
		_current_radius = BASE_RADIUS * pow(MAX_RADIUS / BASE_RADIUS, t)
	if _vortex_layer and _vortex_layer.has_method("set_radius"):
		_vortex_layer.call("set_radius", _current_radius)
	if _glow_layer and _glow_layer.has_method("set_radius"):
		_glow_layer.call("set_radius", _current_radius)


func _create_visual_layers() -> void:
	_glow_layer          = BlackHoleGlowLayer.new()
	_glow_layer.z_index  = -2
	add_child(_glow_layer)

	_vortex_layer         = BlackHoleVortexLayer.new()
	_vortex_layer.z_index = -1
	add_child(_vortex_layer)


func _update_visuals(delta: float) -> void:
	_pickup_shake_strength = maxf(0.0, _pickup_shake_strength - delta * PICKUP_SHAKE_DECAY)
	var shake_offset := Vector2.ZERO
	if _pickup_shake_strength > 0.01:
		var t := Time.get_ticks_msec() / 1000.0
		shake_offset = Vector2(
			sin((t * 32.0) + _pickup_shake_seed),
			cos((t * 37.0) + _pickup_shake_seed * 1.7)
		) * _pickup_shake_strength
	if _vortex_layer != null:
		_vortex_layer.position = shake_offset
	if _glow_layer != null:
		_glow_layer.position = shake_offset * 0.55
	var level_t := float(_level - 1) / float(MAX_LEVEL - 1)
	if _vortex_layer and _vortex_layer.has_method("tick"):
		_vortex_layer.call("tick", delta, _current_radius, level_t, get_energy_bar_ratio())
	if _glow_layer and _glow_layer.has_method("tick"):
		_glow_layer.call("tick", delta, _current_radius, level_t)
