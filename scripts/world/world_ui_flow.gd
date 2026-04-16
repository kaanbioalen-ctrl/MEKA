extends RefCounted
class_name WorldUIFlow

enum RunFlowState {
	MENU,
	RUNNING,
	GAME_OVER,
	UPGRADE,
	RESTARTING,
	PAUSED,
	OCAK,
}

var death_screen: CanvasLayer = null
var upgrade_screen: CanvasLayer = null
var main_menu: CanvasLayer = null
var hud: CanvasLayer = null
var pause_screen: CanvasLayer = null
var ocak_screen: CanvasLayer = null

var flow_state: int = RunFlowState.RUNNING
var game_over_triggered: bool = false


func setup(next_death_screen: CanvasLayer, next_upgrade_screen: CanvasLayer, next_main_menu: CanvasLayer, next_hud: CanvasLayer, next_pause_screen: CanvasLayer = null, next_ocak_screen: CanvasLayer = null) -> void:
	death_screen = next_death_screen
	upgrade_screen = next_upgrade_screen
	main_menu = next_main_menu
	hud = next_hud
	pause_screen = next_pause_screen
	ocak_screen = next_ocak_screen


func reset_runtime_state() -> void:
	game_over_triggered = false
	if pause_screen != null:
		pause_screen.visible = false
	if ocak_screen != null:
		ocak_screen.visible = false
	flow_state = RunFlowState.RUNNING


func is_menu() -> bool:
	return flow_state == RunFlowState.MENU


func is_game_over() -> bool:
	return flow_state == RunFlowState.GAME_OVER


func is_upgrade() -> bool:
	return flow_state == RunFlowState.UPGRADE


func is_death_screen_visible() -> bool:
	return death_screen != null and death_screen.visible


func is_upgrade_screen_visible() -> bool:
	return upgrade_screen != null and upgrade_screen.visible


func set_death_screen_visible(visible: bool) -> void:
	if death_screen != null:
		death_screen.visible = visible


func set_upgrade_screen_visible(visible: bool) -> void:
	if upgrade_screen == null:
		return
	if visible and upgrade_screen.has_method("open_screen"):
		upgrade_screen.call("open_screen")
		return
	if not visible and upgrade_screen.has_method("close_screen"):
		upgrade_screen.call("close_screen")
		return
	upgrade_screen.visible = visible


func set_main_menu_visible(visible: bool) -> void:
	if main_menu != null:
		main_menu.visible = visible


func hide_all_overlay_ui() -> void:
	set_main_menu_visible(false)
	set_upgrade_screen_visible(false)
	set_death_screen_visible(false)
	if pause_screen != null:
		pause_screen.visible = false
	if ocak_screen != null:
		ocak_screen.visible = false
	if hud != null:
		hud.visible = true


func open_main_menu() -> void:
	flow_state = RunFlowState.MENU
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.paused = true
	set_main_menu_visible(true)
	set_death_screen_visible(false)
	set_upgrade_screen_visible(false)
	if hud != null:
		hud.visible = false


func close_main_menu() -> void:
	set_main_menu_visible(false)
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.paused = false
	flow_state = RunFlowState.RUNNING
	if hud != null:
		hud.visible = true


func trigger_game_over_once(restart_in_progress: bool) -> bool:
	if game_over_triggered or restart_in_progress:
		return false
	game_over_triggered = true
	flow_state = RunFlowState.GAME_OVER
	set_upgrade_screen_visible(false)
	set_death_screen_visible(true)
	return true


func open_upgrade_overlay(restart_in_progress: bool, allow_game_over: bool = false) -> void:
	if restart_in_progress:
		return
	if game_over_triggered and not allow_game_over:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.paused = true
	set_death_screen_visible(false)
	set_upgrade_screen_visible(true)
	flow_state = RunFlowState.UPGRADE


func close_upgrade_overlay() -> void:
	set_upgrade_screen_visible(false)
	var tree := Engine.get_main_loop() as SceneTree
	if game_over_triggered:
		if tree != null:
			tree.paused = true
		set_death_screen_visible(true)
		flow_state = RunFlowState.GAME_OVER
	else:
		if tree != null:
			tree.paused = false
		set_death_screen_visible(false)
		flow_state = RunFlowState.RUNNING


func handle_upgrade_close_requested(restart_in_progress: bool) -> void:
	if restart_in_progress:
		return
	if flow_state == RunFlowState.UPGRADE and game_over_triggered:
		set_upgrade_screen_visible(false)
		set_death_screen_visible(true)
		flow_state = RunFlowState.GAME_OVER
		return
	close_upgrade_overlay()


func is_paused() -> bool:
	return flow_state == RunFlowState.PAUSED


func can_pause() -> bool:
	return flow_state == RunFlowState.RUNNING


func open_pause(tree: SceneTree) -> void:
	if not can_pause():
		return
	flow_state = RunFlowState.PAUSED
	if pause_screen != null:
		pause_screen.visible = true
	if tree != null:
		tree.paused = true


func close_pause(tree: SceneTree) -> void:
	if flow_state != RunFlowState.PAUSED:
		return
	flow_state = RunFlowState.RUNNING
	if pause_screen != null:
		pause_screen.visible = false
	if tree != null:
		tree.paused = false


func can_toggle_upgrade_with_keyboard(restart_in_progress: bool, player_exists: bool) -> bool:
	if flow_state == RunFlowState.MENU:
		return false
	if flow_state == RunFlowState.PAUSED:
		return false
	if flow_state == RunFlowState.OCAK:
		return false
	if restart_in_progress or game_over_triggered or is_death_screen_visible():
		return false
	return player_exists


func is_ocak() -> bool:
	return flow_state == RunFlowState.OCAK


func open_ocak() -> void:
	if flow_state != RunFlowState.PAUSED:
		return
	flow_state = RunFlowState.OCAK
	if pause_screen != null:
		pause_screen.visible = false
	if ocak_screen != null:
		ocak_screen.visible = true


func close_ocak() -> void:
	if flow_state != RunFlowState.OCAK:
		return
	flow_state = RunFlowState.PAUSED
	if ocak_screen != null:
		ocak_screen.visible = false
	if pause_screen != null:
		pause_screen.visible = true
