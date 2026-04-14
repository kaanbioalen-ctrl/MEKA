extends Node2D
## Üçüncü harita (Uranium Zone) için spawner.
## Sadece uranyum asteroidleri spawnlar — wrap-aware mesafe hesabı.

const SMALL_URANIUM_WEIGHT  := 50.0
const MEDIUM_URANIUM_WEIGHT := 32.0
const LARGE_URANIUM_WEIGHT  := 18.0
const SULFUR_SPAWN_CHANCE   := 0.75

@export var uranium_small_scene:       PackedScene
@export var uranium_medium_scene:      PackedScene
@export var uranium_large_scene:       PackedScene
@export var uranium_small_definition:  AsteroidDefinition
@export var uranium_medium_definition: AsteroidDefinition
@export var uranium_large_definition:  AsteroidDefinition
@export var sulfur_scene:              PackedScene
@export var sulfur_definition:         AsteroidDefinition
@export_range(0.1, 2.0, 0.05) var tick_interval:                    float = 0.25
@export_range(80.0, 1200.0, 1.0) var safe_spawn_radius:             float = 280.0
@export_range(32.0, 800.0, 1.0) var spawn_margin_outside_view:      float = 180.0
@export_range(1, 100, 1) var desired_asteroid_count_near_player:     int   = 12
@export_range(400.0, 8000.0, 1.0) var despawn_distance:             float = 3600.0
@export_range(24.0, 600.0, 1.0) var min_asteroid_spacing:           float = 130.0
@export_range(1, 128, 1) var max_spawn_attempts:                     int   = 24
@export_range(0.5, 4.0, 0.1) var density_scale:                     float = 1.5

var _player:             Node2D  = null
var _world_bounds:       Rect2   = Rect2(0.0, 0.0, 0.0, 0.0)
var _screen_size:        Vector2 = Vector2(1920.0, 1080.0)
var _tick_left:          float   = 0.0
var _initial_fill_done:  bool    = false


func configure(player: Node2D, world_bounds: Rect2, screen_size: Vector2) -> void:
	_player            = player
	_world_bounds      = world_bounds
	_screen_size       = screen_size
	_tick_left         = tick_interval
	_initial_fill_done = false
	_fill_initial_neighborhood()


func _process(delta: float) -> void:
	if not _can_run():
		return
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left = tick_interval
	_cleanup_far_asteroids()
	_maintain_near_player_density()


func _fill_initial_neighborhood() -> void:
	if _initial_fill_done or not _can_run():
		return
	_cleanup_far_asteroids()
	_fill_quota(true)
	_initial_fill_done = true


func _maintain_near_player_density() -> void:
	_fill_quota(false)


func _fill_quota(allow_visible_spawn: bool) -> void:
	var nearby_count := _count_nearby_asteroids()
	while nearby_count < desired_asteroid_count_near_player:
		var spawn_data := _find_spawn_data(allow_visible_spawn)
		if spawn_data.is_empty():
			return
		if not _spawn_asteroid(spawn_data):
			return
		nearby_count += 1


func _spawn_asteroid(spawn_data: Dictionary) -> bool:
	var asteroid := _instantiate_uranium_asteroid()
	if asteroid == null:
		return false
	var player_max_speed := _get_player_max_speed()
	asteroid.global_position = spawn_data["position"]
	if asteroid.has_method("set_speed"):
		asteroid.call("set_speed", maxf(1.0, player_max_speed * randf_range(0.09, 0.16)))
	if asteroid.has_method("set_move_direction"):
		asteroid.call("set_move_direction", spawn_data["direction"])
	if asteroid.has_method("set_world_bounds"):
		asteroid.call("set_world_bounds", _world_bounds)
	if asteroid.has_method("set_player"):
		asteroid.call("set_player", _player)
	get_parent().add_child(asteroid)
	return true


func _find_spawn_data(allow_visible_spawn: bool) -> Dictionary:
	if _player == null:
		return {}
	var player_pos          := _player.global_position
	var view_rect           := _get_view_rect_centered_on_player()
	var neighborhood_radius := _get_neighborhood_radius()
	for _attempt in range(max_spawn_attempts):
		var candidate := _pick_spawn_candidate(view_rect, allow_visible_spawn)
		if candidate.is_empty():
			continue
		var candidate_position: Vector2 = candidate["position"]
		var wrapped_candidate := WorldWrap.closest_wrapped_target(
			player_pos, candidate_position, _world_bounds
		)
		var dist_to_player := player_pos.distance_to(wrapped_candidate)
		if dist_to_player < safe_spawn_radius:
			continue
		if dist_to_player > neighborhood_radius:
			continue
		if not _has_spacing_from_asteroids(candidate_position):
			continue
		return candidate
	return {}


