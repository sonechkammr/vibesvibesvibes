extends Node2D
signal place_pressed(place: String)
signal navigate_requested(destination: int)
signal seated
const Nav = preload("res://scripts/garden_navigation.gd")
const Day = preload("res://scripts/day_cycle.gd")
const PLAYER_SPEED: float = 132.0
const CUSHION := Vector2(373,255)
const BOWL := Vector2(447,239)
const SIZE := Vector2(540,960)
var model: GardenState
var zone: int = 1
var player := Vector2(264,444)
var cat := Vector2(335,465)
var cat_target := Vector2(335,465)
var cat_route: Array[Vector2] = []
var cat_wait: float = 3
var cat_distance: float = 0
var cat_facing: int = 2
var meditating := false
var pose: String = "idle"
var pose_time: float = 0
var facing: int = 0
var distance_walked: float = 0
var route: Array[Vector2] = []
var route_action: String = ""
var walking: bool = false
var clock: float = 0
var pointer_down := false
var pointer_start := Vector2.ZERO
var input_blocked := false
var backgrounds: Array[Texture2D] = []
var actors: Texture2D = preload("res://assets/actors.png")
var walk_texture: Texture2D = preload("res://assets/walk_cycle.png")
var walk_rects: Array[Rect2] = []
var cat_texture: Texture2D = preload("res://assets/cat_directions.png")
var cat_rects: Array[Rect2] = []
var flora: Texture2D = preload("res://assets/flora.png")
var actor_rects: Array[Rect2] = []
var flora_rects: Array[Rect2] = []
var navigation := Nav.new()
var background_node: Sprite2D
var light_material: ShaderMaterial
var preview_hour: float = -1
var day_info: Dictionary = {}
var click_marker := Vector2(-100,-100)
var marker_time: float = 0
var marker_allowed := true
var highlight_kind: String = ""
var highlight_time: float = 0
var strike_age: float = -1
var strike_count: int = 0
var debug_navigation := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for scene_name in ["journal","garden","practice"]:
		backgrounds.append(load("res://assets/scene_%s.png" % scene_name))
	actor_rects = _frames(actors,6,[0,235,443,647,855,1080,1254])
	walk_rects = _frames(walk_texture,4,[0,325,633,940,1254])
	flora_rects = _frames(flora,4,[0,282,501,739,1001,1225,1414,1659])
	cat_rects = _frames(cat_texture,4,[0,350,662,955,1254])
	background_node = Sprite2D.new()
	background_node.centered = false
	background_node.region_enabled = true
	background_node.z_index = -20
	light_material = ShaderMaterial.new()
	light_material.shader = preload("res://assets/day_cycle.gdshader")
	background_node.material = light_material
	add_child(background_node)
	navigation.configure(zone)
	player = navigation.nearest_point(player)
	_set_background()
	_update_day()

func _frames(texture: Texture2D,columns: int,edges: Array) -> Array[Rect2]:
	var frames: Array[Rect2] = []
	var img := texture.get_image()
	var reference_height: float = float(edges[-1])
	for row in range(edges.size()-1):
		for col in range(columns):
			var top: int = floori(float(edges[row])*float(img.get_height())/reference_height)
			var bottom: int = floori(float(edges[row+1])*float(img.get_height())/reference_height)
			var left: int = floori(float(col)*float(img.get_width())/float(columns))
			var right: int = floori(float(col+1)*float(img.get_width())/float(columns))
			var cell := Rect2i(left,top,right-left,bottom-top)
			var used: Rect2i = img.get_region(cell).get_used_rect()
			frames.append(Rect2(cell.position+used.position,used.size))
	return frames

func _set_background() -> void:
	var texture: Texture2D = backgrounds[zone]
	background_node.texture = texture
	# Camera crop removes the unused distant panorama. Art originals stay intact.
	background_node.region_rect = Rect2(0,texture.get_height()*0.14,texture.get_width(),texture.get_height()*0.78)
	background_node.scale = Vector2(540.0/float(texture.get_width()),800.0/(float(texture.get_height())*0.78))

func set_zone(value: int,direction: float=1) -> void:
	cancel_route()
	zone = value
	navigation.configure(zone)
	player = navigation.nearest_point(Vector2(50 if direction>0 else 490,370))
	facing = 2 if direction>0 else 3
	_set_background()

func cancel_route() -> void:
	route.clear()
	route_action = ""
	walking = false
	meditating = false
	pose = "idle"
	pose_time = 0
	pointer_down = false

