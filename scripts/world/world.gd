extends Node2D

const WorldUIFlow        = preload("res://scripts/world/world_ui_flow.gd")
const PORTAL_SCENE      := preload("res://scenes/world/portal.tscn")
const DEATH_SCREEN_SCRIPT    = preload("res://scripts/ui/death_screen.gd")
const MAIN_MENU_SCRIPT       = preload("res://scripts/ui/main_menu_screen.gd")
const PAUSE_SCREEN_SCRIPT    = preload("res://scripts/ui/pause_screen.gd")
const OCAK_SCREEN_SCRIPT     = preload("res://scripts/ui/ocak_screen.gd")
const WORLD_ONE_SCENE := "res://scenes/world/world.tscn"
const WORLD_TWO_SCENE   := "res://scenes/world/world2.tscn"
const WORLD_THREE_SCENE := "res://scenes/world/world3.tscn"
const WORLD_TEST_SCENE  := "res://scenes/world/world_test.tscn"
const WORLD_TEST_PLAYER_SPEED_MULTIPLIER: float = 3.0
const WORLD_TWO_GATE_FIRST_RELOCATE_DELAY: float = 30.0
const WORLD_TWO_GATE_RELOCATE_INTERVAL: float = 180.0
const WORLD_TWO_GATE_WORLD_MARGIN: float = 260.0

@export var draw_debug_grid: bool = false
@onready var zone_manager: ZoneManager = $ZoneManager
@onready var asteroid_spawner: Node2D = $AsteroidSpawner
@onready var worm_spawner: Node2D = $WormSpawner
@onready var black_hole: Node2D = get_node_or_null("BlackHole") as Node2D
@onready var player: Node = $Player
@onready var hud: CanvasLayer = $HUD
@onready var death_screen: CanvasLayer = $DeathScreen
@onready var upgrade_screen: CanvasLayer = $UpgradeScreen
@onready var main_menu: CanvasLayer = $MainMenu
@onready var pause_screen: CanvasLayer = $PauseScreen
@onready var ocak_screen: CanvasLayer = $OcakScreen

const EnemyDirectorScript = preload("res://scripts/enemies/enemy_director.gd")

var _ui_flow: WorldUIFlow = WorldUIFlow.new()
var _restart_in_progress: bool = false
var _enemy_director: Node = null
var _black_hole_panel: BlackHolePanel = null
var _portal: Node2D = null
var _portal_relocate_timer: float = 0.0
var _portal_first_relocation_done: bool = false
var _death_screen_ctrl: Node = null
var _main_menu_ctrl   : Node = null
var _pause_screen_ctrl: Node = null
var _ocak_screen_ctrl : Node = null


func _ready() -> void:
	_restart_in_progress = false
	_setup_death_screen_ctrl()
	_setup_main_menu_ctrl()
	_setup_pause_screen_ctrl()
	_setup_ocak_screen_ctrl()
	_ui_flow.setup(death_screen, upgrade_screen, main_menu, hud, pause_screen, ocak_screen)
	_reset_runtime_state()
	var viewport_size := get_viewport_rect().size
	zone_manager.rebuild(viewport_size)
	_apply_world_bounds_to_player()
	_center_player()
	_apply_test_map_player_speed()
	_configure_asteroid_spawner(viewport_size)
	_configure_worm_spawner(viewport_size)
	_configure_enemy_director()
	_spawn_portal_at_start()
	_spawn_test_portal()
	_configure_black_hole()
	_connect_player_signals()
	_hide_all_overlay_ui()

	var run_state := get_node_or_null("/root/RunState")
	if run_state != null and bool(run_state.get("coming_from_portal")):
		run_state.set("coming_from_portal", false)
		_apply_run_state_to_scene()
		run_state.active = true
	elif run_state != null and bool(run_state.auto_load_save):
		run_state.auto_load_save = false
		_init_run_state_for_retry()
		var save_mgr := get_node_or_null("/root/SaveManager")
		if save_mgr != null and save_mgr.save_exists():
			var save_data: Dictionary = save_mgr.read_save()
			_apply_save_to_run(save_data)
		if run_state != null:
			run_state.active = true
	else:
		_reset_run_state()
		_open_main_menu()

	print(
		"World ready: %sx%s screens (%s total), screen=%s, world=%s"
		% [
			ZoneManager.GRID_WIDTH,
			ZoneManager.GRID_HEIGHT,
			zone_manager.get_total_screens(),
			viewport_size,
			zone_manager.world_size
		]
	)
	queue_redraw()