func _pick_spawn_candidate(view_rect: Rect2, allow_visible_spawn: bool) -> Dictionary:
	if allow_visible_spawn:
		return _pick_initial_spawn_candidate(view_rect)
	return _pick_runtime_spawn_candidate(view_rect)


func _pick_initial_spawn_candidate(_view_rect: Rect2) -> Dictionary:
	var player_pos          := _player.global_position
	var neighborhood_radius := _get_neighborhood_radius()
	var angle               := randf() * TAU
	var min_radius          := maxf(safe_spawn_radius, min_asteroid_spacing * 0.9)
	var spawn_radius        := randf_range(min_radius, neighborhood_radius)
	var spawn_pos           := player_pos + Vector2.RIGHT.rotated(angle) * spawn_radius
	spawn_pos = WorldWrap.apply(spawn_pos, _world_bounds)
	var tangent_blend := randf_range(-0.5, 0.5)
	var to_player     := (player_pos - spawn_pos).normalized()
	if to_player == Vector2.ZERO:
		to_player = Vector2.RIGHT
	var tangent_dir := to_player.orthogonal()
	if tangent_blend < 0.0:
		tangent_dir = -tangent_dir
	var move_direction := to_player.slerp(tangent_dir, absf(tangent_blend) * 0.35).normalized()
	if move_direction == Vector2.ZERO:
		move_direction = Vector2.RIGHT.rotated(randf() * TAU)
	return {"position": spawn_pos, "direction": move_direction}


func _pick_runtime_spawn_candidate(view_rect: Rect2) -> Dictionary:
	var expanded_view := view_rect.grow(spawn_margin_outside_view)
	var side          := randi() % 4
	var spawn_pos     := Vector2.ZERO
	var target_pos    := Vector2.ZERO
	match side:
		0:
			spawn_pos  = Vector2(randf_range(expanded_view.position.x, expanded_view.end.x), expanded_view.position.y)
			target_pos = Vector2(randf_range(view_rect.position.x, view_rect.end.x), view_rect.position.y + randf_range(view_rect.size.y * 0.12, view_rect.size.y * 0.88))
		1:
			spawn_pos  = Vector2(expanded_view.end.x, randf_range(expanded_view.position.y, expanded_view.end.y))
			target_pos = Vector2(view_rect.end.x - randf_range(view_rect.size.x * 0.12, view_rect.size.x * 0.88), randf_range(view_rect.position.y, view_rect.end.y))
		2:
			spawn_pos  = Vector2(randf_range(expanded_view.position.x, expanded_view.end.x), expanded_view.end.y)
			target_pos = Vector2(randf_range(view_rect.position.x, view_rect.end.x), view_rect.end.y - randf_range(view_rect.size.y * 0.12, view_rect.size.y * 0.88))
		_:
			spawn_pos  = Vector2(expanded_view.position.x, randf_range(expanded_view.position.y, expanded_view.end.y))
			target_pos = Vector2(view_rect.position.x + randf_range(view_rect.size.x * 0.12, view_rect.size.x * 0.88), randf_range(view_rect.position.y, view_rect.end.y))
	spawn_pos = WorldWrap.apply(spawn_pos, _world_bounds)
	if not _is_outside_view(spawn_pos, view_rect):
		return {}
	var move_direction := (target_pos - spawn_pos).normalized()
	if move_direction == Vector2.ZERO:
		move_direction = (_player.global_position - spawn_pos).normalized()
	if move_direction == Vector2.ZERO:
		move_direction = Vector2.RIGHT
	move_direction = move_direction.rotated(randf_range(-0.22, 0.22)).normalized()
	return {"position": spawn_pos, "direction": move_direction}


func _count_nearby_asteroids() -> int:
	var player_pos             := _player.global_position
	var neighborhood_radius_sq := _get_neighborhood_radius() * _get_neighborhood_radius()
	var count := 0
	for asteroid_node in get_tree().get_nodes_in_group("asteroid"):
		if not (asteroid_node is Node2D):
			continue
		var asteroid := asteroid_node as Node2D
		var wrapped := WorldWrap.closest_wrapped_target(
			player_pos, asteroid.global_position, _world_bounds
		)
		if wrapped.distance_squared_to(player_pos) <= neighborhood_radius_sq:
			count += 1
	return count


