extends Node
class_name OcakDropIntegrator

## Ocak ekranındaki EnergyOrb'ları RadialGravityEngine'e bağlar.
##
## Kullanım:
##   1. OcakScreen sahnesine bu script'i ekle (Node olarak).
##   2. @export alanlarını inspector'dan bağla.
##   3. Ocak ekranı açıldığında _register_existing_drops() çağır,
##      yeni drop spawnadığında register_drop() çağır.

@export var engine: RadialGravityEngine = null

## Ocak ekranının dünya uzayındaki merkezi (genellikle karadelik node'unun global_position'ı).
@export var ocak_center: Node2D = null


func _ready() -> void:
	if engine == null:
		push_warning("OcakDropIntegrator: engine atanmadı.")
		return
	engine.drop_absorbed.connect(_on_drop_absorbed)
	engine.drop_settled.connect(_on_drop_settled)
	engine.cell_sealed.connect(_on_cell_sealed)
	engine.pattern_matched.connect(_on_pattern_matched)


## Sahnede zaten var olan tüm energy_pickup grubundaki node'ları engine'e ekle.
func register_existing_drops() -> void:
	if engine == null:
		return
	var center_pos := _center_world()
	for node in get_tree().get_nodes_in_group("energy_pickup"):
		if not is_instance_valid(node):
			continue
		var n2d := node as Node2D
		if n2d == null:
			continue
		_hand_off(n2d, center_pos)


## Yeni bir drop'u engine'e teslim et.
## Genellikle drop spawn edildiğinde çağrılır.
func register_drop(drop_node: Node2D) -> void:
	if engine == null or not is_instance_valid(drop_node):
		return
	var center_pos := _center_world()
	_hand_off(drop_node, center_pos)


func _hand_off(node: Node2D, center_pos: Vector2) -> void:
	# Engine local-space konumu (engine'in kendi dönüşümüne göre)
	var local_pos := engine.to_local(node.global_position)

	# Mevcut hızı al (EnergyOrb ise _velocity property'si var)
	var vel := Vector2.ZERO
	if "_velocity" in node:
		vel = Vector2(node.get("_velocity"))

	# Resource bilgisi
	var kind  : StringName = &"iron"
	var value : int        = 1
	if "_resource_kind" in node:
		kind = StringName(node.get("_resource_kind"))
	match kind:
		&"iron":
			if "iron_value" in node:
				value = int(node.get("iron_value"))
		&"gold":
			if "gold_value" in node:
				value = int(node.get("gold_value"))
		&"energy":
			if "energy_percent_gain" in node:
				value = 1

	# EnergyOrb'un kendi fiziğini dondur — engine yönetecek
	if node.has_method("set_physics_process"):
		node.set_physics_process(false)
	if "monitoring" in node:
		node.set("monitoring", false)

	engine.add_drop(local_pos, vel, kind, value, node)


# ── Sinyal alıcıları ─────────────────────────────────────────────────────────

func _on_drop_absorbed(resource_kind: StringName, value: int) -> void:
	# Karadelik dropu yuttu — oyun state'ine kaynak ekle
	var world := _find_world()
	if world == null:
		return
	match resource_kind:
		&"iron":
			if world.has_method("add_iron"):
				world.call("add_iron", value)
		&"gold":
			if world.has_method("add_gold"):
				world.call("add_gold", value)
		&"energy":
			var player := _find_player()
			if player != null and player.has_method("add_energy_percent"):
				player.call("add_energy_percent", float(value))


func _on_drop_settled(layer: int, segment: int, resource_kind: StringName) -> void:
	# Opsiyonel: hücre doldu görsel efekti tetikle
	pass


func _on_cell_sealed(_layer: int, _segment: int) -> void:
	pass


func _on_pattern_matched(pattern_id: StringName, cells: Array) -> void:
	# Pattern eşleşti — örneğin upgrade tetikle
	print("OcakDropIntegrator: pattern '%s' eşleşti, %d hücre açıldı." % [pattern_id, cells.size()])


# ── Yardımcılar ──────────────────────────────────────────────────────────────

func _center_world() -> Vector2:
	if ocak_center != null and is_instance_valid(ocak_center):
		return ocak_center.global_position
	if engine != null:
		return engine.global_position
	return Vector2.ZERO


func _find_world() -> Node:
	return get_tree().get_first_node_in_group("world")


func _find_player() -> Node2D:
	var n := get_tree().get_first_node_in_group("player")
	return n as Node2D
