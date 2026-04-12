extends Node2D
## Devasa asteroid spawner — test haritası için.
## Dünya merkezinin iki yanına birer iron_devasa ve gold_devasa yerleştirir.
## configure() çağrısında tek seferlik spawn yapar.

const IRON_DEVASA_SCENE := preload("res://scenes/asteroids/iron_devasa.tscn")
const GOLD_DEVASA_SCENE := preload("res://scenes/asteroids/gold_devasa.tscn")
const IRON_DEVASA_DEF   := preload("res://resources/asteroids/iron_devasa.tres")
const GOLD_DEVASA_DEF   := preload("res://resources/asteroids/gold_devasa.tres")

## İron devasa'nın dünya merkezine göre ofseti.
@export var iron_offset: Vector2 = Vector2(-1600.0, -400.0)
## Gold devasa'nın dünya merkezine göre ofseti.
@export var gold_offset: Vector2 = Vector2(1600.0, 400.0)

var _spawned: bool = false


func configure(player: Node2D, world_bounds: Rect2, _screen_size: Vector2) -> void:
	if _spawned:
		return
	_spawned = true
	var center := world_bounds.get_center()
	_spawn_iron(player, world_bounds, center + iron_offset)
	_spawn_gold(player, world_bounds, center + gold_offset)


func _spawn_iron(player: Node2D, world_bounds: Rect2, pos: Vector2) -> void:
	var asteroid := IRON_DEVASA_SCENE.instantiate() as Node2D
	if asteroid == null:
		return
	if asteroid.has_method("set_definition"):
		asteroid.call("set_definition", IRON_DEVASA_DEF)
	asteroid.global_position = pos
	if asteroid.has_method("set_world_bounds"):
		asteroid.call("set_world_bounds", world_bounds)
	if asteroid.has_method("set_player"):
		asteroid.call("set_player", player)
	# Çok yavaş, ağır drift hareketi
	var slow_dir := Vector2.RIGHT.rotated(randf_range(-PI * 0.15, PI * 0.15))
	if asteroid.has_method("set_move_direction"):
		asteroid.call("set_move_direction", slow_dir)
	get_parent().add_child(asteroid)


func _spawn_gold(player: Node2D, world_bounds: Rect2, pos: Vector2) -> void:
	var asteroid := GOLD_DEVASA_SCENE.instantiate() as Node2D
	if asteroid == null:
		return
	if asteroid.has_method("set_definition"):
		asteroid.call("set_definition", GOLD_DEVASA_DEF)
	asteroid.global_position = pos
	if asteroid.has_method("set_world_bounds"):
		asteroid.call("set_world_bounds", world_bounds)
	if asteroid.has_method("set_player"):
		asteroid.call("set_player", player)
	# Çok yavaş, ağır drift hareketi — iron'un tersine yönde
	var slow_dir := Vector2.LEFT.rotated(randf_range(-PI * 0.15, PI * 0.15))
	if asteroid.has_method("set_move_direction"):
		asteroid.call("set_move_direction", slow_dir)
	get_parent().add_child(asteroid)
