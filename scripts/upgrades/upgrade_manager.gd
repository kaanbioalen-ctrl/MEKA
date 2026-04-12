extends Node

const UpgradeDefinitions = preload("res://scripts/upgrades/upgrade_definitions.gd")


func get_run_state() -> Node:
	return get_node_or_null("/root/RunState")


func get_player() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("player")


func get_upgrade_cost_info(level: int) -> Dictionary:
	if level < 0 or level >= UpgradeDefinitions.STANDARD_UPGRADE_COSTS.size():
		return {"iron": 0, "gold": 0, "crystal": 0}
	return UpgradeDefinitions.STANDARD_UPGRADE_COSTS[level].duplicate()


func get_mining_upgrade_cost_info(level: int) -> Dictionary:
	if level < 0 or level >= UpgradeDefinitions.MINING_UPGRADE_COSTS.size():
		return {"iron": 0, "gold": 0, "crystal": 0}
	return UpgradeDefinitions.MINING_UPGRADE_COSTS[level].duplicate()


func get_orbit_mode_upgrade_cost_info(level: int) -> Dictionary:
	if level < 0 or level >= UpgradeDefinitions.ORBIT_MODE_UPGRADE_COSTS.size():
		return {"iron": 0, "gold": 0, "crystal": 0}
	return UpgradeDefinitions.ORBIT_MODE_UPGRADE_COSTS[level].duplicate()


func _can_pay_upgrade_cost(level: int) -> bool:
	var info := get_upgrade_cost_info(level)
	var iron_cost := int(info.get("iron", 0))
	var gold_cost := int(info.get("gold", 0))
	var crystal_cost := int(info.get("crystal", 0))
	if iron_cost <= 0 and gold_cost <= 0 and crystal_cost <= 0:
		return true
	var run_state := get_run_state()
	if run_state == null:
		return false
	if int(run_state.iron) < iron_cost:
		return false
	if int(run_state.gold) < gold_cost:
		return false
	if int(run_state.crystal) < crystal_cost:
		return false
	return true


func _can_pay_custom_cost(iron_cost: int, gold_cost: int = 0, crystal_cost: int = 0) -> bool:
	var run_state := get_run_state()
	if run_state == null:
		return false
	return int(run_state.iron) >= iron_cost and int(run_state.gold) >= gold_cost and int(run_state.crystal) >= crystal_cost


func _can_pay_specific_cost(info: Dictionary) -> bool:
	return _can_pay_custom_cost(int(info.get("iron", 0)), int(info.get("gold", 0)), int(info.get("crystal", 0)))


func _pay_custom_cost(iron_cost: int, gold_cost: int = 0, crystal_cost: int = 0) -> bool:
	if not _can_pay_custom_cost(iron_cost, gold_cost, crystal_cost):
		return false
	var run_state := get_run_state()
	if run_state == null:
		return false
	run_state.iron = maxi(0, int(run_state.iron) - iron_cost)
	run_state.gold = maxi(0, int(run_state.gold) - gold_cost)
	run_state.crystal = maxi(0, int(run_state.crystal) - crystal_cost)
	var player := get_player()
	if player != null:
		player.set("iron", run_state.iron)
		player.set("gold", run_state.gold)
		player.set("crystal", run_state.crystal)
	return true


func _pay_specific_cost(info: Dictionary) -> bool:
	return _pay_custom_cost(int(info.get("iron", 0)), int(info.get("gold", 0)), int(info.get("crystal", 0)))


func _pay_upgrade_cost(level: int) -> bool:
	if not _can_pay_upgrade_cost(level):
		return false
	var info := get_upgrade_cost_info(level)
	var run_state := get_run_state()
	if run_state == null:
		return false
	var iron_cost := int(info.get("iron", 0))
	var gold_cost := int(info.get("gold", 0))
	var crystal_cost := int(info.get("crystal", 0))
	if iron_cost > 0:
		run_state.iron = maxi(0, run_state.iron - iron_cost)
	if gold_cost > 0:
		run_state.gold = maxi(0, run_state.gold - gold_cost)
	if crystal_cost > 0:
		run_state.crystal = maxi(0, run_state.crystal - crystal_cost)
	var player := get_player()
	if player != null:
		player.set("iron",    run_state.iron)
		player.set("gold",    run_state.gold)
		player.set("crystal", run_state.crystal)
	return true


