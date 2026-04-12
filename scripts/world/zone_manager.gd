extends Node
class_name ZoneManager

const GRID_WIDTH: int = 10
const GRID_HEIGHT: int = 10
const TOTAL_SCREENS: int = GRID_WIDTH * GRID_HEIGHT

var screen_size: Vector2 = Vector2.ZERO
var world_size: Vector2 = Vector2.ZERO
var zones: Array[Dictionary] = []


func rebuild(viewport_size: Vector2) -> void:
	screen_size = viewport_size
	world_size = Vector2(screen_size.x * GRID_WIDTH, screen_size.y * GRID_HEIGHT)
	zones.clear()

	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			var zone_id := y * GRID_WIDTH + x
			var rect := Rect2(
				Vector2(float(x) * screen_size.x, float(y) * screen_size.y),
				screen_size
			)
			zones.append({
				"id": zone_id,
				"grid": Vector2i(x, y),
				"rect": rect
			})


func get_total_screens() -> int:
	return TOTAL_SCREENS


func get_zone_at_position(world_position: Vector2) -> Dictionary:
	if screen_size.x <= 0.0 or screen_size.y <= 0.0 or zones.is_empty():
		return {}
	var gx := int(clampf(world_position.x / screen_size.x, 0.0, float(GRID_WIDTH  - 1)))
	var gy := int(clampf(world_position.y / screen_size.y, 0.0, float(GRID_HEIGHT - 1)))
	var zone_id := gy * GRID_WIDTH + gx
	if zone_id < 0 or zone_id >= zones.size():
		return {}
	return zones[zone_id]
