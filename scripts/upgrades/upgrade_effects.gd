extends RefCounted
class_name UpgradeEffects

const UpgradeDefinitions = preload("res://scripts/upgrades/upgrade_definitions.gd")


static func is_attraction_skill_unlocked(run_state: Node) -> bool:
	if run_state == null:
		return false
	return bool(run_state.attraction_skill_unlocked)


static func is_drop_collection_skill_unlocked(run_state: Node) -> bool:
	if run_state == null:
		return false
	return bool(run_state.drop_collection_skill_unlocked)


static func get_current_mining_damage(run_state: Node) -> float:
	if run_state == null:
		return 1.0
	var lvl := clampi(int(run_state.mining_upgrade_level), 0, UpgradeDefinitions.MINING_DAMAGE_VALUES.size() - 1)
	return float(UpgradeDefinitions.MINING_DAMAGE_VALUES[lvl])


static func get_current_mining_interval(run_state: Node) -> float:
	if run_state == null:
		return float(UpgradeDefinitions.MINING_SPEED_INTERVAL_VALUES[0])
	var lvl := clampi(int(run_state.mining_speed_upgrade_level), 0, UpgradeDefinitions.MINING_SPEED_INTERVAL_VALUES.size() - 1)
	return float(UpgradeDefinitions.MINING_SPEED_INTERVAL_VALUES[lvl])


static func get_damage_aura_upgrade_level(run_state: Node) -> int:
	if run_state == null:
		return 0
	return maxi(0, int(run_state.damage_aura_upgrade_level))


static func get_current_damage_aura_radius(run_state: Node, base_radius: float) -> float:
	var level := get_damage_aura_upgrade_level(run_state)
	return maxf(1.0, base_radius) * pow(1.5, float(level))


static func get_energy_field_upgrade_level(run_state: Node) -> int:
	if run_state == null:
		return 0
	if not is_attraction_skill_unlocked(run_state):
		return 0
	return maxi(0, int(run_state.energy_field_upgrade_level))


static func get_current_energy_field_radius(run_state: Node, base_radius: float) -> float:
	var level := get_energy_field_upgrade_level(run_state)
	return maxf(1.0, base_radius) * pow(1.25, float(level))


static func get_energy_orb_magnet_upgrade_level(run_state: Node) -> int:
	if run_state == null:
		return 0
	if not is_attraction_skill_unlocked(run_state):
		return 0
	return clampi(int(run_state.energy_orb_magnet_upgrade_level), 0, UpgradeDefinitions.MAX_ENERGY_ORB_MAGNET_UPGRADE_LEVEL)


static func get_energy_orb_attract_radius_multiplier(run_state: Node) -> float:
	var level := get_energy_orb_magnet_upgrade_level(run_state)
	if level <= 0:
		return 1.0
	return pow(1.5, float(level))


static func get_orbit_mode_upgrade_level(run_state: Node) -> int:
	if run_state == null:
		return 0
	return maxi(0, int(run_state.orbit_mode_upgrade_level))


static func get_current_orbit_mode_capacity(run_state: Node) -> int:
	return 1 + get_orbit_mode_upgrade_level(run_state)


static func get_crit_chance_upgrade_level(run_state: Node) -> int:
	if run_state == null:
		return 0
	return clampi(int(run_state.crit_chance_upgrade_level), 0, UpgradeDefinitions.MAX_CRIT_CHANCE_UPGRADE_LEVEL)


static func get_current_crit_chance(run_state: Node) -> float:
	return float(UpgradeDefinitions.CRIT_CHANCE_VALUES[get_crit_chance_upgrade_level(run_state)])


static func get_crit_damage_multiplier() -> float:
	return UpgradeDefinitions.CRIT_DAMAGE_MULTIPLIER


static func is_developer_mode_enabled(run_state: Node) -> bool:
	if run_state == null:
		return false
	return bool(run_state.developer_mode_enabled)