func go_to_cushion() -> void:
	if meditating or pose=="sit_down" or route_action=="sit":
		return
	if player.distance_to(CUSHION)<16:
		pose = "sit_down"
		pose_time = 0
		return
	walk_to(CUSHION,"sit")

func stand_up() -> void:
	route.clear()
	route_action = ""
	walking = false
	pose = "stand_up" if meditating else "idle"
	pose_time = 0
	meditating = false

func walk_to(destination: Vector2,action: String="") -> void:
	var target: Vector2 = navigation.nearest_point(destination)
	route = navigation.path_between(player,target)
	route_action = action
	meditating = false
	walking = not route.is_empty()
	pose = "walk" if walking else "idle"
	model.pattern("walks")
	click_marker = target
	marker_time = 0.6
	marker_allowed = true
	if not walking and action=="sit":
		_arrived()

func _arrived() -> void:
	walking = false
	pose = "idle"
	var action: String = route_action
	route_action = ""
	if action=="sit":
		player = CUSHION
		pose = "sit_down"
		pose_time = 0
	elif action.begins_with("exit"):
		navigate_requested.emit(zone+(-1 if action=="exit_left" else 1))

func _process(delta: float) -> void:
	clock += delta
	pose_time += delta
	marker_time = maxf(0,marker_time-delta)
	highlight_time = maxf(0,highlight_time-delta)
	if strike_age>=0:
		strike_age += delta
		if strike_age>0.65:
			strike_age = -1
	_update_day()
	var budget: float = PLAYER_SPEED*depth_scale(player.y)*delta
	while walking and not route.is_empty() and budget>0:
		var diff: Vector2 = route[0]-player
		var travel: float = minf(diff.length(),budget)
		if travel>0.001:
			facing = (2 if diff.x>0 else 3) if absf(diff.x)>absf(diff.y) else (0 if diff.y>0 else 1)
			player += diff.normalized()*travel
			distance_walked += travel
		budget -= travel
		if player.distance_to(route[0])<0.1:
			route.pop_front()
		if route.is_empty():
			_arrived()
	if pose=="sit_down" and pose_time>0.7:
		pose = "seated"
		meditating = true
		seated.emit()
	elif pose=="stand_up" and pose_time>0.6:
		pose = "idle"
	if zone==1:
		_cat_process(delta)
	queue_redraw()

func _cat_process(delta: float) -> void:
	cat_wait -= delta
	if cat_wait<0:
		cat_target = navigation.nearest_point(Vector2(120+fmod(clock*29,300),420+fmod(clock*17,160)))
		cat_route = navigation.path_between(cat,cat_target)
		cat_wait = 9+fmod(clock,7)
	if not cat_route.is_empty():
		var diff: Vector2 = cat_route[0]-cat
		var moved: Vector2 = cat.move_toward(cat_route[0],delta*27)
		cat_distance += cat.distance_to(moved)
		cat = moved
		if diff.length()>0.1:
			cat_facing = (2 if diff.x>0 else 3) if absf(diff.x)>absf(diff.y) else (0 if diff.y>0 else 1)
		if cat.distance_to(cat_route[0])<0.2:
			cat_route.pop_front()

func depth_scale(y: float) -> float:
	return clampf(lerpf(0.90,1.10,(y-300.0)/430.0),0.90,1.10)

func _update_day() -> void:
	var time: Dictionary = Time.get_time_dict_from_system()
	var hour: float = preview_hour if preview_hour>=0 else float(time.hour)+float(time.minute)/60.0+float(time.second)/3600.0
	day_info = Day.sample(hour)
	light_material.set_shader_parameter("daylight",day_info.light)
	light_material.set_shader_parameter("warmth",day_info.warmth)

func ecosystem_counts() -> Dictionary:
	var ground: int = 0
	var water: int = 0
	for plant in model.data.plants:
		if int(plant.species)<4:
			ground += 1
		else:
			water += 1
	return {"flowers":ground,"water":water,"fruit":mini(8,floori(float(model.data.patterns.revisions)/2.0)+floori(float(model.data.patterns.practices)/2.0)),"fireflies":particle_count() if bool(day_info.get("night",false)) else 0}

func particle_count() -> int:
	var p: Dictionary = model.data.patterns
	return mini(36,8+floori(float(model.data.traces.size())/2.0)+floori(float(p.draft_changes)/3.0)+floori(float(p.transitions)/5.0))

func highlight(kind: String) -> void:
	highlight_kind = kind
	highlight_time = 3.0

