extends SceneTree
const Nav = preload("res://scripts/garden_navigation.gd")
const Day = preload("res://scripts/day_cycle.gd")
const Model = preload("res://scripts/garden_state.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var nav := Nav.new()
	for scene_index in range(3):
		nav.configure(scene_index)
		check(nav.free_cells.size()>300,"Scene has a broad walkable area")
		check(not nav.contains(Vector2(270,80)),"Panorama is not walkable")
		var points: Array[Vector2] = [Vector2(30,430),Vector2(490,430),Vector2(160,550),Vector2(270,700),Vector2(470,570)]
		for i in range(points.size()):
			var start: Vector2 = nav.nearest_point(points[i])
			var goal: Vector2 = nav.nearest_point(points[(i+1)%points.size()])
			var route: Array[Vector2] = nav.path_between(start,goal)
			check(not route.is_empty(),"Distant positions stay connected")
			var previous := start
			var valid_route := true
			for point in route:
				valid_route = valid_route and nav.segment_clear(previous,point)
				previous = point
			check(valid_route,"Simplified route never cuts across an obstacle")
	nav.configure(1)
	for slot in Model.SLOTS:
		check(not nav.contains(slot),"Plant roots are outside walkable ground")
	check(not nav.contains(Vector2(330,540)),"Lower island bed blocks walking")
	check(nav.contains(Vector2(260,680)),"Foreground path is usable")
	nav.configure(2)
	var cushion := Vector2(373,255)
	check(nav.contains(cushion),"Cushion lies on reachable pavilion floor")
	check(not nav.path_between(nav.nearest_point(Vector2(50,430)),cushion).is_empty(),"Pavilion stairs connect with courtyard")
	var noon: Dictionary = Day.sample(12)
	var midnight: Dictionary = Day.sample(0)
	check(noon.period=="День" and midnight.period=="Ночь","Device hours select correct periods")
	check(noon.light>midnight.light+0.5,"Day and night have materially different light")
	check(Day.sample(6).warmth>0.5 and Day.sample(18.25).warmth>0.5,"Sunrise and sunset have warm light")
	check(absf(float(Day.sample(23.999).light)-float(Day.sample(0).light))<0.01,"Midnight has no lighting jump")
	check(absf(float(Day.sample(7.999).light)-float(Day.sample(8.001).light))<0.01,"Day phase boundaries are continuous")
	print("NAVIGATION/DAY %s: %d checks, %d failures" % ["PASS" if failures==0 else "FAIL",checks,failures])
	quit(0 if failures==0 else 1)
