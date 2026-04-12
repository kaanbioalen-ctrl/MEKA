extends Control
class_name StarBackground
## Procedural star field with slow drift and loose clusters.
## Stars wrap around screen edges. No zoom pulse.

const MAX_STARS:       int   = 50
const MAX_DRIFT_SPEED: float = 50.0

var _stars: Array[Dictionary] = []
var _time:  float = 0.0
var _built: bool  = false


func _ready() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0
	mouse_filter  = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	_rebuild_stars()
	resized.connect(_rebuild_stars)


func _rebuild_stars() -> void:
	_stars.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 55271
	var w := maxf(size.x, 800.0)
	var h := maxf(size.y, 600.0)

	var placed := 0
	while placed < MAX_STARS:
		# Decide cluster size: 35% chance of a cluster (2-6 stars)
		var cluster_size: int
		if rng.randf() < 0.35:
			cluster_size = rng.randi_range(2, 6)
		else:
			cluster_size = 1
		cluster_size = mini(cluster_size, MAX_STARS - placed)

		# Shared base velocity for this cluster
		var base_speed := rng.randf_range(5.0, MAX_DRIFT_SPEED)
		var base_angle := rng.randf() * TAU
		var base_vel   := Vector2(cos(base_angle), sin(base_angle)) * base_speed

		# Cluster spawn center
		var cx := rng.randf() * w
		var cy := rng.randf() * h

		for _j in range(cluster_size):
			var roll := rng.randf()
			var radius: float
			var base_a: float
			if roll > 0.92:          # bright
				radius = rng.randf_range(2.5, 4.5)
				base_a = rng.randf_range(0.48, 0.78)
			elif roll > 0.75:        # medium
				radius = rng.randf_range(1.2, 2.5)
				base_a = rng.randf_range(0.22, 0.48)
			else:                    # dim
				radius = rng.randf_range(0.4, 1.2)
				base_a = rng.randf_range(0.06, 0.24)

			# Individual position variance within cluster
			var spread       := rng.randf_range(0.0, 40.0)
			var spread_angle := rng.randf() * TAU
			var pos := Vector2(
				cx + cos(spread_angle) * spread,
				cy + sin(spread_angle) * spread,
			)

			# Individual velocity variance (slight deviation from cluster base)
			var var_speed := rng.randf_range(0.0, 8.0)
			var var_angle := rng.randf() * TAU
			var vel := base_vel + Vector2(cos(var_angle), sin(var_angle)) * var_speed
			if vel.length() > MAX_DRIFT_SPEED:
				vel = vel.normalized() * MAX_DRIFT_SPEED

			_stars.append({
				"pos":   pos,
				"vel":   vel,
				"r":     radius,
				"a":     base_a,
				"phase": rng.randf() * TAU,
				"spd":   rng.randf_range(0.28, 1.7),
			})
		placed += cluster_size

	_built = true
	queue_redraw()


## No-op kept for API compatibility with UpgradeScreen.
func on_panel_opened() -> void:
	pass


func _process(delta: float) -> void:
	_time += delta
	if _built:
		var w := maxf(size.x, 800.0)
		var h := maxf(size.y, 600.0)
		for star in _stars:
			var pos: Vector2 = star["pos"] as Vector2
			var vel: Vector2 = star["vel"] as Vector2
			pos += vel * delta
			# Wrap around screen edges
			if   pos.x < 0.0: pos.x += w
			elif pos.x > w:   pos.x -= w
			if   pos.y < 0.0: pos.y += h
			elif pos.y > h:   pos.y -= h
			star["pos"] = pos
	queue_redraw()


func _draw() -> void:
	if not _built:
		return
	for star in _stars:
		var pos:   Vector2 = star["pos"] as Vector2
		var r:     float   = float(star["r"])
		var ba:    float   = float(star["a"])
		var phase: float   = float(star["phase"])
		var spd:   float   = float(star["spd"])
		var twinkle: float = sin(_time * spd + phase) * 0.5 + 0.5
		var alpha:   float = clampf(ba * lerpf(0.42, 1.0, twinkle), 0.0, 1.0)
		draw_circle(pos, r, Color(0.80, 0.92, 1.0, alpha))
		if r > 2.0:
			draw_circle(pos, r * 2.5, Color(0.65, 0.82, 1.0, alpha * 0.14))
