class_name GardenNavigation
extends RefCounted

const CELL: float = 8.0
var grid := AStarGrid2D.new()
var polygon := PackedVector2Array()
var holes: Array[PackedVector2Array] = []
var free_cells: Array[Vector2i] = []
var zone: int = 1

func configure(value: int) -> void:
	zone = value
	holes.clear()
	if zone==1:
		polygon = PackedVector2Array([Vector2(0,342),Vector2(75,304),Vector2(160,290),Vector2(278,289),Vector2(347,298),Vector2(396,321),Vector2(468,331),Vector2(540,350),Vector2(540,400),Vector2(486,420),Vector2(476,449),Vector2(517,481),Vector2(531,514),Vector2(502,556),Vector2(470,594),Vector2(438,623),Vector2(391,664),Vector2(344,703),Vector2(294,740),Vector2(257,726),Vector2(236,696),Vector2(216,671),Vector2(188,648),Vector2(180,621),Vector2(153,598),Vector2(139,573),Vector2(141,545),Vector2(125,524),Vector2(112,501),Vector2(116,475),Vector2(133,452),Vector2(100,432),Vector2(74,418),Vector2(40,398),Vector2(0,391)])
		holes.append(PackedVector2Array([Vector2(273,485),Vector2(391,478),Vector2(454,499),Vector2(459,539),Vector2(429,580),Vector2(354,603),Vector2(277,598),Vector2(226,565),Vector2(220,527)]))
	else:
		polygon = PackedVector2Array([Vector2(0,325),Vector2(110,308),Vector2(435,309),Vector2(540,331),Vector2(540,487),Vector2(468,541),Vector2(420,607),Vector2(346,692),Vector2(270,738),Vector2(191,691),Vector2(130,603),Vector2(65,553),Vector2(0,485)])
		if zone==2:
			polygon = PackedVector2Array([Vector2(0,365),Vector2(210,347),Vector2(248,345),Vector2(250,302),Vector2(269,302),Vector2(269,274),Vector2(178,274),Vector2(178,234),Vector2(510,234),Vector2(510,274),Vector2(425,274),Vector2(425,345),Vector2(540,380),Vector2(540,487),Vector2(468,541),Vector2(420,607),Vector2(346,692),Vector2(270,738),Vector2(191,691),Vector2(130,603),Vector2(65,553),Vector2(0,485)])
	grid.region = Rect2i(0,0,68,100)
	grid.cell_size = Vector2(CELL,CELL)
	grid.offset = Vector2(CELL/2.0,CELL/2.0)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	free_cells.clear()
	for y in range(grid.region.size.y):
		for x in range(grid.region.size.x):
			var cell := Vector2i(x,y)
			var point := Vector2(cell)*CELL+grid.offset
			var passable: bool = contains(point)
			grid.set_point_solid(cell,not passable)
			if passable:
				free_cells.append(cell)

func contains(point: Vector2) -> bool:
	if not Geometry2D.is_point_in_polygon(point,polygon):
		return false
	for hole in holes:
		if Geometry2D.is_point_in_polygon(point,hole):
			return false
	return true

func nearest_cell(point: Vector2) -> Vector2i:
	var best := Vector2i.ZERO
	var best_distance: float = INF
	for cell in free_cells:
		var distance: float = grid.get_point_position(cell).distance_squared_to(point)
		if distance<best_distance:
			best = cell
			best_distance = distance
	return best

func nearest_point(point: Vector2) -> Vector2:
	return grid.get_point_position(nearest_cell(point))

func path_between(from: Vector2,to: Vector2) -> Array[Vector2]:
	var raw: PackedVector2Array = grid.get_point_path(nearest_cell(from),nearest_cell(to))
	var result: Array[Vector2] = []
	# Simplify only when every intermediate point stays on the actual mask.
	var anchor: Vector2 = from
	var index: int = 1
	while index<raw.size():
		var farthest: int = index
		while farthest+1<raw.size() and segment_clear(anchor,raw[farthest+1]):
			farthest += 1
		result.append(raw[farthest])
		anchor = raw[farthest]
		index = farthest+1
	return result

func segment_clear(from: Vector2,to: Vector2) -> bool:
	var steps: int = maxi(1,int(ceil(from.distance_to(to)/2.0)))
	for i in range(steps+1):
		var point: Vector2 = from.lerp(to,float(i)/float(steps))
		var cell := Vector2i(floori(point.x/CELL),floori(point.y/CELL))
		if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell) or not contains(point):
			return false
	return true
