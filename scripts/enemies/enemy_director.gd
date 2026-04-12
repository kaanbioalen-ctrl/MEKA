## EnemyDirector — RunState.run_time bazlı zorluk tırmanması.
##
## Fazlara göre worm sayısı, hız ve dönüş hızını belirler.
## WormSpawner referansı üzerinden spawner'a hedef değerleri yazar.
## Faz değişimi anında tüm mevcut worm'ların hızı da güncellenir.
extends Node
class_name EnemyDirector

## Director'ın kaç saniyede bir yeniden değerlendireceği
@export_range(1.0, 30.0, 0.5) var eval_interval: float = 5.0

## [run_time_threshold, max_worms, move_speed, turn_speed]
const PHASES: Array[Array] = [
	[0.0,    0,  135.0, 3.2],   # 0-60s   : worm yok
	[60.0,   1,  115.0, 2.8],   # 1-2 dk  : 1 yavaş
	[120.0,  2,  130.0, 3.0],   # 2-3 dk  : 2 normal
	[180.0,  3,  148.0, 3.4],   # 3-5 dk  : 3 biraz hızlı
	[300.0,  4,  165.0, 3.7],   # 5-8 dk  : 4 hızlı
	[480.0,  5,  182.0, 4.1],   # 8-10 dk : 5 çok hızlı
	[600.0,  6,  200.0, 4.5],   # 10dk+   : 6 maksimum
]

var _worm_spawner: Node = null
var _eval_timer: float = 0.0
var _current_phase_idx: int = -1


func configure(worm_spawner: Node) -> void:
	_worm_spawner = worm_spawner
	_eval_timer = 0.0
	_current_phase_idx = -1
	_evaluate_difficulty()


func _process(delta: float) -> void:
	_eval_timer -= delta
	if _eval_timer > 0.0:
		return
	_eval_timer = eval_interval
	_evaluate_difficulty()


func get_current_move_speed() -> float:
	if _current_phase_idx < 0:
		return float(PHASES[0][2])
	return float(PHASES[_current_phase_idx][2])


func get_current_turn_speed() -> float:
	if _current_phase_idx < 0:
		return float(PHASES[0][3])
	return float(PHASES[_current_phase_idx][3])


## Aktif worm'ların hızını anlık olarak günceller (faz geçişinde çağrılır).
func refresh_live_worm_stats() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var speed := get_current_move_speed()
	var turn  := get_current_turn_speed()
	for worm in tree.get_nodes_in_group("worm_enemy"):
		if is_instance_valid(worm):
			worm.set("move_speed", speed)
			worm.set("turn_speed", turn)


func _evaluate_difficulty() -> void:
	var run_state := get_node_or_null("/root/RunState")
	if run_state == null or not bool(run_state.get("active")):
		return

	var run_time: float = float(run_state.get("run_time"))
	var new_idx := _get_phase_index(run_time)

	if new_idx == _current_phase_idx:
		return

	_current_phase_idx = new_idx
	_apply_phase(PHASES[new_idx])


func _get_phase_index(run_time: float) -> int:
	var best := 0
	for i in range(PHASES.size()):
		if run_time >= float(PHASES[i][0]):
			best = i
	return best


func _apply_phase(phase: Array) -> void:
	var count: int   = int(phase[1])
	var speed: float = float(phase[2])
	var turn:  float = float(phase[3])

	if _worm_spawner != null and is_instance_valid(_worm_spawner):
		_worm_spawner.set("target_max_count", count)
		if _worm_spawner.has_method("set_spawn_overrides"):
			_worm_spawner.call("set_spawn_overrides", speed, turn)

	refresh_live_worm_stats()

	print(
		"[EnemyDirector] Faz %d → worm=%d hız=%.0f dönüş=%.1f (run_time=%.0fs)"
		% [_current_phase_idx, count, speed, turn, float(
			get_node_or_null("/root/RunState").get("run_time") if get_node_or_null("/root/RunState") != null else 0.0
		)]
	)