func _refund_cost(info: Dictionary) -> void:
	var run_state := get_run_state()
	if run_state == null:
		return
	run_state.iron    += int(info.get("iron",    0))
	run_state.gold    += int(info.get("gold",    0))
	run_state.crystal += int(info.get("crystal", 0))
	var player := get_player()
	if player != null:
		player.set("iron",    run_state.iron)
		player.set("gold",    run_state.gold)
		player.set("crystal", run_state.crystal)


func _get_total_cost(level: int, max_level: int) -> int:
	if level < 0 or level >= max_level:
		return 0
	var info := get_upgrade_cost_info(level)
	return int(info.get("iron", 0)) + int(info.get("gold", 0)) + int(info.get("crystal", 0))


func _get_specific_total_cost(info: Dictionary) -> int:
	return int(info.get("iron", 0)) + int(info.get("gold", 0)) + int(info.get("crystal", 0))


func _has_attraction_prerequisite() -> bool:
	var run_state := get_run_state()
	return run_state != null and bool(run_state.attraction_skill_unlocked)


func can_unlock_attraction_skill() -> bool:
	var run_state := get_run_state()
	if run_state == null:
		return false
	if bool(run_state.attraction_skill_unlocked):
		return false
	return _can_pay_custom_cost(UpgradeDefinitions.ATTRACTION_SKILL_IRON_COST)


func unlock_attraction_skill() -> bool:
	var run_state := get_run_state()
	if run_state == null:
		return false
	if not can_unlock_attraction_skill():
		return false
	if not _pay_custom_cost(UpgradeDefinitions.ATTRACTION_SKILL_IRON_COST):
		return false
	run_state.attraction_skill_unlocked = true
	run_state.energy_field_upgrade_level = 1
	return true


func can_unlock_drop_collection_skill() -> bool:
	var run_state := get_run_state()
	if run_state == null:
		return false
	if not _has_attraction_prerequisite():
		return false
	if bool(run_state.drop_collection_skill_unlocked):
		return false
	return _can_pay_custom_cost(0, UpgradeDefinitions.DROP_COLLECTION_SKILL_GOLD_COST, 0)


func unlock_drop_collection_skill() -> bool:
	var run_state := get_run_state()
	if run_state == null:
		return false
	if not can_unlock_drop_collection_skill():
		return false
	if not _pay_custom_cost(0, UpgradeDefinitions.DROP_COLLECTION_SKILL_GOLD_COST, 0):
		return false
	run_state.drop_collection_skill_unlocked = true
	return true


func can_buy_mining_upgrade() -> bool:
	var run_state := get_run_state()
	if run_state == null:
		return false
	if not _has_attraction_prerequisite():
		return false
	var lvl := int(run_state.mining_upgrade_level)
	if lvl >= UpgradeDefinitions.MAX_MINING_UPGRADE_LEVEL:
		return false
	return _can_pay_specific_cost(get_mining_upgrade_cost_info(lvl))


func get_next_mining_upgrade_cost() -> int:
	var run_state := get_run_state()
	if run_state == null:
		return 0
	return _get_specific_total_cost(get_mining_upgrade_cost_info(int(run_state.mining_upgrade_level)))


func buy_mining_upgrade() -> bool:
	var run_state := get_run_state()
	if run_state == null:
		return false
	if not can_buy_mining_upgrade():
		return false
	var lvl := int(run_state.mining_upgrade_level)
	if not _pay_specific_cost(get_mining_upgrade_cost_info(lvl)):
		return false
	run_state.mining_upgrade_level += 1
	return true


func downgrade_mining_upgrade() -> bool:
	var run_state := get_run_state()
	if run_state == null:
		return false
	var lvl := int(run_state.mining_upgrade_level)
	if lvl <= 0:
		return false
	_refund_cost(get_mining_upgrade_cost_info(lvl - 1))
	run_state.mining_upgrade_level -= 1
	return true


func can_buy_mining_speed_upgrade() -> bool:
	var run_state := get_run_state()
	if run_state == null:
		return false
	if not _has_attraction_prerequisite():
		return false
	if int(run_state.mining_speed_upgrade_level) >= UpgradeDefinitions.MAX_MINING_SPEED_UPGRADE_LEVEL:
		return false
	return _can_pay_specific_cost(get_mining_upgrade_cost_info(int(run_state.mining_speed_upgrade_level)))


func get_next_mining_speed_upgrade_cost() -> int:
	var run_state := get_run_state()
	if run_state == null:
		return 0
	return _get_specific_total_cost(get_mining_upgrade_cost_info(int(run_state.mining_speed_upgrade_level)))