func _process(_delta: float) -> void:
	if _restart_in_progress:
		return
	_update_world_two_gate_timer(_delta)
	_update_run_state_zone()


func _input(event: InputEvent) -> void:
	if _restart_in_progress:
		return
	if _ui_flow.is_menu():
		return
	if _ui_flow.is_upgrade():
		return
	# NOTE: Wheel input is allowed even when upgrade screen is open.
	# UpgradeScreen (CanvasLayer) is immune to Camera2D zoom, so world zoom
	# does not affect skill panel text or UI elements.
	# Upgrade screen detects the wheel separately to animate star background.
	if not (event is InputEventMouseButton):
		return
	var button_event := event as InputEventMouseButton
	if not button_event.pressed:
		return

	var zoom_direction := 0
	if button_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom_direction = -1
	elif button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_direction = 1
	if zoom_direction == 0:
		return

	var player_node := get_node_or_null("Player")
	if player_node != null and player_node.has_method("apply_camera_zoom_step"):
		player_node.call("apply_camera_zoom_step", zoom_direction)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	if not event.is_pressed() or event.is_echo():
		return
	if _ui_flow.is_menu():
		return

	# ESC — pause / ocak aç/kapat
	if event.keycode == KEY_ESCAPE:
		if _ui_flow.is_ocak():
			_on_ocak_close_pressed()
		elif _ui_flow.is_paused():
			_close_pause()
		elif _ui_flow.can_pause():
			_open_pause()
		get_viewport().set_input_as_handled()
		return

	if event.keycode != KEY_K:
		return
	if not _can_toggle_upgrade_with_keyboard():
		return

	if _is_upgrade_screen_visible():
		_close_upgrade_overlay()
	else:
		_open_upgrade_overlay()

	get_viewport().set_input_as_handled()


func _draw() -> void:
	if not draw_debug_grid:
		return

	var color := Color(0.1, 0.9, 1.0, 0.5)
	for zone in zone_manager.zones:
		var rect: Rect2 = zone["rect"]
		draw_rect(rect, color, false, 2.0)


func _apply_world_bounds_to_player() -> void:
	var player_node := get_node_or_null("Player")
	if player_node == null:
		return
	if player_node.has_method("set_movement_bounds"):
		player_node.call("set_movement_bounds", Rect2(Vector2.ZERO, zone_manager.world_size))


func _center_player() -> void:
	var player_node := get_node_or_null("Player") as Node2D
	if player_node == null:
		return
	player_node.global_position = zone_manager.world_size * 0.5
	if player_node.get("accumulated_position") != null:
		player_node.accumulated_position = player_node.global_position
	if player_node.has_method("snap_interpolation_to_current_position"):
		player_node.call("snap_interpolation_to_current_position")


func _apply_test_map_player_speed() -> void:
	if String(scene_file_path) != WORLD_TEST_SCENE:
		return
	var player_node := get_node_or_null("Player")
	if player_node == null:
		return
	if player_node.get("min_speed") != null:
		player_node.set("min_speed", float(player_node.get("min_speed")) * WORLD_TEST_PLAYER_SPEED_MULTIPLIER)
	if player_node.get("max_speed") != null:
		player_node.set("max_speed", float(player_node.get("max_speed")) * WORLD_TEST_PLAYER_SPEED_MULTIPLIER)


