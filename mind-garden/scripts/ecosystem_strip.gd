extends Control
signal selected(kind: String)
const FONT: Font = preload("res://assets/Body.tres")
var world: Node2D
var categories: Array[String] = ["flowers","water","fruit","fireflies"]
var titles: Array[String] = ["Цветы","Вода","Плоды","Светлячки"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(world):
		return
	var counts: Dictionary = world.ecosystem_counts()
	var card_width: float = size.x/4.0
	for i in range(4):
		var x: float = float(i)*card_width
		var panel := StyleBoxFlat.new()
		panel.bg_color = Color("1d302b")
		panel.border_color = Color("546652")
		panel.set_border_width_all(1)
		panel.set_corner_radius_all(5)
		draw_style_box(panel,Rect2(x+3,0,card_width-6,size.y))
		var point := Vector2(x+32,27)
		if i<2:
			var source: Rect2 = world.flora_rects[2 if i==0 else 26]
			var height: float = 30*source.size.y/maxf(1,source.size.x)
			draw_texture_rect_region(world.flora,Rect2(point-Vector2(15,height/2),Vector2(30,height)),source)
		elif i==2:
			draw_rect(Rect2(point-Vector2(9,7),Vector2(18,18)),Color("d9a161"))
			draw_rect(Rect2(point+Vector2(-1,-13),Vector2(3,7)),Color("8aaa74"))
			draw_rect(Rect2(point+Vector2(-6,-5),Vector2(4,4)),Color("f6d39a"))
		else:
			draw_rect(Rect2(point-Vector2(5,5),Vector2(10,10)),Color("f5d991"))
			draw_rect(Rect2(point+Vector2(-11,-1),Vector2(4,2)),Color("91a6a3"))
			draw_rect(Rect2(point+Vector2(8,-1),Vector2(4,2)),Color("91a6a3"))
		draw_string(FONT,Vector2(x+63,35),str(counts[categories[i]]),HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("f0e5ce"))
		var title_width: float = FONT.get_string_size(titles[i],HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
		draw_string(FONT,Vector2(x+(card_width-title_width)/2,68),titles[i],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("d0d3be"))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		var index: int = clampi(floori(event.position.x/(size.x/4.0)),0,3)
		selected.emit(categories[index])
		accept_event()