func strike() -> void:
	strike_age = 0
	strike_count += 1

func _draw() -> void:
	if backgrounds.is_empty():
		return
	var night: bool = day_info.get("night",false)
	var p: Dictionary = model.data.patterns
	var clouds: int = mini(5,1+floori(float(p.opens)/4.0)+floori(float(p.early_finishes)/3.0))
	for i in range(clouds):
		var x: float = fmod(clock*1.3+float(i)*147,700)-80
		for j in range(5):
			draw_rect(Rect2(Vector2(x+float(j)*16,60+float(i)*12+float(j%2)*4).floor(),Vector2(32,4)),Color(0.6,0.7,0.8,0.06))
	if night:
		for i in range(22):
			var point := Vector2(20+(i*71)%500,14+(i*37)%100)
			draw_rect(Rect2(point,Vector2(2,2)),Color(0.8,0.88,1,0.35+0.2*sin(clock+float(i))))
	if zone==1:
		var objects: Array[Dictionary] = []
		for plant in model.data.plants:
			objects.append({"kind":"plant","y":GardenState.SLOTS[int(plant.slot)].y,"plant":plant})
		objects.append({"kind":"player","y":player.y})
		objects.append({"kind":"cat","y":cat.y})
		objects.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.y<b.y)
		for object in objects:
			match object.kind:
				"plant": _plant(object.plant)
				"player": _player()
				"cat": _cat()
		var count: int = int(ecosystem_counts().fruit)
		for i in range(count):
			var point := Vector2(52+(i*37)%160,58+(i*23)%92)
			draw_rect(Rect2(point,Vector2(7,8)),Color("dc9b5d"))
			if highlight_time>0 and highlight_kind=="fruit":
				draw_rect(Rect2(point-Vector2(4,4),Vector2(15,16)),Color("e9d09a"),false,1)
		for i in range(6):
			var point := Vector2(379+i*19,205+(i*17)%45)
			draw_line(point,point+Vector2(10+sin(clock*1.3+float(i))*3,0),Color(0.65,0.85,0.95,0.18))
	else:
		_player()
	if zone==2:
		_draw_mallet()
	for i in range(particle_count()):
		var point := Vector2(fmod(float(i)*61+clock*(3+float(i%4))+sin(clock*0.4+float(i))*12,500)+20,160+fmod(float(i)*41+sin(clock*0.2+float(i))*30,550))
		var alpha: float = maxf(0,sin(clock*1.1+float(i)*1.7))*(0.8 if night else 0.25)
		var colors := [Color(0.95,0.78,0.42,alpha),Color(0.66,0.78,1,alpha),Color(0.97,0.64,0.83,alpha)]
		draw_rect(Rect2(point.floor(),Vector2(3,3)),colors[i%3])
		if highlight_time>0 and highlight_kind=="fireflies" and night:
			draw_rect(Rect2(point.floor()-Vector2(2,2),Vector2(7,7)),Color(0.9,0.9,0.6,0.4))
	var detail: Dictionary = model.atmosphere_detail()
	var strength: float = detail.strength
	if detail.kind in ["rain","cloud"]:
		draw_rect(Rect2(Vector2.ZERO,Vector2(540,800)),Color(0.04,0.07,0.16,strength*0.15))
	if detail.kind=="rain":
		for i in range(int(20+strength*90)):
			var point := Vector2(fmod(float(i)*73+clock*14,540),fmod(float(i)*89+clock*(90+strength*80),800))
			draw_line(point,point+Vector2(-2,6+strength*4),Color(0.7,0.8,0.95,0.12+strength*0.2))
	if debug_navigation:
		draw_colored_polygon(navigation.polygon,Color(0.1,0.9,0.3,0.23))
		for hole in navigation.holes:
			draw_colored_polygon(hole,Color(0.9,0.12,0.12,0.3))
	if marker_time>0:
		var color := Color("e4d5a4") if marker_allowed else Color("d09273")
		var radius: float = 6+(0.6-marker_time)*14
		draw_arc(click_marker,radius,0,TAU,12,Color(color,marker_time/0.6),2)

func _plant(plant: Dictionary) -> void:
	var point: Vector2 = GardenState.SLOTS[int(plant.slot)]
	var species: int = int(plant.species)
	var rect: Rect2 = flora_rects[species*4+model.phase(plant)]
	var width: float = 54 if species<4 else 55
	var height: float = width*rect.size.y/maxf(1,rect.size.x)
	var sway: float = sin(clock*1.2+point.x)*0.8
	draw_texture_rect_region(flora,Rect2(point-Vector2(width/2.0-sway,height),Vector2(width,height)),rect)
	if highlight_time>0 and ((highlight_kind=="flowers" and species<4) or (highlight_kind=="water" and species>=4)):
		draw_rect(Rect2(point-Vector2(width/2.0+4,height+4),Vector2(width+8,height+8)),Color("f4d699"),false,2)