func _configure_asteroid_spawner(viewport_size: Vector2) -> void:
	if asteroid_spawner == null:
		return
	var player_node := get_node_or_null("Player") as Node2D
	if player_node == null:
		return
	if asteroid_spawner.has_method("configure"):
		asteroid_spawner.call(
			"configure",
			player_node,
			Rect2(Vector2.ZERO, zone_manager.world_size),
			viewport_size
		)


func _configure_worm_spawner(viewport_size: Vector2) -> void:
	if worm_spawner == null:
		return
	var current_path := String(scene_file_path)
	if current_path == WORLD_ONE_SCENE or current_path == WORLD_TEST_SCENE:
		worm_spawner.set_process(false)
		worm_spawner.set_physics_process(false)
		worm_spawner.visible = false
		return
	var player_node := get_node_or_null("Player") as Node2D
	if player_node == null:
		return
	if worm_spawner.has_method("configure"):
		worm_spawner.call(
			"configure",
			player_node,
			Rect2(Vector2.ZERO, zone_manager.world_size),
			viewport_size
		)


func _configure_enemy_director() -> void:
	if _enemy_director != null:
		_enemy_director.queue_free()
	_enemy_director = EnemyDirectorScript.new()
	add_child(_enemy_director)
	if _enemy_director.has_method("configure"):
		_enemy_director.call("configure", worm_spawner)


func _spawn_portal_at_start() -> void:
	if PORTAL_SCENE == null:
		return
	# Portal zaten sahnede varsa (restart vb.) tekrar açma.
	# Sadece ana portal (_portal) kontrol edilir; kırmızı test portali ayrı takip edilir.
	if _portal != null and is_instance_valid(_portal):
		return
	var p := PORTAL_SCENE.instantiate() as Node2D
	if p == null:
		return
	if p.get("target_scene") != null:
		p.set("target_scene", _get_portal_target_scene())
	if p.get("portal_color") != null:
		p.set("portal_color", _get_portal_color())
	var world_center := zone_manager.world_size * 0.5
	p.global_position = world_center + Vector2(420.0, 0.0)
	add_child(p)
	_portal = p


func _spawn_test_portal() -> void:
	if String(scene_file_path) != WORLD_ONE_SCENE:
		return
	if PORTAL_SCENE == null:
		return
	var p := PORTAL_SCENE.instantiate() as Node2D
	if p == null:
		return
	if p.get("target_scene") != null:
		p.set("target_scene", WORLD_TEST_SCENE)
	if p.get("portal_color") != null:
		p.set("portal_color", Color(1.0, 0.08, 0.05))
	if p.get("label_text") != null:
		p.set("label_text", "TEST")
	var world_center := zone_manager.world_size * 0.5
	p.global_position = world_center + Vector2(-420.0, 0.0)
	add_child(p)


func _get_portal_target_scene() -> String:
	var current_path := String(scene_file_path)
	if current_path == WORLD_TEST_SCENE:
		return WORLD_ONE_SCENE
	if current_path == WORLD_THREE_SCENE:
		return WORLD_ONE_SCENE
	if current_path == WORLD_TWO_SCENE:
		return WORLD_THREE_SCENE
	return WORLD_TWO_SCENE


func _get_portal_color() -> Color:
	var current_path := String(scene_file_path)
	if current_path == WORLD_TEST_SCENE:
		return Color(1.0, 0.08, 0.05)
	return Color(0.18, 0.72, 1.0)


func _update_world_two_gate_timer(delta: float) -> void:
	if String(scene_file_path) != WORLD_ONE_SCENE:
		return
	if _portal == null or not is_instance_valid(_portal):
		return
	if String(_portal.get("target_scene")) != WORLD_TWO_SCENE:
		return
	_portal_relocate_timer += delta
	var required_delay := WORLD_TWO_GATE_RELOCATE_INTERVAL if _portal_first_relocation_done else WORLD_TWO_GATE_FIRST_RELOCATE_DELAY
	if _portal_relocate_timer < required_delay:
		return
	_portal_relocate_timer = 0.0
	_portal_first_relocation_done = true
	_relocate_world_two_gate()


