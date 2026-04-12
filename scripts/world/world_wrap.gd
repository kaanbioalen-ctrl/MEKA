## WorldWrap — Seamless wrap-around utility for toroidal world boundaries.
##
## Tüm entityler (player, asteroid, enemy) bu tek helper üzerinden wrap eder.
## Black hole kasıtlı olarak bounce kullanmaya devam eder (tasarım kararı).
##
## Kullanım:
##   # Pozisyon wrap — fposmod tabanlı, negatif koordinatlarda da doğru çalışır
##   if WorldWrap.needs_wrap(global_position, bounds):
##       global_position = WorldWrap.apply(global_position, bounds)
##
##   # Orbit/follow için en kısa yol
##   var target := WorldWrap.closest_wrapped_target(my_pos, player_pos, bounds)
class_name WorldWrap
extends RefCounted


## [param pos]'u [param bounds] içine wrap eder.
## fposmod kullanır — negatif değerler ve bounds.end ötesi koordinatlar doğru işlenir.
static func apply(pos: Vector2, bounds: Rect2) -> Vector2:
	var size := bounds.size
	if size.x <= 0.0 or size.y <= 0.0:
		return pos
	var local := pos - bounds.position
	return bounds.position + Vector2(fposmod(local.x, size.x), fposmod(local.y, size.y))


## [param pos] bounds dışındaysa [code]true[/code] döner.
## apply() çağrısından önce gereksiz fposmod hesabını atlamak için kullanılır.
static func needs_wrap(pos: Vector2, bounds: Rect2) -> bool:
	var local := pos - bounds.position
	return (
		local.x < 0.0 or local.x >= bounds.size.x
		or local.y < 0.0 or local.y >= bounds.size.y
	)


## Orbit ve follow sistemleri için [param target]'ın [param origin]'e en yakın
## wrap kopyasını döner. Tüm 8 komşu offset kontrol edilir, böylece follow
## mantığı dünya sınırından geçen kısa yolu alır, uzun yolu değil.
static func closest_wrapped_target(origin: Vector2, target: Vector2, bounds: Rect2) -> Vector2:
	var size := bounds.size
	if size.x <= 0.0 or size.y <= 0.0:
		return target
	var best    := target
	var best_sq := origin.distance_squared_to(target)
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var candidate := target + Vector2(float(dx) * size.x, float(dy) * size.y)
			var sq        := origin.distance_squared_to(candidate)
			if sq < best_sq:
				best_sq = sq
				best    = candidate
	return best
