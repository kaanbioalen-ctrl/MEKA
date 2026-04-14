extends Node

var active: bool = false
var auto_load_save: bool = false
var coming_from_portal: bool = false
var run_time: float = 0.0
var multiplier: float = 1.0
var mining_upgrade_level: int = 0
var mining_speed_upgrade_level: int = 0
var energy_field_upgrade_level: int = 0
var energy_orb_magnet_upgrade_level: int = 0
var damage_aura_upgrade_level: int = 0
var orbit_mode_upgrade_level: int = 0
var crit_chance_upgrade_level: int = 0
var attraction_skill_unlocked: bool = false
var drop_collection_skill_unlocked: bool = false
var developer_mode_enabled: bool = false
var iron_before_dev: int = 0
var gold_before_dev: int = 0
var crystal_before_dev: int = 0
var uranium_before_dev: int = 0
var titanium_before_dev: int = 0
var current_zone_id: int = -1
var current_zone_grid: Vector2i = Vector2i(-1, -1)
var total_zones: int = 0
var iron: int = 0
var gold: int = 0
var crystal: int = 0
var uranium: int = 0
var titanium: int = 0
var blackhole_level: int = 1
var blackhole_progress: float = 0.0
var blackhole_energy: float = 0.0
var blackhole_total_energy: float = 0.0
var blackhole_gravity_well_level: int = 0
var blackhole_event_horizon_level: int = 0
var blackhole_accretion_level: int = 0
var blackhole_singularity_drive_level: int = 0

# ── Silah kilitleri (perk ile kazanılır, run sonu sıfırlanır) ──────────────────
var laser_unlocked: bool = false
var bullet_unlocked: bool = false
var rocket_unlocked: bool = false
var laser_upgrade_level: int = 0
var laser_duration_upgrade_level: int = 0
var dual_laser_upgrade_level: int = 0
var bullet_bounce_upgrade_level: int = 0
var bullet_damage_upgrade_level: int = 0
var rocket_upgrade_level: int = 0


func _process(delta: float) -> void:
	if active:
		run_time += delta


func reset_run() -> void:
	active = false
	run_time = 0.0
	multiplier = 1.0
	mining_upgrade_level = 0
	mining_speed_upgrade_level = 0
	energy_field_upgrade_level = 0
	energy_orb_magnet_upgrade_level = 0
	damage_aura_upgrade_level = 0
	orbit_mode_upgrade_level = 0
	crit_chance_upgrade_level = 0
	attraction_skill_unlocked = false
	drop_collection_skill_unlocked = false
	developer_mode_enabled = false
	iron_before_dev = 0
	gold_before_dev = 0
	crystal_before_dev = 0
	uranium_before_dev = 0
	titanium_before_dev = 0
	current_zone_id = -1
	current_zone_grid = Vector2i(-1, -1)
	total_zones = 0
	iron = 0
	gold = 0
	crystal = 0
	uranium = 0
	titanium = 0
	blackhole_level = 1
	blackhole_progress = 0.0
	blackhole_energy = 0.0
	blackhole_total_energy = 0.0
	blackhole_gravity_well_level = 0
	blackhole_event_horizon_level = 0
	blackhole_accretion_level = 0
	blackhole_singularity_drive_level = 0
	laser_unlocked = false
	bullet_unlocked = false
	rocket_unlocked = false
	laser_upgrade_level = 0
	laser_duration_upgrade_level = 0
	dual_laser_upgrade_level = 0
	bullet_bounce_upgrade_level = 0
	bullet_damage_upgrade_level = 0
	rocket_upgrade_level = 0


func set_current_zone(zone_id: int, zone_grid: Vector2i) -> void:
	current_zone_id = zone_id
	current_zone_grid = zone_grid


func set_total_zones(value: int) -> void:
	total_zones = max(0, value)