func _relocate_world_two_gate() -> void:
	if _portal == null or not is_instance_valid(_portal):
		return
	if not _portal.has_method("respawn_at"):
		return
	_portal.call("respawn_at", _get_random_portal_position())


func _get_random_portal_position() -> Vector2:
	var margin := WORLD_TWO_GATE_WORLD_MARGIN
	var min_x := margin
	var max_x := maxf(min_x, zone_manager.world_size.x - margin)
	var min_y := margin
	var max_y := maxf(min_y, zone_manager.world_size.y - margin)
	var candidate := Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))
	var player_node := get_node_or_null("Player") as Node2D
	if player_node == null:
		return candidate
	var attempts := 0
	while attempts < 8 and candidate.distance_to(player_node.global_position) < 520.0:
		candidate = Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))
		attempts += 1
	return candidate


func _configure_black_hole() -> void:
	if black_hole == null:
		return
	var player_node := get_node_or_null("Player") as Node2D
	if player_node == null:
		return
	if black_hole.has_method("configure"):
		black_hole.call("configure", player_node, Rect2(Vector2.ZERO, zone_manager.world_size))
	# Panel oluştur ve sinyali bağla
	_black_hole_panel = BlackHolePanel.new()
	add_child(_black_hole_panel)
	_black_hole_panel.closed.connect(_on_black_hole_panel_closed)
	if black_hole.has_signal("panel_open_requested"):
		black_hole.connect("panel_open_requested", _on_black_hole_panel_requested)
	if black_hole.has_signal("leveled_up"):
		black_hole.connect("leveled_up", _on_black_hole_leveled_up)


func _on_black_hole_panel_requested() -> void:
	if _black_hole_panel == null or _ui_flow.is_menu():
		return
	if not _black_hole_panel.visible:
		_black_hole_panel.open(black_hole)


func _on_black_hole_panel_closed() -> void:
	pass


func _on_black_hole_leveled_up(new_level: int) -> void:
	print("Karadelik seviye atladı: ", new_level)


func _setup_main_menu_ctrl() -> void:
	_main_menu_ctrl = MAIN_MENU_SCRIPT.new()
	main_menu.add_child(_main_menu_ctrl)
	_main_menu_ctrl.continue_pressed.connect(_on_main_menu_continue_pressed)
	_main_menu_ctrl.new_game_pressed.connect(_on_main_menu_new_game_pressed)
	_main_menu_ctrl.settings_pressed.connect(_on_main_menu_settings_pressed)
	_main_menu_ctrl.quit_pressed.connect(_on_main_menu_quit_pressed)


func _setup_pause_screen_ctrl() -> void:
	if pause_screen == null:
		return
	pause_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_screen_ctrl = PAUSE_SCREEN_SCRIPT.new()
	pause_screen.add_child(_pause_screen_ctrl)
	_pause_screen_ctrl.resume_pressed.connect(_on_pause_resume_pressed)
	_pause_screen_ctrl.main_menu_pressed.connect(_on_pause_main_menu_pressed)
	_pause_screen_ctrl.ocak_pressed.connect(_on_pause_ocak_pressed)


func _setup_ocak_screen_ctrl() -> void:
	if ocak_screen == null:
		return
	ocak_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	_ocak_screen_ctrl = OCAK_SCREEN_SCRIPT.new()
	ocak_screen.add_child(_ocak_screen_ctrl)
	_ocak_screen_ctrl.close_pressed.connect(_on_ocak_close_pressed)


