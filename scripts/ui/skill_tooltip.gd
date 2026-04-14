extends Control
class_name SkillTooltip

const TOOLTIP_W: float = 268.0
const PAD: float = 14.0
const MOUSE_OFFSET: Vector2 = Vector2(20.0, 14.0)
const FADE_SPEED: float = 12.0

var _alpha: float = 0.0
var _target: float = 0.0

var _box: StyleBoxFlat = null
var _vbox: VBoxContainer = null
var _lbl_name: Label = null
var _lbl_level: Label = null
var _lbl_desc: Label = null
var _lbl_effect: Label = null
var _sep: HSeparator = null
var _lbl_cost: Label = null
var _lbl_req: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	modulate.a = 0.0
	custom_minimum_size = Vector2(TOOLTIP_W, 0.0)
	_build_layout()
	set_process(true)


func _build_layout() -> void:
	_box = StyleBoxFlat.new()
	_box.bg_color = Color(0.05, 0.08, 0.15, 0.95)
	_box.set_border_width_all(1)
	_box.border_color = Color(0.30, 0.58, 0.90, 0.80)
	_box.set_corner_radius_all(9)
	_box.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	_box.shadow_size = 8
	add_theme_stylebox_override("panel", _box)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 4)
	add_child(_vbox)

	_lbl_name = _add_label(15, Color(0.88, 0.96, 1.0, 1.0), false)
	_lbl_level = _add_label(11, Color(0.58, 0.82, 0.98, 0.90), false)
	_lbl_desc = _add_label(12, Color(0.76, 0.85, 0.94, 0.85), true)
	_lbl_effect = _add_label(12, Color(0.48, 1.0, 0.70, 0.90), false)
	_sep = HSeparator.new()
	_sep.add_theme_color_override("color", Color(0.28, 0.45, 0.68, 0.55))
	_vbox.add_child(_sep)
	_lbl_cost = _add_label(13, Color(1.0, 0.84, 0.38, 1.0), false)
	_lbl_req = _add_label(11, Color(0.88, 0.50, 0.42, 0.88), false)


func _add_label(sz: int, col: Color, wrap: bool) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vbox.add_child(l)
	return l


func show_for(skill_id: String, cfg: Dictionary, state: Dictionary, mouse_pos: Vector2, screen_sz: Vector2) -> void:
	_fill(skill_id, cfg, state)
	_reposition(mouse_pos, screen_sz)
	_alpha = 1.0
	modulate.a = 1.0
	_target = 1.0


func hide_tooltip() -> void:
	_target = 0.0


func _fill(skill_id: String, cfg: Dictionary, state: Dictionary) -> void:
	var name_str := str(cfg.get("label", skill_id)).replace("\n", " ")
	_lbl_name.text = name_str

	var level := int(state.get("level", 0))
	var max_lvl := int(state.get("max_level", 1))
	var locked := bool(state.get("locked", true))
	var can_buy := bool(state.get("can_buy", false))
	var cost_s := str(state.get("cost_text", ""))

	if locked:
		_lbl_level.text = "Durum: Kilitli"
		_lbl_level.add_theme_color_override("font_color", Color(0.75, 0.40, 0.36, 0.90))
	elif max_lvl <= 1 and level >= 1:
		_lbl_level.text = "Durum: ACILDI"
		_lbl_level.add_theme_color_override("font_color", Color(0.42, 1.0, 0.60, 0.90))
	elif level >= max_lvl:
		_lbl_level.text = "Seviye: %d / %d  MAX" % [level, max_lvl]
		_lbl_level.add_theme_color_override("font_color", Color(1.0, 0.90, 0.30, 0.95))
	else:
		_lbl_level.text = "Seviye: %d / %d" % [level, max_lvl]
		_lbl_level.add_theme_color_override("font_color", Color(0.58, 0.82, 0.98, 0.90))

	_lbl_desc.text = _description(skill_id)
	_lbl_effect.text = _effect_text(skill_id, level)
	_lbl_effect.visible = not _lbl_effect.text.is_empty()

	if can_buy and not cost_s.is_empty():
		_lbl_cost.text = "Maliyet: %s" % cost_s
		_lbl_cost.visible = true
	else:
		_lbl_cost.visible = false

	if locked:
		_lbl_req.text = "Gereksinim: Once cekirdek becerisini ac"
		_lbl_req.visible = true
	else:
		_lbl_req.visible = false

	_vbox.position = Vector2(PAD, PAD)
	_vbox.size.x = TOOLTIP_W - PAD * 2.0
	_vbox.custom_minimum_size.x = TOOLTIP_W - PAD * 2.0
	size = Vector2(TOOLTIP_W, 0.0)