func buy_mining_speed_upgrade() -> bool:
	var run_state := get_run_state()
	if run_state == null:
		return false
	if not can_buy_mining_speed_upgrade():
		return false
	if not _pay_specific_cost(get_mining_upgrade_cost_info(int(run_state.mining_speed_upgrade_level))):
		return false
	run_state.mining_speed_upgrade_level += 1
	return true


func downgrade_mining_speed_upgrade() -> bool:
	var run_state := get_run_state()
	if run_state == null:
		return false
	var lvl := int(run_state.mining_speed_upgrade_level)
	if lvl <= 0:
		return false
	_refund_cost(get_mining_upgrade_cost_info(lvl - 1))
	run_state.mining_speed_upgrade_level -= 1
	return true


func can_buy_energy_field_upgrade() -> bool:
	var run_state := get_run_state()
	if run_state == null:
		return false
	return can_unlock_attraction_skill()


func get_next_energy_field_upgrade_cost() -> int:
	return UpgradeDefinitions.ATTRACTION_SKILL_IRON_COST


func buy_energy_field_upgrade() -> bool:
	return unlock_attraction_skill()


func downgrade_damage_aura_upgrade() -> bool:
	var run_state := get_run_state()
	if run_state == null:
		return false
	var lvl := int(run_state.damage_aura_upgrade_level)
	if lvl <= 0:
		return false
	_refund_cost(get_upgrade_cost_info(lvl - 1))
	run_state.damage_aura_upgrade_level -= 1
	return true


func can_buy_energy_orb_magnet_upgrade() -> bool:
	var run_state := get_run_state()
	if run_state == null:
		return false
	if not _has_attraction_prerequisite():
		return false
	if int(run_state.energy_orb_magnet_upgrade_level) >= UpgradeDefinitions.MAX_ENERGY_ORB_MAGNET_UPGRADE_LEVEL:
		return false
	return _can_pay_upgrade_cost(int(run_state.energy_orb_magnet_upgrade_level))


func get_next_energy_orb_magnet_upgrade_cost() -> int:
	var run_state := get_run_state()
	if run_state == null:
		return 0
	return _get_total_cost(int(run_state.energy_orb_magnet_upgrade_level), UpgradeDefinitions.MAX_ENERGY_ORB_MAGNET_UPGRADE_LEVEL)


func buy_energy_orb_magnet_upgrade() -> bool:
	var run_state := get_run_state()
	if run_state == null:
		return false
	if not can_buy_energy_orb_magnet_upgrade():
		return false
	if not _pay_upgrade_cost(int(run_state.energy_orb_magnet_upgrade_level)):
		return false
	run_state.energy_orb_magnet_upgrade_level += 1
	return true


func downgrade_energy_orb_magnet_upgrade() -> bool:
	var run_state := get_run_state()
	if run_state == null:
		return false
	var lvl := int(run_state.energy_orb_magnet_upgrade_level)
	if lvl <= 0:
		return false
	_refund_cost(get_upgrade_cost_info(lvl - 1))
	run_state.energy_orb_magnet_upgrade_level -= 1
	return true


func can_buy_damage_aura_upgrade() -> bool:
	var run_state := get_run_state()
	if run_state == null:
		return false
	if not _has_attraction_prerequisite():
		return false
	if int(run_state.damage_aura_upgrade_level) >= UpgradeDefinitions.MAX_DAMAGE_AURA_UPGRADE_LEVEL:
		return false
	return _can_pay_upgrade_cost(int(run_state.damage_aura_upgrade_level))


func get_next_damage_aura_upgrade_cost() -> int:
	var run_state := get_run_state()
	if run_state == null:
		return 0
	return _get_total_cost(int(run_state.damage_aura_upgrade_level), UpgradeDefinitions.MAX_DAMAGE_AURA_UPGRADE_LEVEL)


func buy_damage_aura_upgrade() -> bool:
	var run_state := get_run_state()
	if run_state == null:
		return false
	if not can_buy_damage_aura_upgrade():
		return false
	if not _pay_upgrade_cost(int(run_state.damage_aura_upgrade_level)):
		return false
	run_state.damage_aura_upgrade_level += 1
	return true