func _setup_death_screen_ctrl() -> void:
	if death_screen == null:
		return
	death_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	_death_screen_ctrl = DEATH_SCREEN_SCRIPT.new()
	death_screen.add_child(_death_screen_ctrl)
	_death_screen_ctrl.retry_pressed.connect(_on_retry_button_pressed)
	_death_screen_ctrl.upgrade_pressed.connect(_on_upgrade_button_pressed)
	_death_screen_ctrl.quit_pressed.connect(_on_death_screen_quit_pressed)


func _connect_player_signals() -> void:
	var player_node := get_node_or_null("Player")
	player = player_node
	if player_node == null:
		return
	if player_node.has_signal("died"):
		var on_died := Callable(self, "_on_player_died")
		if not player_node.is_connected("died", on_died):
			player_node.connect("died", on_died)


func _on_player_died() -> void:
	var run_state := get_node_or_null("/root/RunState")
	if run_state != null:
		run_state.active = false
	_try_save_progress_on_death()
	if _death_screen_ctrl != null:
		_death_screen_ctrl.call("populate", run_state)
	_trigger_game_over_once()


func _on_retry_button_pressed() -> void:
	_restart_run()


func _on_upgrade_button_pressed() -> void:
	if not _ui_flow.is_game_over():
		return
	_open_upgrade_overlay(true)


func _on_upgrade_screen_close_requested() -> void:
	_ui_flow.handle_upgrade_close_requested(_restart_in_progress)


func _on_main_menu_continue_pressed() -> void:
	var save_mgr := get_node_or_null("/root/SaveManager")
	if save_mgr != null and save_mgr.save_exists():
		var save_data: Dictionary = save_mgr.read_save()
		_apply_save_to_run(save_data)
	_close_main_menu()


func _on_main_menu_new_game_pressed() -> void:
	var save_mgr := get_node_or_null("/root/SaveManager")
	if save_mgr != null:
		save_mgr.delete_save()
	_close_main_menu()


func _on_main_menu_settings_pressed() -> void:
	if _main_menu_ctrl != null:
		_main_menu_ctrl.call("toggle_settings_hint")


func _on_main_menu_quit_pressed() -> void:
	_try_save_progress()
	get_tree().quit()


func _reset_run_state() -> void:
	var run_state := get_node_or_null("/root/RunState")
	if run_state == null:
		return
	run_state.reset_run()
	run_state.set_total_zones(zone_manager.get_total_screens())
	_update_run_state_zone()


func _init_run_state_for_retry() -> void:
	var run_state := get_node_or_null("/root/RunState")
	if run_state == null:
		return
	run_state.run_time = 0.0
	run_state.active = false
	run_state.set_total_zones(zone_manager.get_total_screens())
	_update_run_state_zone()


func _update_run_state_zone() -> void:
	var run_state := get_node_or_null("/root/RunState")
	if run_state == null:
		return
	var player_node := get_node_or_null("Player") as Node2D
	if player_node == null:
		return
	var zone := zone_manager.get_zone_at_position(player_node.global_position)
	if zone.is_empty():
		return
	run_state.set_current_zone(zone["id"], zone["grid"])


func _can_toggle_upgrade_with_keyboard() -> bool:
	var player_node := get_node_or_null("Player")
	return _ui_flow.can_toggle_upgrade_with_keyboard(_restart_in_progress, player_node != null)


func _is_death_screen_visible() -> bool:
	return _ui_flow.is_death_screen_visible()


func _is_upgrade_screen_visible() -> bool:
	return _ui_flow.is_upgrade_screen_visible()


func _trigger_game_over_once() -> void:
	_ui_flow.trigger_game_over_once(_restart_in_progress)


func _restart_run() -> void:
	if _restart_in_progress:
		return
	_restart_in_progress = true
	_ui_flow.flow_state = WorldUIFlow.RunFlowState.RESTARTING
	_ui_flow.game_over_triggered = false
	_disable_game_over_buttons()
	_reset_tree_runtime_state()
	_hide_all_overlay_ui()
	set_process_input(false)
	set_process_unhandled_input(false)
	var run_state := get_node_or_null("/root/RunState")
	if run_state != null:
		run_state.auto_load_save = true
	call_deferred("_perform_scene_reload")


