extends Control
signal value_changed(minutes: int)
const FONT: Font = preload("res://assets/Body.tres")
var value: int = 5
var offset: float = 0
var dragging := false
var previous_y: float = 0

func _ready() -> void:
	custom_minimum_size = Vector2(0,156)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	focus_mode = Control.FOCUS_ALL

func set_value(minutes: int) -> void:
	value = clampi(minutes,1,120)
	offset = 0
	value_changed.emit(value)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP and event.pressed:
			set_value(value-1)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			set_value(value+1)
		elif event.button_index==MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			previous_y = event.position.y
			if not dragging:
				set_value(value-int(round(offset/40.0)))
	elif event is InputEventMouseMotion and dragging:
		offset += event.position.y-previous_y
		previous_y = event.position.y
		while absf(offset)>=40:
			var step: int = -1 if offset>0 else 1
			value = clampi(value+step,1,120)
			offset += step*40
			value_changed.emit(value)
	elif event is InputEventKey and event.pressed:
		if event.keycode==KEY_UP:
			set_value(value-1)
		elif event.keycode==KEY_DOWN:
			set_value(value+1)
	queue_redraw()
	accept_event()

func _draw() -> void:
	draw_style_box(_panel(),Rect2(Vector2.ZERO,size))
	draw_rect(Rect2(8,57,size.x-16,42),Color("35413f"))
	for i in range(-2,3):
		var n: int = value+i
		if n<1 or n>120:
			continue
		var text_value := "%d мин" % n
		var fs: int = 32 if i==0 else 20
		var text_size: Vector2 = FONT.get_string_size(text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,fs)
		draw_string(FONT,Vector2((size.x-text_size.x)/2,90+i*40+offset),text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color("f3d4a5") if i==0 else Color("858b89"))

func _panel() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("142221")
	s.border_color = Color("667064")
	s.set_border_width_all(1)
	return s