func _draw_actor(texture: Texture2D,rect: Rect2,point: Vector2,height: float) -> void:
	var width: float = height*rect.size.x/maxf(1,rect.size.y)
	draw_set_transform(point,0,Vector2(1,0.28))
	draw_circle(Vector2.ZERO,width*0.35,Color(0.02,0.02,0.04,0.32))
	draw_set_transform(Vector2.ZERO)
	var tint := Color.WHITE.lerp(Color("9aafd0"),(1.0-float(day_info.get("light",1.0)))*0.3)
	draw_set_transform((point-Vector2(width/2.0,height)).floor())
	draw_texture_rect_region(texture,Rect2(Vector2.ZERO,Vector2(width,height)),rect,tint)
	draw_set_transform(Vector2.ZERO)

func _player() -> void:
	var point := player
	var height: float = 86*depth_scale(player.y)
	var rect: Rect2 = actor_rects[[24,6,12,18][facing]]
	var texture: Texture2D = actors
	if walking:
		rect = walk_rects[facing*4+int(distance_walked/13.0)%4]
		texture = walk_texture
	if meditating or pose=="seated":
		rect = actor_rects[28]
		point = CUSHION
		height = 76
		texture = actors
	elif pose=="sit_down":
		rect = actor_rects[25 if pose_time<0.3 else 26]
		point = CUSHION
		height = 81 if pose_time<0.3 else 76
		texture = actors
	elif pose=="stand_up":
		rect = actor_rects[29]
		height = 79
	_draw_actor(texture,rect,point,height)

func _cat() -> void:
	var frame: int = int(cat_distance/5.0)%4 if not cat_route.is_empty() else 0
	_draw_actor(cat_texture,cat_rects[cat_facing*4+frame],cat,39*depth_scale(cat.y))

func _draw_mallet() -> void:
	if strike_age<0:
		return
	var progress: float = clampf(strike_age/0.65,0,1)
	var swing: float = cos(progress*PI*0.5)
	var angle: float = lerpf(3.5,2.5,swing)
	draw_set_transform(BOWL+Vector2(40,-35),angle)
	draw_rect(Rect2(0,-2,40,4),Color("d0ae72"))
	draw_rect(Rect2(38,-4,9,8),Color("796056"))
	draw_set_transform(Vector2.ZERO)
	if progress<0.5:
		for i in range(3):
			draw_arc(BOWL,18+float(i)*7,PI,TAU,12,Color(0.95,0.83,0.52,(0.5-progress)*0.8),1)

func _unhandled_input(event: InputEvent) -> void:
	if input_blocked:
		pointer_down = false
		return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			pointer_down = true
			pointer_start = get_local_mouse_position()
		elif pointer_down:
			pointer_down = false
			gesture(pointer_start,get_local_mouse_position())

func gesture(from: Vector2,to: Vector2) -> void:
	var delta := to-from
	if absf(delta.x)>70 and absf(delta.x)>absf(delta.y)*1.5:
		navigate_requested.emit(zone+(1 if delta.x<0 else -1))
		return
	if delta.length()>20 or meditating or pose=="sit_down":
		return
	click_marker = to
	marker_time = 0.6
	marker_allowed = navigation.contains(to)
	if zone==0 and Rect2(145,160,190,112).has_point(to):
		place_pressed.emit("journal")
		return
	if zone==2 and Rect2(326,191,104,93).has_point(to):
		place_pressed.emit("meditation")
		return
	if zone==1:
		if to.distance_to(cat)<32:
			place_pressed.emit("cat")
			return
		for plant in model.data.plants:
			if to.distance_to(GardenState.SLOTS[int(plant.slot)]-Vector2(0,20))<29:
				place_pressed.emit("plant")
				return
		if Rect2(360,130,180,175).has_point(to):
			place_pressed.emit("pond")
			return
	if not navigation.contains(to):
		return
	if to.x<36 and zone>0:
		walk_to(Vector2(10,368),"exit_left")
	elif to.x>504 and zone<2:
		walk_to(Vector2(530,368),"exit_right")
	else:
		walk_to(to)
