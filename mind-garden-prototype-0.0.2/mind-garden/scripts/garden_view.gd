extends Node2D

# Interactive illustration. App functions live in the UI.
signal place_pressed(place: String)

const SIZE := Vector2(540, 960)
const PLANT_POSITIONS: Array[Vector2] = [Vector2(160, 568), Vector2(178, 587), Vector2(142, 602), Vector2(206, 633), Vector2(296, 652), Vector2(390, 607), Vector2(415, 633), Vector2(386, 674), Vector2(127, 626), Vector2(287, 577), Vector2(452, 592), Vector2(322, 689)]
var model: GardenState
var zone: int = 1
var player := Vector2(256, 660)
var cat := Vector2(310, 678)
var cat_target := Vector2(310, 678)
var cat_wait: float = 5.0
var walking: bool = false
var meditating: bool = false
var clock: float = 0.0
var weather: String = "clear"
var backgrounds: Array[Texture2D] = []
var characters: Texture2D = preload("res://assets/characters.png")
var plant_texture: Texture2D = preload("res://assets/plants.png")
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for name in ["journal", "garden", "practice"]:
		backgrounds.append(load("res://assets/scene_%s.png" % name))
	rng.seed = 17319

func _process(delta: float) -> void:
	clock += delta
	cat_wait -= delta
	if cat_wait < 0:
		cat_target = Vector2(rng.randf_range(230, 355), rng.randf_range(648, 714))
		cat_wait = rng.randf_range(8.0, 16.0)
	cat = cat.move_toward(cat_target, delta * 8.0)
	weather = model.atmosphere() if model != null else "clear"
	queue_redraw()

func _draw() -> void:
	if backgrounds.is_empty():
		return
	draw_texture_rect(backgrounds[zone], Rect2(Vector2.ZERO, SIZE), false)
	if model != null and zone == 1:
		for plant in model.data.plants:
			var point: Vector2 = PLANT_POSITIONS[int(plant.slot)]
			var stage: int = model.phase(plant)
			draw_texture_rect_region(plant_texture, Rect2(point - Vector2(9, 21), Vector2(18, 24)), Rect2(stage * 24, 0, 24, 32))
		var ripple: float = fmod(clock * 3.0, 15.0)
		draw_arc(Vector2(408, 513), ripple, 0, TAU, 18, Color(0.63, 0.72, 0.88, (1.0 - ripple / 15.0) * 0.32), 1.0)
		var age: float = float(model.data.world_age)
		for i in range(mini(14, int(age / 86400.0))):
			var p := Vector2(146 + (i * 57) % 258, 600 + (i * 23) % 100)
			draw_line(p, p + Vector2(-1,-4), Color("6f8198"))
			draw_line(p, p + Vector2(3,-3), Color("89977f"))
	var hour: int = int(Time.get_datetime_dict_from_system().hour)
	if hour >= 21 or hour < 6:
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.035, 0.055, 0.16, 0.12))
	for i in range(9):
		var p := Vector2(100 + fmod(i * 49 + sin(clock * 0.25 + i) * 8, 330), 370 + fmod(i * 39, 310))
		var alpha: float = maxf(0.0, sin(clock * 0.7 + i * 1.7)) * 0.7
		draw_rect(Rect2(p.floor(), Vector2(2, 2)), Color(0.93, 0.76, 0.51, alpha))
	if weather in ["rain", "cloud"]:
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.08, 0.10, 0.24, 0.14))
	if weather == "rain":
		for i in range(70):
			var p := Vector2(fmod(i * 73 + clock * 6, 540), fmod(i * 71 + clock * 95, 760))
			draw_line(p, p + Vector2(-2, 7), Color(0.65, 0.75, 0.9, 0.26))
	if weather == "wind":
		for i in range(7):
			var p := Vector2(fmod(clock * 25 + i * 93, 540), 230 + i * 61)
			draw_line(p, p + Vector2(12, -2), Color(0.68, 0.72, 0.86, 0.27))
	# The small player is visual, never the means of app navigation.
	var frame: int = 1 + int(clock * 5) % 2 if walking else 0
	var point: Vector2 = Vector2(386, 439) if meditating else player
	if meditating:
		draw_texture_rect_region(characters, Rect2(point - Vector2(26, 40), Vector2(52, 40)), Rect2(0, 0, 512, 395))
	elif zone == 1:
		draw_texture_rect_region(characters, Rect2(point - Vector2(26, 56), Vector2(52, 61)), Rect2(frame * 512, 0, 512, 600))
	var cat_frame: int = 1 + int(clock * 4) % 2 if cat.distance_to(cat_target) > 1 else 0
	if zone == 1:
		draw_texture_rect_region(characters, Rect2(cat.floor() - Vector2(25, 24), Vector2(50, 30)), Rect2(cat_frame * 512, 600, 512, 424))
	if zone == 2 and model != null and model.practice_seconds() > 0 and not meditating:
		draw_line(Vector2(376, 436), Vector2(395, 437), Color(0.31,0.25,0.4,0.5), 2.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = get_local_mouse_position()
		if zone != 1 or point.y < 340 or point.y > 752 or walking or meditating:
			return
		if point.distance_to(cat) < 24:
			place_pressed.emit("cat")
			return
		walking = true
		var tween := create_tween()
		var destination := Vector2(clampf(point.x, 195, 368), clampf(point.y, 626, 730))
		tween.tween_property(self, "player", destination, 0.75).set_trans(Tween.TRANS_SINE)
		tween.finished.connect(func() -> void: walking = false)