func _perform_scene_reload() -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.change_scene_to_file(WORLD_ONE_SCENE)


func _reset_runtime_state() -> void:
	_ui_flow.reset_runtime_state()
	_reset_tree_runtime_state()
	set_process_input(true)
	set_process_unhandled_input(true)


func _reset_tree_runtime_state() -> void:
	var tree := get_tree()
	if tree != null:
		tree.paused = false
	Engine.time_scale = 1.0


func _hide_all_overlay_ui() -> void:
	_ui_flow.hide_all_overlay_ui()
	_disable_game_over_buttons(false)


func _open_upgrade_overlay(allow_game_over: bool = false) -> void:
	_ui_flow.open_upgrade_overlay(_restart_in_progress, allow_game_over)


func _close_upgrade_overlay() -> void:
	_ui_flow.close_upgrade_overlay()


func _on_death_screen_quit_pressed() -> void:
	get_tree().quit()


func _disable_game_over_buttons(disabled: bool = true) -> void:
	if _death_screen_ctrl != null:
		_death_screen_ctrl.call("set_buttons_disabled", disabled)


func _open_main_menu() -> void:
	_ui_flow.open_main_menu()
	_update_continue_button()


func _update_continue_button() -> void:
	if _main_menu_ctrl == null:
		return
	var save_mgr := get_node_or_null("/root/SaveManager")
	if save_mgr == null or not save_mgr.save_exists():
		_main_menu_ctrl.call("setup_continue_button", false, "DEVAM ET")
		return
	var save_data: Dictionary = save_mgr.read_save()
	var label := "TEKRAR DENE" if bool(save_data.get("died", false)) else "DEVAM ET"
	_main_menu_ctrl.call("setup_continue_button", true, label)


func _try_save_progress() -> void:
	var save_mgr := get_node_or_null("/root/SaveManager")
	if save_mgr == null:
		return
	var player_node := get_node_or_null("Player")
	var run_state   := get_node_or_null("/root/RunState")
	var data: Dictionary = save_mgr.build_save_data(player_node, run_state)
	data["died"] = false
	if save_mgr.has_progress(data):
		save_mgr.write_save(data)


func _try_save_progress_on_death() -> void:
	var save_mgr := get_node_or_null("/root/SaveManager")
	if save_mgr == null:
		return
	var player_node := get_node_or_null("Player")
	var run_state   := get_node_or_null("/root/RunState")
	var data: Dictionary = save_mgr.build_save_data(player_node, run_state)
	data["died"] = true
	save_mgr.write_save(data)