func _reposition(mouse_pos: Vector2, screen_sz: Vector2) -> void:
	var est_h := 170.0
	var pos := mouse_pos + MOUSE_OFFSET
	if pos.x + TOOLTIP_W + PAD > screen_sz.x:
		pos.x = mouse_pos.x - TOOLTIP_W - MOUSE_OFFSET.x
	if pos.y + est_h + PAD > screen_sz.y:
		pos.y = screen_sz.y - est_h - PAD
	pos.x = clampf(pos.x, PAD, screen_sz.x - TOOLTIP_W - PAD)
	pos.y = clampf(pos.y, PAD, screen_sz.y - est_h - PAD)
	position = pos


func _process(delta: float) -> void:
	if not is_equal_approx(_alpha, _target):
		_alpha = move_toward(_alpha, _target, FADE_SPEED * delta)
		modulate.a = _alpha


func _description(id: String) -> String:
	if id.begins_with("bh_placeholder_"):
		return "Karadelik kozmosunun daha derin katmanlarinda yer alan ileri singularity yetenegi.\nBu dugum daha sonra acilacak."
	match id:
		"energy_field":
			return "Etrafindaki mineralleri otomatik ceker.\nTemel beceri â€” once bunu acman gerekir."
		"mining":
			return "Madencilik hasarini ve verimini arttirir."
		"mining_speed":
			return "Madencilik darbe intervalini azaltir, daha hizli kaynak kazanirsin."
		"damage_aura":
			return "Karakterin etrafinda hasar alani olusturur."
		"drop_collection":
			return "[P] tusu ile etrafindaki droplari hizlica ceker."
		"orbit_mode":
			return "Asteroidleri yörüngeye alarak kontrol edebilirsin."
		"crit_chance":
			return "Mining darbelerine kritik vurma sansi ekler. Kritik vuruslar normal hasarin 2 katini verir."
		"laser_duration":
			return "Silia lazerinin aktif kalma suresini uzatir. Her seviyede lazer vurus zamani %10 artar."
		"dual_laser":
			return "Silia sisteminin ayni anda iki ayri kume lazeri olusturmasini saglar."
		"energy_orb_magnet":
			return "Enerji orb cekim mesafesini her seviyede 1.5 kat buyutur."
		"bh_core":
			return "Karadeligin ana cekirdegi. Dis halkalardaki tum singularity becerileri buradan dallanir."
		"bh_gravity_well":
			return "Karadeligin cekim kuvvetini artirir. Asteroidler daha uzak mesafeden daha sert iceri kirilir."
		"bh_event_horizon":
			return "Etkilesim ufkunu genisletir. Karadelik daha genis alani kontrol eder."
		"bh_accretion":
			return "Kaynaklarin enerjiye donusum verimini artirir. Her cevrim daha fazla black hole enerjisi uretir."
		"bh_singularity_drive":
			return "Karadeligin haritadaki avlanma temposunu artirir. Daha cevik gezer, daha hizli toplar."
	return ""


func _effect_text(id: String, level: int) -> String:
	if id.begins_with("bh_placeholder_"):
		return "Durum: taslak dugum"
	match id:
		"mining":
			return "Madencilik bonusu: +%d%%" % (level * 15)
		"mining_speed":
			var intervals: Array[float] = [2.2, 2.0, 1.9, 1.8, 1.7, 1.6, 1.4]
			return "Darbe araligi: %.1f sn" % intervals[clampi(level, 0, intervals.size() - 1)]
		"damage_aura":
			return "Hasar alani: %d px" % (100 + level * 40)
		"orbit_mode":
			return "Yörünge kapasitesi: %d asteroid" % maxi(1, level)
		"crit_chance":
			return "Kritik sansi: %d%%" % roundi(level * 3.0)
		"laser_duration":
			return "Lazer sure bonusu: +%d%%" % int(level * 10)
		"dual_laser":
			return "Eszamanli lazer sayisi: %d" % (1 + level)
		"energy_orb_magnet":
			return "Orb cekim carpani: x%.1f" % pow(1.5, float(level))
		"bh_gravity_well":
			return "Cekim kuvveti: +%d" % int(level * 48)
		"bh_event_horizon":
			return "Ufuk bonusu: +%d%%" % int(level * 22)
		"bh_accretion":
			return "Donusum verimi: +%d%%" % int(level * 20)
		"bh_singularity_drive":
			return "Hareket bonusu: +%d" % int(level * 16)
		"bh_core":
			return "Harcanabilir enerjiyle singularity becerileri satin alabilirsin."
	return ""
