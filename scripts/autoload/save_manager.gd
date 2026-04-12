extends Node

const SAVE_PATH := "user://progress.json"


func save_exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func write_save(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: Dosya yazılamadı: %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func read_save() -> Dictionary:
	if not save_exists():
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_warning("SaveManager: Kayıt dosyası okunamadı veya bozuk.")
	return {}


func delete_save() -> void:
	if not save_exists():
		return
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.remove("progress.json")


func build_save_data(player: Node, run_state: Node) -> Dictionary:
	var data: Dictionary = {}
	if player != null:
		data["iron"]    = int(player.get("iron"))
		data["gold"]    = int(player.get("gold"))
		data["crystal"] = int(player.get("crystal"))
		data["uranium"] = int(player.get("uranium"))
		data["titanium"] = int(player.get("titanium"))
	elif run_state != null:
		data["iron"]    = int(run_state.iron)
		data["gold"]    = int(run_state.gold)
		data["crystal"] = int(run_state.crystal)
		data["uranium"] = int(run_state.uranium)
		data["titanium"] = int(run_state.titanium)
	if run_state != null:
		data["mining_upgrade_level"]       = int(run_state.mining_upgrade_level)
		data["mining_speed_upgrade_level"] = int(run_state.mining_speed_upgrade_level)
		data["energy_field_upgrade_level"] = int(run_state.energy_field_upgrade_level)
		data["energy_orb_magnet_upgrade_level"] = int(run_state.energy_orb_magnet_upgrade_level)
		data["damage_aura_upgrade_level"]  = int(run_state.damage_aura_upgrade_level)
		data["orbit_mode_upgrade_level"]   = int(run_state.orbit_mode_upgrade_level)
		data["crit_chance_upgrade_level"]  = int(run_state.crit_chance_upgrade_level)
		data["attraction_skill_unlocked"]  = bool(run_state.attraction_skill_unlocked)
		data["drop_collection_skill_unlocked"] = bool(run_state.drop_collection_skill_unlocked)
		data["blackhole_level"] = int(run_state.blackhole_level)
		data["blackhole_progress"] = float(run_state.blackhole_progress)
		data["blackhole_energy"] = float(run_state.blackhole_energy)
		data["blackhole_total_energy"] = float(run_state.blackhole_total_energy)
		data["blackhole_gravity_well_level"] = int(run_state.blackhole_gravity_well_level)
		data["blackhole_event_horizon_level"] = int(run_state.blackhole_event_horizon_level)
		data["blackhole_accretion_level"] = int(run_state.blackhole_accretion_level)
		data["blackhole_singularity_drive_level"] = int(run_state.blackhole_singularity_drive_level)
	return data


func has_progress(data: Dictionary) -> bool:
	for val in data.values():
		if int(val) > 0:
			return true
	return false