func _cleanup_far_asteroids() -> void:
	if _player == null:
		return
	var player_pos          := _player.global_position
	var despawn_distance_sq := despawn_distance * despawn_distance
	for asteroid_node in get_tree().get_nodes_in_group("asteroid"):
		if not (asteroid_node is Node2D):
			continue
		var asteroid := asteroid_node as Node2D
		var wrapped := WorldWrap.closest_wrapped_target(
			player_pos, asteroid.global_position, _world_bounds
		)
		if wrapped.distance_squared_to(player_pos) > despawn_distance_sq:
			asteroid.queue_free()


func _has_spacing_from_asteroids(candidate_position: Vector2) -> bool:
	var spacing_sq := min_asteroid_spacing * min_asteroid_spacing
	for asteroid_node in get_tree().get_nodes_in_group("asteroid"):
		if not (asteroid_node is Node2D):
			continue
		var asteroid := asteroid_node as Node2D
		var wrapped := WorldWrap.closest_wrapped_target(
			candidate_position, asteroid.global_position, _world_bounds
		)
		if wrapped.distance_squared_to(candidate_position) < spacing_sq:
			return false
	return true


func _get_view_rect_centered_on_player() -> Rect2:
	var size := _screen_size
	if size.x <= 0.0 or size.y <= 0.0:
		size = Vector2(1920.0, 1080.0)
	return Rect2(_player.global_position - (size * 0.5), size)


func _get_neighborhood_radius() -> float:
	var view_radius := _screen_size.length() * 0.7
	var base := (view_radius + spawn_margin_outside_view) * density_scale
	return minf(maxf(base, safe_spawn_radius + min_asteroid_spacing), despawn_distance * 0.72)


func _get_player_max_speed() -> float:
	if _player != null and _player.get("max_speed") != null:
		return float(_player.get("max_speed"))
	return 420.0


func _is_outside_view(position: Vector2, view_rect: Rect2) -> bool:
	return not view_rect.has_point(position)


func _can_run() -> bool:
	return (
		uranium_small_scene       != null
		and uranium_medium_scene  != null
		and uranium_large_scene   != null
		and uranium_small_definition  != null
		and uranium_medium_definition != null
		and uranium_large_definition  != null
		and _player != null
		and is_instance_valid(_player)
		and get_parent() != null
	)


func _instantiate_uranium_asteroid() -> Node2D:
	var use_sulfur := _can_spawn_sulfur() and randf() < SULFUR_SPAWN_CHANCE
	if use_sulfur:
		return _instantiate_sulfur_asteroid()
	var size_key      := _pick_weighted_size_key()
	var uranium_scene := _get_scene_for_size(size_key)
	var uranium_def   := _get_definition_for_size(size_key)
	if uranium_scene == null or uranium_def == null:
		return null
	var asteroid := uranium_scene.instantiate() as Node2D
	if asteroid == null:
		return null
	if asteroid.has_method("set_definition"):
		asteroid.call("set_definition", uranium_def)
	return asteroid


func _instantiate_sulfur_asteroid() -> Node2D:
	if sulfur_scene == null:
		return null
	var asteroid := sulfur_scene.instantiate() as Node2D
	if asteroid == null:
		return null
	if sulfur_definition != null and asteroid.has_method("set_definition"):
		asteroid.call("set_definition", sulfur_definition)
	return asteroid


func _pick_weighted_size_key() -> String:
	var total_weight := SMALL_URANIUM_WEIGHT + MEDIUM_URANIUM_WEIGHT + LARGE_URANIUM_WEIGHT
	if total_weight <= 0.0:
		return "medium"
	var roll := randf() * total_weight
	if roll < SMALL_URANIUM_WEIGHT:
		return "small"
	if roll < SMALL_URANIUM_WEIGHT + MEDIUM_URANIUM_WEIGHT:
		return "medium"
	return "large"


func _get_scene_for_size(size_key: String) -> PackedScene:
	match size_key:
		"small": return uranium_small_scene
		"large": return uranium_large_scene
		_:       return uranium_medium_scene


func _get_definition_for_size(size_key: String) -> AsteroidDefinition:
	match size_key:
		"small": return uranium_small_definition
		"large": return uranium_large_definition
		_:       return uranium_medium_definition


func _can_spawn_sulfur() -> bool:
	return sulfur_scene != null