func can_buy_orbit_mode_upgrade() -> bool:
	var run_state := get_run_state()
	if run_state == null:
		return false
	if not _has_attraction_prerequisite():
		return false
	if int(run_state.orbit_mode_upgrade_level) >= UpgradeDefinitions.MAX_ORBIT_MODE_UPGRADE_LEVEL:
		return false
	return _can_pay_specific_cost(get_orbit_mode_upgrade_cost_info(int(run_state.orbit_mode_upgrade_level)))


func get_next_orbit_mode_upgrade_cost() -> int:
	var run_state := get_run_state()
	if run_state == null:
		return 0
	return _get_specific_total_cost(get_orbit_mode_upgrade_cost_info(int(run_state.orbit_mode_upgrade_level)))


func buy_orbit_mode_upgrade() -> bool:
	var run_state := get_run_state()
	if run_state == null:
		return false
	if not can_buy_orbit_mode_upgrade():
		return false
	if not _pay_specific_cost(get_orbit_mode_upgrade_cost_info(int(run_state.orbit_mode_upgrade_level))):
		return false
	run_state.orbit_mode_upgrade_level += 1
	return true


func downgrade_orbit_mode_upgrade() -> bool:
	var run_state := get_run_state()
	if run_state == null:
		return false
	var lvl := int(run_state.orbit_mode_upgrade_level)
	if lvl <= 0:
		return false
	_refund_cost(get_orbit_mode_upgrade_cost_info(lvl - 1))
	run_state.orbit_mode_upgrade_level -= 1
	return true


func can_buy_crit_chance_upgrade() -> bool:
	var run_state := get_run_state()
	if run_state == null:
		return false
	if not _has_attraction_prerequisite():
		return false
	if int(run_state.crit_chance_upgrade_level) >= UpgradeDefinitions.MAX_CRIT_CHANCE_UPGRADE_LEVEL:
		return false
	return _can_pay_upgrade_cost(int(run_state.crit_chance_upgrade_level))


func get_next_crit_chance_upgrade_cost() -> int:
	var run_state := get_run_state()
	if run_state == null:
		return 0
	return _get_total_cost(int(run_state.crit_chance_upgrade_level), UpgradeDefinitions.MAX_CRIT_CHANCE_UPGRADE_LEVEL)


func buy_crit_chance_upgrade() -> bool:
	var run_state := get_run_state()
	if run_state == null:
		return false
	if not can_buy_crit_chance_upgrade():
		return false
	if not _pay_upgrade_cost(int(run_state.crit_chance_upgrade_level)):
		return false
	run_state.crit_chance_upgrade_level += 1
	return true


func downgrade_crit_chance_upgrade() -> bool:
	var run_state := get_run_state()
	if run_state == null:
		return false
	var lvl := int(run_state.crit_chance_upgrade_level)
	if lvl <= 0:
		return false
	_refund_cost(get_upgrade_cost_info(lvl - 1))
	run_state.crit_chance_upgrade_level -= 1
	return true


func can_toggle_developer_mode() -> bool:
	var run_state := get_run_state()
	return run_state != null


func toggle_developer_mode() -> bool:
	var run_state := get_run_state()
	if run_state == null:
		return false
	if bool(run_state.developer_mode_enabled):
		# Kapat — gerçek değerlere geri dön
		run_state.iron    = int(run_state.iron_before_dev)
		run_state.gold    = int(run_state.gold_before_dev)
		run_state.crystal = int(run_state.crystal_before_dev)
		run_state.uranium = int(run_state.uranium_before_dev)
		run_state.developer_mode_enabled = false
		var player := get_player()
		if player != null:
			player.set("iron",    run_state.iron)
			player.set("gold",    run_state.gold)
			player.set("crystal", run_state.crystal)
			player.set("uranium", run_state.uranium)
		return true
	# Aç — önce gerçek değerleri kaydet
	run_state.iron_before_dev    = run_state.iron
	run_state.gold_before_dev    = run_state.gold
	run_state.crystal_before_dev = run_state.crystal
	run_state.uranium_before_dev = run_state.uranium
	run_state.iron    += UpgradeDefinitions.DEVELOPER_MODE_IRON_REWARD
	run_state.gold    += UpgradeDefinitions.DEVELOPER_MODE_GOLD_REWARD
	run_state.crystal += UpgradeDefinitions.DEVELOPER_MODE_CRYSTAL_REWARD
	run_state.developer_mode_enabled = true
	var player := get_player()
	if player != null:
		player.set("iron",    run_state.iron)
		player.set("gold",    run_state.gold)
		player.set("crystal", run_state.crystal)
		player.set("uranium", run_state.uranium)
	return true
