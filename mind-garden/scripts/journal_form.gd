extends VBoxContainer

signal submitted(states: Dictionary,deeds: Array,note: String,event_id: int)
signal draft_changed(value: Dictionary)
signal history_requested

const BODY: Font = preload("res://assets/Body.tres")
const PIXEL: Font = preload("res://assets/Body.tres")
const EMOTIONS := ["Тревога","Грусть","Усталость","Злость","Радость","Благодарность","Сострадание","Равностность","Сорадование","Одиночество","Растерянность","Не знаю"]
const DEEDS := ["Помогли","Узнали новое","Проявили терпение","Извинились","Позаботились о себе","Сделали подарок"]
var draft: Dictionary = {"states":{},"deeds":[],"note":""}
var editing_id: int = 0
var note: TextEdit
var intensity_rows: VBoxContainer
var sliders: Dictionary = {}

func _label(value: String,font_size: int=16) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_override("font",BODY)
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",Color("e9e0cc"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _button(value: String) -> Button:
	var b := Button.new()
	b.text = value
	b.custom_minimum_size.y = 44
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_override("font",BODY)
	b.add_theme_font_size_override("font_size",15)
	return b

func build(initial: Dictionary,event_id: int=0) -> void:
	draft = initial.duplicate(true)
	editing_id = event_id
	add_theme_constant_override("separation",12)
	add_child(_label("Что сейчас заметно?",18))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation",6)
	grid.add_theme_constant_override("v_separation",6)
	add_child(grid)
	for emotion in EMOTIONS:
		var b := _button(emotion)
		b.toggle_mode = true
		b.button_pressed = draft.states.has(emotion)
		grid.add_child(b)
		b.toggled.connect(func(on: bool) -> void:
			if on:
				draft.states[emotion] = 50
			else:
				draft.states.erase(emotion)
			_rebuild_rows()
			_changed())
	intensity_rows = VBoxContainer.new()
	intensity_rows.add_theme_constant_override("separation",10)
	add_child(intensity_rows)
	_rebuild_rows()
	add_child(_label("Намерения и дела",18))
	var deeds_grid := GridContainer.new()
	deeds_grid.columns = 2
	deeds_grid.add_theme_constant_override("h_separation",6)
	deeds_grid.add_theme_constant_override("v_separation",6)
	add_child(deeds_grid)
	for deed in DEEDS:
		var b := _button(deed)
		b.toggle_mode = true
		b.button_pressed = deed in draft.deeds
		deeds_grid.add_child(b)
		b.toggled.connect(func(on: bool) -> void:
			if on and not deed in draft.deeds:
				draft.deeds.append(deed)
			elif not on:
				draft.deeds.erase(deed)
			_changed())
	add_child(_label("Несколько слов",18))
	note = TextEdit.new()
	note.custom_minimum_size.y = 110
	note.text = draft.note
	note.placeholder_text = "Что произошло? Что удалось заметить?"
	note.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	note.add_theme_font_override("font",BODY)
	note.add_theme_font_size_override("font_size",18)
	add_child(note)
	note.text_changed.connect(func() -> void:
		draft.note = note.text.left(2000)
		_changed())
	var save := _button("Сохранить изменения" if event_id>0 else "Сохранить запись")
	save.add_theme_font_override("font",PIXEL)
	save.add_theme_font_size_override("font_size",19)
	save.pressed.connect(func() -> void: submitted.emit(draft.states,draft.deeds,draft.note,editing_id))
	add_child(save)
	var history := _button("История записей")
	history.pressed.connect(func() -> void: history_requested.emit())
	add_child(history)

func _rebuild_rows() -> void:
	for child in intensity_rows.get_children():
		intensity_rows.remove_child(child)
		child.queue_free()
	sliders.clear()
	for emotion in draft.states:
		var row := VBoxContainer.new()
		intensity_rows.add_child(row)
		var caption := _label("%s · %d%%" % [emotion,int(draft.states[emotion])])
		row.add_child(caption)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.value = draft.states[emotion]
		slider.custom_minimum_size.y = 38
		row.add_child(slider)
		sliders[emotion] = slider
		slider.value_changed.connect(func(value: float) -> void:
			draft.states[emotion] = int(value)
			caption.text = "%s · %d%%" % [emotion,int(value)]
			_changed())

func _changed() -> void:
	draft_changed.emit(draft.duplicate(true))
