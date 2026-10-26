extends Control
var kind: String = "left"
var active: bool = true
var ink := Color("f2e3c8")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var center: Vector2 = size/2.0
	if kind in ["left","right"]:
		var direction: float = -1 if kind=="left" else 1
		for i in range(5):
			var point := center+Vector2(direction*(10-i*4),-i*4)
			draw_rect(Rect2(point,Vector2(6,6)),ink)
			if i>0:
				draw_rect(Rect2(center+Vector2(direction*(10-i*4),i*4),Vector2(6,6)),ink)
	elif kind=="sound":
		draw_rect(Rect2(center+Vector2(-14,-6),Vector2(6,12)),ink)
		draw_polygon(PackedVector2Array([center+Vector2(-8,-6),center+Vector2(2,-14),center+Vector2(2,14),center+Vector2(-8,6)]),PackedColorArray([ink]))
		if active:
			for i in range(3):
				draw_rect(Rect2(center+Vector2(7+i*4,-5-i*3),Vector2(3,10+i*6)),Color(ink,0.95-float(i)*0.16))
		else:
			for i in range(8):
				draw_rect(Rect2(center+Vector2(-13+i*4,13-i*4),Vector2(4,4)),Color("e5ac88"))