func _apply_save_to_run(data: Dictionary) -> void:
	var run_state := get_node_or_null("/root/RunState")
	if run_state != null:
		run_state.mining_upgrade_level       = int(data.get("mining_upgrade_level", 0))
		run_state.mining_speed_upgrade_level = int(data.get("mining_speed_upgrade_level", 0))
		run_state.energy_field_upgrade_level = int(data.get("energy_field_upgrade_level", 0))
		run_state.energy_orb_magnet_upgrade_level = int(data.get("energy_orb_magnet_upgrade_level", 0))
		run_state.damage_aura_upgrade_level  = int(data.get("damage_aura_upgrade_level", 0))
		run_state.orbit_mode_upgrade_level   = int(data.get("orbit_mode_upgrade_level", 0))
		run_state.crit_chance_upgrade_level  = int(data.get("crit_chance_upgrade_level", 0))
		run_state.laser_duration_upgrade_level = int(data.get("laser_duration_upgrade_level", 0))
		run_state.dual_laser_upgrade_level = int(data.get("dual_laser_upgrade_level", 0))
		run_state.attraction_skill_unlocked  = bool(data.get("attraction_skill_unlocked", int(run_state.energy_field_upgrade_level) > 0))
		run_state.drop_collection_skill_unlocked = bool(data.get("drop_collection_skill_unlocked", false))
		run_state.blackhole_level = int(data.get("blackhole_level", 1))
		run_state.blackhole_progress = float(data.get("blackhole_progress", 0.0))
		run_state.blackhole_energy = float(data.get("blackhole_energy", 0.0))
		run_state.blackhole_total_energy = float(data.get("blackhole_total_energy", run_state.blackhole_energy))
		run_state.blackhole_gravity_well_level = int(data.get("blackhole_gravity_well_level", 0))
		run_state.blackhole_event_horizon_level = int(data.get("blackhole_event_horizon_level", 0))
		run_state.blackhole_accretion_level = int(data.get("blackhole_accretion_level", 0))
		run_state.blackhole_singularity_drive_level = int(data.get("blackhole_singularity_drive_level", 0))
		run_state.iron    = int(data.get("iron", 0))
		run_state.gold    = int(data.get("gold", 0))
		run_state.crystal = int(data.get("crystal", 0))
		run_state.uranium = int(data.get("uranium", 0))
		run_state.titanium = int(data.get("titanium", 0))
	_apply_run_state_to_scene()
	if black_hole != null and black_hole.has_method("reload_from_run_state"):
		black_hole.call("reload_from_run_state")


func _apply_run_state_to_scene() -> void:
	var run_state := get_node_or_null("/root/RunState")
	if run_state == null:
		return
	var player_node := get_node_or_null("Player")
	if player_node != null:
		player_node.set("iron", int(run_state.iron))
		player_node.set("gold", int(run_state.gold))
		player_node.set("crystal", int(run_state.crystal))
		player_node.set("uranium", int(run_state.uranium))
		player_node.set("titanium", int(run_state.titanium))


func _close_main_menu() -> void:
	_ui_flow.close_main_menu()
	var run_state := get_node_or_null("/root/RunState")
	if run_state != null:
		run_state.active = true


func _open_pause() -> void:
	_ui_flow.open_pause(get_tree())
	if _pause_screen_ctrl != null:
		_pause_screen_ctrl.call("show_menu")


func _close_pause() -> void:
	_ui_flow.close_pause(get_tree())
	if _pause_screen_ctrl != null:
		_pause_screen_ctrl.call("hide_menu")


func _on_pause_resume_pressed() -> void:
	_close_pause()


func _on_pause_ocak_pressed() -> void:
	_ui_flow.open_ocak()
	if _ocak_screen_ctrl != null:
		_ocak_screen_ctrl.call("show_screen")


func _on_ocak_close_pressed() -> void:
	_ui_flow.close_ocak()
	if _ocak_screen_ctrl != null:
		_ocak_screen_ctrl.call("hide_screen")
	if _pause_screen_ctrl != null:
		_pause_screen_ctrl.call("show_menu")


func _on_pause_main_menu_pressed() -> void:
	_try_save_progress()
	# Pause'u kapat, sahneyi yeniden yükle — auto_load_save=false olduğu için
	# _ready() else branch'ına girer ve ana menüyü açar.
	_ui_flow.close_pause(get_tree())
	if _pause_screen_ctrl != null:
		_pause_screen_ctrl.call("hide_menu")
	_restart_in_progress = true
	_ui_flow.flow_state = WorldUIFlow.RunFlowState.RESTARTING
	_ui_flow.game_over_triggered = false
	_reset_tree_runtime_state()
	_hide_all_overlay_ui()
	set_process_input(false)
	set_process_unhandled_input(false)
	var run_state := get_node_or_null("/root/RunState")
	if run_state != null:
		run_state.auto_load_save = false
		run_state.coming_from_portal = false
	call_deferred("_perform_scene_reload")
