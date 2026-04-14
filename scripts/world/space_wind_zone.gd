extends Area2D
class_name SpaceWindZone

const DEFAULT_ASTEROID_SCENE := preload("res://scenes/asteroids/IronAsteroid.tscn")

@export_range(80.0, 1200.0, 1.0) var radius: float = 320.0
@export_range(10.0, 800.0, 1.0) var wind_speed: float = 180.0
@export_range(0.0, 1.5, 0.01) var turbulence: float = 0.42
@export_range(0.05, 10.0, 0.05) var steering_strength: float = 2.6
@export_range(0.0, 32.0, 1.0) var spawn_count: int = 8
@export var wind_direction: Vector2 = Vector2(1.0, -0.2)
@export var asteroid_scene: PackedScene = DEFAULT_ASTEROID_SCENE


func _ready() -> void:
	add_to_group("space_wind_zone")
	_sync_collision_shape()
	_spawn_asteroids_around_zone()
	queue_redraw()


func _physics_process(delta: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var base_dir := wind_direction.normalized()
	if base_dir == Vector2.ZERO:
		base_dir = Vector2.RIGHT
	for node in tree.get_nodes_in_group("asteroid"):
		if not (node is Node2D):
			continue
		if not is_instance_valid(node):
			continue
		var asteroid := node as Node2D
		var to_asteroid := asteroid.global_position - global_position
		var dist := to_asteroid.length()
		if dist > radius or dist <= 0.001:
			continue
		var edge_fade := 1.0 - clampf(dist / radius, 0.0, 1.0)
		var swirl_phase := sin((to_asteroid.angle() * 2.6) + (dist * 0.018))
		var desired_dir := base_dir.rotated(swirl_phase * turbulence)
		var current_velocity: Vector2 = asteroid.get("velocity")
		var current_speed := maxf(1.0, current_velocity.length())
		var target_speed := maxf(current_speed, wind_speed * (0.55 + edge_fade * 0.85))
		var desired_velocity := desired_dir * target_speed
		var blend := clampf(delta * steering_strength * (0.45 + edge_fade * 1.6), 0.0, 1.0)
		asteroid.set("velocity", current_velocity.lerp(desired_velocity, blend))


func _spawn_asteroids_around_zone() -> void:
	if asteroid_scene == null:
		return
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	for i in range(spawn_count):
		var asteroid := asteroid_scene.instantiate() as Node2D
		if asteroid == null:
			continue
		var angle := (TAU * float(i) / maxf(1.0, float(spawn_count))) + randf_range(-0.3, 0.3)
		var spawn_radius := randf_range(radius * 0.28, radius * 0.82)
		var spawn_pos := global_position + Vector2.RIGHT.rotated(angle) * spawn_radius
		asteroid.global_position = spawn_pos
		if asteroid.has_method("set_move_direction"):
			var tangent := (spawn_pos - global_position).orthogonal().normalized()
			if tangent == Vector2.ZERO:
				tangent = Vector2.RIGHT
			var base_dir := wind_direction.normalized()
			if base_dir == Vector2.ZERO:
				base_dir = Vector2.RIGHT
			var move_dir := tangent.slerp(base_dir, 0.55).normalized()
			asteroid.call("set_move_direction", move_dir)
		scene_root.add_child(asteroid)


func _sync_collision_shape() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	var circle := shape_node.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		shape_node.shape = circle
	circle.radius = radius


func _draw() -> void:
	var base_col := Color(0.18, 1.0, 0.46, 0.08)
	var line_col := Color(0.42, 1.0, 0.62, 0.36)
	draw_circle(Vector2.ZERO, radius, base_col)
	draw_arc(Vector2.ZERO, radius * 0.98, 0.0, TAU, 72, Color(0.34, 1.0, 0.58, 0.26), 2.0, true)
	var dir := wind_direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var perp := dir.orthogonal()
	for i in range(6):
		var t := float(i) / 5.0
		var offset := perp * lerpf(-radius * 0.55, radius * 0.55, t)
		var start := offset - dir * (radius * 0.42)
		var fin := offset + dir * (radius * 0.42)
		draw_line(start, fin, line_col, 1.6, true)
		draw_line(fin, fin - dir * 10.0 + perp * 4.0, line_col, 1.2, true)
		draw_line(fin, fin - dir * 10.0 - perp * 4.0, line_col, 1.2, true)
