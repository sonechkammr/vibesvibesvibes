extends Control

const FONT: Font = preload("res://assets/Interface.ttf")
const Model = preload("res://scripts/garden_state.gd")
const View = preload("res://scripts/garden_view.gd")
const INK := Color("ede9dc")
const MUTED := Color("a6adc3")
const GOLD := Color("e7c79f")
const EMOTIONS: Array[String] = ["Тревога", "Грусть", "Усталость", "Злость", "Радость", "Благодарность", "Сострадание", "Равностность", "Одиночество", "Не знаю"]
const DEEDS: Array[String] = ["Помогли", "Узнали новое", "Проявили терпение", "Извинились", "Позаботились о себе"]

var model: GardenState
var world: Node2D
var hud: Control
var overlay: ColorRect
var modal_content: VBoxContainer
var toast_box: PanelContainer
var toast_label: Label
var toast_timer: Timer
var zone_title: Label
var zone_description: Label
var status_label: Label
var action_button: Button
var journal_note: TextEdit
var selected_emotions: Array[String] = []
var selected_deed: String = ""
var intensity_slider: HSlider
var timer_seconds: int = 180
var elapsed_seconds: float = 0.0
var meditation_state: String = "idle"
var opening_elapsed: float = 0.0
var next_strike: int = 0
var timer_label: Label
var timer_hint: Label
var pause_button: Button
var bowl: AudioStreamPlayer
var toast_id: int = 0
var save_elapsed: float = 0.0
var navigating: bool = false
var last_event_id: int = 0
var test_mode: bool = false
var capture_mode: bool = false
var left_arrow: Button
var right_arrow: Button
var page_dots: Label
var sheet_panel: PanelContainer
var sheet_close_button: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	test_mode = "--smoke" in OS.get_cmdline_user_args()
	capture_mode = "--capture" in OS.get_cmdline_user_args()
	var save_path: String = "user://smoke_garden.json" if test_mode else ("user://capture_garden.json" if capture_mode else "user://garden.json")
	model = Model.new(save_path)
	if test_mode or capture_mode:
		model.fresh(int(Time.get_unix_time_from_system()))
	else:
		model.load_or_create(int(Time.get_unix_time_from_system()))
	world = View.new()
	world.model = model
	world.scale = Vector2.ONE
	add_child(world)
	world.place_pressed.connect(_place_pressed)
	bowl = AudioStreamPlayer.new()
	bowl.stream = preload("res://assets/bowl.wav")
	bowl.volume_db = -7
	bowl.max_polyphony = 4
	add_child(bowl)
	_build_hud()
	_refresh_zone()
	model.data.intro_seen = true
	if model.load_warning != "":
		_toast(model.load_warning, 8)
	_persist()
	if test_mode:
		_run_smoke.call_deferred()
	elif "--capture" in OS.get_cmdline_user_args():
		_capture.call_deferred()
	else:
		_arrive()

func _exit_tree() -> void:
	if is_instance_valid(bowl):
		bowl.stop()
		bowl.stream = null

func _arrive() -> void:
	var clouds := ColorRect.new()
	clouds.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clouds.color = Color("667c83")
	clouds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clouds)
	world.position.y = 18
	var tween := create_tween().set_parallel()
	tween.tween_property(clouds, "modulate:a", 0.0, 0.8)
	tween.tween_property(world, "position:y", 0.0, 0.8).set_trans(Tween.TRANS_SINE)
	tween.finished.connect(clouds.queue_free)

func _process(delta: float) -> void:
	save_elapsed += delta
	if save_elapsed > 30:
		model.advance(int(Time.get_unix_time_from_system()))
		_persist()
		save_elapsed = 0
	if meditation_state == "opening":
		opening_elapsed += delta
		while next_strike < 3 and opening_elapsed >= next_strike * 2.2:
			_strike()
			next_strike += 1
		if opening_elapsed >= 6.5:
			meditation_state = "running"
			_update_timer()
	elif meditation_state == "running":
		elapsed_seconds += delta
		_update_timer()
		if timer_seconds > 0 and elapsed_seconds >= timer_seconds:
			_finish_meditation()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		if meditation_state in ["opening", "running"]:
			meditation_state = "paused"
			bowl.stop()
			_update_timer()
		if model != null:
			_persist()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if model != null:
			_persist()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if overlay != null:
			if meditation_state != "idle":
				_stop_meditation()
			else:
				_close_modal()

func _style(color: Color, radius: int = 18, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.border_color = border
	style.set_border_width_all(1)
	return style

func _text(value: String, size: int = 18, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(value: String, callback: Callable, accent: bool = false) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(0, 44)
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("182037") if accent else INK)
	button.add_theme_color_override("font_hover_color", Color("182037") if accent else GOLD)
	button.add_theme_stylebox_override("normal", _style(GOLD if accent else Color("19253d"), 12, Color("35415b")))
	button.add_theme_stylebox_override("hover", _style(Color("edd0a0") if accent else Color("283750"), 12, GOLD))
	button.add_theme_stylebox_override("pressed", _style(Color("b69b74") if accent else Color("32415f"), 12))
	button.add_theme_stylebox_override("focus", _style(Color(0,0,0,0), 12, GOLD))
	button.pressed.connect(callback)
	return button

func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	# A quiet lower fade, not a dashboard panel over the illustration.
	var fade := TextureRect.new()
	fade.position = Vector2(0, 680)
	fade.size = Vector2(540, 280)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gradient.colors = PackedColorArray([Color(0.025,0.04,0.09,0), Color(0.025,0.04,0.09,0.68), Color(0.025,0.04,0.09,0.98)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0,0)
	texture.fill_to = Vector2(0,1)
	fade.texture = texture
	hud.add_child(fade)
	left_arrow = _button("‹", func() -> void: _navigate(world.zone - 1))
	right_arrow = _button("›", func() -> void: _navigate(world.zone + 1))
	for arrow in [left_arrow, right_arrow]:
		arrow.add_theme_font_size_override("font_size", 34)
		var style := _style(Color(0.045,0.075,0.15,0.28), 24)
		style.content_margin_left = 0
		style.content_margin_right = 0
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		arrow.add_theme_stylebox_override("normal", style)
		arrow.size = Vector2(46,52)
		arrow.custom_minimum_size = Vector2(46,52)
		hud.add_child(arrow)
	left_arrow.position = Vector2(12, 447)
	right_arrow.position = Vector2(482, 447)
	status_label = _text("Д Н Е В Н И К  И  П Р А К Т И К А", 10, MUTED)
	status_label.position = Vector2(30, 752)
	hud.add_child(status_label)
	zone_title = _text("", 30, INK)
	zone_title.position = Vector2(28, 778)
	hud.add_child(zone_title)
	zone_description = _text("", 14, MUTED)
	zone_description.position = Vector2(30, 823)
	hud.add_child(zone_description)
	var more := _button("···", _app_menu)
	more.position = Vector2(462, 778)
	more.size = Vector2(48,44)
	more.custom_minimum_size = Vector2(48,44)
	more.add_theme_font_size_override("font_size", 24)
	more.add_theme_stylebox_override("normal", _style(Color.TRANSPARENT, 14))
	hud.add_child(more)
	action_button = _button("", _zone_action, true)
	action_button.position = Vector2(28, 864)
	action_button.size = Vector2(484, 55)
	action_button.add_theme_font_size_override("font_size", 17)
	hud.add_child(action_button)
	page_dots = _text("", 12, MUTED)
	page_dots.position = Vector2(180, 934)
	page_dots.size.x = 180
	page_dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(page_dots)
	toast_box = PanelContainer.new()
	toast_box.position = Vector2(28, 682)
	toast_box.size = Vector2(484, 54)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_theme_stylebox_override("panel", _style(Color(0.055,0.08,0.15,0.96), 14))
	hud.add_child(toast_box)
	toast_label = _text("", 14, INK)
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_box.add_child(toast_label)
	toast_box.hide()
	toast_timer = Timer.new()
	toast_timer.one_shot = true
	toast_timer.timeout.connect(func() -> void: toast_box.hide())
	add_child(toast_timer)

func _refresh_zone() -> void:
	zone_title.text = ["Записи", "Сад ума", "Практика"][world.zone]
	zone_description.text = ["О том, что было внутри и что удалось заметить.", "Ваши намерения оставляют здесь след.", "Несколько минут у поющей чаши."][world.zone]
	action_button.text = ["Открыть дневник", "Сделать запись", "Начать медитацию"][world.zone]
	left_arrow.visible = world.zone > 0
	right_arrow.visible = world.zone < 2
	page_dots.text = ["●   ·   ·", "·   ●   ·", "·   ·   ●"][world.zone]

func _navigate(destination: int) -> void:
	if navigating or destination < 0 or destination > 2 or world.zone == destination or meditation_state != "idle":
		return
	navigating = true
	var direction: float = 1.0 if destination > world.zone else -1.0
	var departure := create_tween().set_parallel()
	departure.tween_property(world, "position:x", -24 * direction, 0.16)
	departure.tween_property(world, "modulate:a", 0.35, 0.16)
	await departure.finished
	world.zone = destination
	world.player = Vector2(256, 660)
	world.position.x = 24 * direction
	_refresh_zone()
	var arrival := create_tween().set_parallel()
	arrival.tween_property(world, "position:x", 0.0, 0.24).set_trans(Tween.TRANS_SINE)
	arrival.tween_property(world, "modulate:a", 1.0, 0.24)
	await arrival.finished
	navigating = false

func _zone_action() -> void:
	if world.zone == 2:
		_meditation_menu()
	elif world.zone == 0:
		_history()
	else:
		_journal("mood")

func _place_pressed(place: String) -> void:
	match place:
		"cat":
			_toast("Кот принял поглаживание. Духовный статус не уточнил.")
			world.cat_wait = 6
			world.cat_target = world.cat
		"journal": _journal("mood")
		"meditation": _meditation_menu()
		"pond": _pond()
		"plant": _plant_info()

func _modal(title: String, description: String = "", height: float = 560) -> VBoxContainer:
	_close_modal()
	toast_box.hide()
	toast_timer.stop()
	overlay = ColorRect.new()
	overlay.color = Color(0.02,0.03,0.08,0.48)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	sheet_panel = PanelContainer.new()
	sheet_panel.position = Vector2(16, 944 - height)
	sheet_panel.size = Vector2(508, height)
	sheet_panel.add_theme_stylebox_override("panel", _style(Color("101b30"), 24, Color("36415e")))
	overlay.add_child(sheet_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sheet_panel.add_child(scroll)
	modal_content = VBoxContainer.new()
	modal_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_content.add_theme_constant_override("separation", 12)
	scroll.add_child(modal_content)
	var heading := HBoxContainer.new()
	modal_content.add_child(heading)
	var title_label := _text(title, 23, INK)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_child(title_label)
	sheet_close_button = _button("×", _close_modal)
	sheet_close_button.add_theme_font_size_override("font_size", 22)
	heading.add_child(sheet_close_button)
	if description != "":
		var explanation := _text(description, 14, MUTED)
		explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		modal_content.add_child(explanation)
	return modal_content

func _close_modal() -> void:
	if is_instance_valid(overlay):
		overlay.hide()
		overlay.queue_free()
		overlay = null

func _journal(kind: String) -> void:
	selected_emotions.clear()
	selected_deed = ""
	var column := _modal("Сделать запись", "Что удалось заметить? Можно выбрать несколько состояний.", 610)
	var tabs := HBoxContainer.new()
	column.add_child(tabs)
	tabs.add_child(_button("Что внутри", func() -> void: _journal("mood"), kind == "mood"))
	tabs.add_child(_button("Намерения и дела", func() -> void: _journal("deed"), kind == "deed"))
	var grid := GridContainer.new()
	grid.columns = 3 if kind == "mood" else 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	column.add_child(grid)
	var choices: Array[String] = EMOTIONS if kind == "mood" else DEEDS
	for choice in choices:
		var option := _button(choice, func() -> void: pass)
		option.toggle_mode = true
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.add_theme_font_size_override("font_size", 14)
		grid.add_child(option)
		option.toggled.connect(func(pressed: bool) -> void:
			if kind == "mood":
				if pressed and not choice in selected_emotions:
					selected_emotions.append(choice)
				elif not pressed:
					selected_emotions.erase(choice)
			else:
				if pressed:
					selected_deed = choice
					for other in grid.get_children():
						if other != option:
							other.set_pressed_no_signal(false)
				elif selected_deed == choice:
					selected_deed = ""
		)
	if kind == "mood":
		column.add_child(_text("Насколько заметно: от едва до сильно", 14, MUTED))
		intensity_slider = HSlider.new()
		intensity_slider.min_value = 1
		intensity_slider.max_value = 5
		intensity_slider.step = 1
		intensity_slider.value = 3
		intensity_slider.custom_minimum_size.y = 26
		column.add_child(intensity_slider)
	journal_note = TextEdit.new()
	journal_note.custom_minimum_size = Vector2(0, 86)
	journal_note.placeholder_text = "Можно добавить пару слов. А можно не добавлять."
	journal_note.add_theme_font_override("font", FONT)
	journal_note.add_theme_font_size_override("font_size", 16)
	journal_note.add_theme_color_override("font_color", INK)
	journal_note.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	journal_note.add_theme_stylebox_override("normal", _style(Color("0a1427"), 10))
	column.add_child(journal_note)
	column.add_child(_button("Сохранить запись", func() -> void: _save_entry(kind), true))

func _save_entry(kind: String) -> void:
	var note: String = journal_note.text.strip_edges()
	if kind == "mood" and selected_emotions.is_empty() and note == "":
		_toast("Выберите состояние или оставьте пару слов.")
		return
	if kind == "deed" and selected_deed == "" and note == "":
		_toast("Выберите дело или опишите его своими словами.")
		return
	var labels: Array = selected_emotions.duplicate() if kind == "mood" else [selected_deed]
	var plants_before: int = model.data.plants.size()
	last_event_id = model.add_event(kind, note, labels, int(intensity_slider.value) if kind == "mood" else 1, 0, int(Time.get_unix_time_from_system()))
	var saved: bool = _persist()
	_close_modal()
	if saved:
		if kind == "deed":
			_toast("В саду появился росток. У записи есть след." if model.data.plants.size() > plants_before else "Запись сохранена. В этом небольшом саду пока все места заняты.", 6)
		else:
			_toast("Запись осталась здесь. Вам не обязательно менять своё состояние.", 6)
	else:
		_toast("Запись пока только в памяти. Не удалось сохранить файл.", 8)

func _history() -> void:
	var column := _modal("История сада", "Здесь остаются записи, даже когда цветение заканчивается.")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 310)
	column.add_child(scroll)
	var entries := VBoxContainer.new()
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries.add_theme_constant_override("separation", 10)
	scroll.add_child(entries)
	if model.data.events.is_empty():
		entries.add_child(_text("Пока пусто. В саду уже можно побыть.", 17, MUTED))
	for i in range(model.data.events.size() - 1, -1, -1):
		var event: Dictionary = model.data.events[i]
		var event_id: int = int(event.id)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _style(Color("19253d"), 10))
		entries.add_child(card)
		var box := VBoxContainer.new()
		card.add_child(box)
		var date: String = Time.get_datetime_string_from_unix_time(int(event.created_at)).replace("T", " ").left(16)
		box.add_child(_text(date + " UTC", 12, MUTED))
		var title: String = "Практика у чаши" if event.kind == "practice" else ", ".join(event.emotions)
		if title == "":
			title = "Своя запись"
		var description := _text(title + (" · %d сек." % int(event.duration) if event.kind == "practice" else ""), 17)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(description)
		if event.note != "":
			var note_label := _text(event.note, 15, MUTED)
			note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(note_label)
		var controls := VBoxContainer.new()
		box.add_child(controls)
		controls.add_child(_button("Исправить текст", func() -> void: _edit_entry(event_id)))
		controls.add_child(_button("Удалить запись", func() -> void: _delete_confirmation(event_id)))
	column.add_child(_button("Новая запись", func() -> void: _journal("mood"), true))

func _edit_entry(event_id: int) -> void:
	for event in model.data.events:
		if int(event.id) != event_id:
			continue
		var column := _modal("Исправить текст", "Состояния записи пока меняются через удаление и новую запись.")
		var editor := TextEdit.new()
		editor.text = event.note
		editor.custom_minimum_size = Vector2(0, 190)
		editor.add_theme_font_override("font", FONT)
		editor.add_theme_font_size_override("font_size", 15)
		editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		column.add_child(editor)
		column.add_child(_button("Сохранить", func() -> void:
			event.note = editor.text.left(2000)
			_persist()
			_history()
		, true))
		return

func _delete_confirmation(event_id: int) -> void:
	var column := _modal("Удалить эту запись?", "Исчезнет запись и связанный с ней росток. Остальной сад останется на месте.")
	column.add_child(_button("Оставить", _history, true))
	column.add_child(_button("Удалить", func() -> void:
		model.remove_event(event_id)
		_persist()
		_history()
	))

func _meditation_menu() -> void:
	var column := _modal("Сесть у чаши", "Три звука в начале, один в конце. Дыхание можно оставить естественным. Глаза можно не закрывать.")
	column.add_child(_text("Сколько времени хочется побыть здесь?", 16))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	for minutes in [1, 3, 5, 7]:
		var seconds: int = minutes * 60
		var duration_button := _button("%d мин." % minutes, func() -> void: _start_meditation(seconds), minutes == 3)
		duration_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(duration_button)
	column.add_child(_button("Без обратного отсчёта", func() -> void: _start_meditation(0)))
	column.add_child(_button("Сейчас слишком тяжело", _support))

func _start_meditation(seconds: int) -> void:
	timer_seconds = seconds
	elapsed_seconds = 0
	opening_elapsed = 0
	next_strike = 0
	var column := _modal("Медитация", "Можно просто побыть здесь.", 304)
	overlay.color.a = 0.12
	sheet_close_button.pressed.disconnect(_close_modal)
	sheet_close_button.pressed.connect(_stop_meditation)
	world.meditating = true
	timer_label = _text("", 64, INK)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(timer_label)
	timer_hint = _text("Три звука чаши. Устраивайтесь удобнее.", 14, MUTED)
	timer_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	timer_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(timer_hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	pause_button = _button("Пауза", _pause_meditation)
	pause_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(pause_button)
	var finish := _button("Завершить", _stop_meditation, true)
	finish.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(finish)
	meditation_state = "opening"
	_update_timer()

func _update_timer() -> void:
	if not is_instance_valid(timer_label):
		return
	var seconds: int = maxi(0, int(ceil(timer_seconds - elapsed_seconds))) if timer_seconds > 0 else int(elapsed_seconds)
	timer_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	if meditation_state == "paused":
		timer_hint.text = "Пауза. Вернуться можно, когда удобно."
		pause_button.text = "Продолжить"
	elif meditation_state == "running":
		timer_hint.text = "Естественное дыхание. Звуки вокруг. Опора под телом."
		pause_button.text = "Пауза"

func _pause_meditation() -> void:
	if meditation_state == "paused":
		meditation_state = "opening" if opening_elapsed < 6.5 else "running"
		if meditation_state == "opening":
			timer_hint.text = "Три звука чаши. Устраивайтесь удобнее."
			pause_button.text = "Пауза"
	elif meditation_state in ["opening", "running"]:
		meditation_state = "paused"
		bowl.stop()
	_update_timer()

func _finish_meditation() -> void:
	if meditation_state == "idle":
		return
	meditation_state = "idle"
	world.meditating = false
	_strike()
	var seconds: int = maxi(1, int(elapsed_seconds))
	last_event_id = model.add_event("practice", "Практика у поющей чаши", [], 1, seconds, int(Time.get_unix_time_from_system()))
	var saved: bool = _persist()
	var column := _modal("Можно закончить здесь", "Чаша ещё звучит. Не обязательно чувствовать себя иначе.", 320)
	column.add_child(_text("У подушки остался небольшой след практики.", 17, MUTED))
	if not saved:
		column.add_child(_text("Не удалось сохранить файл. Практика пока в памяти.", 16, GOLD))
	column.add_child(_button("Продолжить", _close_modal, true))

func _stop_meditation() -> void:
	if elapsed_seconds >= 1:
		_finish_meditation()
	else:
		meditation_state = "idle"
		world.meditating = false
		bowl.stop()
		_close_modal()
		_toast("Можно вернуться к чаше в другой раз.")

func _strike() -> void:
	if bool(model.data.sound) and not capture_mode:
		bowl.play()

func _support() -> void:
	var column := _modal("Можно сделать меньше", "Остановите практику, если сейчас так комфортнее. Посмотрите вокруг и найдите несколько знакомых предметов. Можно почувствовать опору под ногами или написать человеку, которому доверяете.")
	column.add_child(_text("Не нужно разбираться со всем прямо сейчас.", 18, GOLD))
	column.add_child(_button("Просто вернуться в сад", _close_modal, true))

func _pond() -> void:
	var explanations: Dictionary = {"clear":"Свет меняется вместе со временем суток. Не каждому облаку нужна причина в вас.", "rain":"Дождь связан с вашей недавней отметкой грусти. Это образ переживания, а не оценка поступков.", "wind":"Ветер связан с недавней отметкой тревоги или злости. Он постепенно стихнет.", "cloud":"Облачность связана с отметкой усталости или неопределённости. Ясность не обязательна."}
	var column := _modal("Что происходит в саду", explanations[model.atmosphere()])
	column.add_child(_text("Погода от записи постепенно сменится сама.", 17, MUTED))
	column.add_child(_button("Побыть у воды", _close_modal, true))

func _plant_info() -> void:
	var column := _modal("У каждого цветка своё время", "Растения проходят через рост, цветение и семена. Их возраст зависит от прошедшего времени. Запись о добром деле может оставить новый росток.")
	column.add_child(_text("Цветение меняется. Запись остаётся.", 18, GOLD))
	column.add_child(_button("Вернуться", _close_modal, true))

func _settings() -> void:
	var column := _modal("Настройки", "Ранняя версия 0.0.2. Данные сохраняются на этом устройстве. Синхронизации и облачного восстановления пока нет.")
	column.add_child(_button("Звук чаши: " + ("включён" if bool(model.data.sound) else "выключен"), func() -> void:
		model.data.sound = not bool(model.data.sound)
		if not model.data.sound:
			bowl.stop()
		_persist()
		_settings()
	))
	column.add_child(_button("Что уже работает", _about))
	column.add_child(_button("Сейчас слишком тяжело", _support))
	column.add_child(_text("Не удаляйте приложение: сначала перенесите сохранение.\nУдобный экспорт появится до первой раздачи друзьям.", 14, MUTED))

func _about() -> void:
	var column := _modal("Об этом месте", "Сад ума, дневник состояний и буддийской практики с живой иллюстрацией.")
	var details := _text("Стрелки по краям открывают соседние экраны.\nКнопка внизу открывает запись или практику.\nНажатие на сад лишь перемещает персонажа.\n\nСад учитывает время между посещениями.\nНет серий дней, штрафов и оценки вашей кармы.\n\nНовое визуальное направление требует согласования.\nЗвук чаши пока синтезирован.", 14, MUTED)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(details)

func _persist() -> bool:
	var error: Error = model.save()
	if error != OK:
		push_error("Garden save failed: %s" % error_string(error))
	return error == OK

func _toast(message: String, duration: float = 4.0) -> void:
	toast_label.text = message
	toast_box.show()
	# Toasts stay above modal overlays so validation errors remain visible.
	toast_box.z_index = 10
	toast_timer.start(duration)

func _capture() -> void:
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var result: Error = get_viewport().get_texture().get_image().save_png("res://../artifacts/mind-garden-v2-home.png")
	print("CAPTURE HOME ", error_string(result))
	action_button.pressed.emit()
	await get_tree().create_timer(0.15).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../artifacts/mind-garden-v2-journal.png")
	_close_modal()
	await _navigate(0)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../artifacts/mind-garden-v2-left.png")
	await _navigate(1)
	await _navigate(2)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../artifacts/mind-garden-v2-right.png")
	_start_meditation(180)
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../artifacts/mind-garden-v2-meditation.png")
	bowl.stop()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(0 if result == OK else 1)

func _run_smoke() -> void:
	await get_tree().create_timer(0.2).timeout
	assert(get_viewport().get_visible_rect().size == Vector2(540,960))
	assert(world.scale == Vector2.ONE)
	assert(left_arrow.visible and right_arrow.visible)
	action_button.pressed.emit()
	selected_emotions.append("Грусть")
	journal_note.text = "Тестовая запись"
	_save_entry("mood")
	assert(model.atmosphere() == "rain")
	assert(model.data.events.size() == 1)
	_journal("deed")
	selected_deed = "Помогли"
	_save_entry("deed")
	assert(model.data.plants.size() == 4)
	_history()
	_edit_entry(1)
	_close_modal()
	await _navigate(0)
	assert(not left_arrow.visible and right_arrow.visible)
	await _navigate(1)
	await _navigate(2)
	assert(left_arrow.visible and not right_arrow.visible)
	action_button.pressed.emit()
	assert(is_instance_valid(overlay))
	_start_meditation(2)
	opening_elapsed = 6.5
	await get_tree().create_timer(0.2).timeout
	_pause_meditation()
	assert(meditation_state == "paused")
	_pause_meditation()
	await get_tree().create_timer(2.3).timeout
	assert(meditation_state == "idle")
	assert(model.practice_seconds() >= 2)
	_close_modal()
	var reloaded := Model.new("user://smoke_garden.json")
	assert(reloaded.load_or_create(int(Time.get_unix_time_from_system())))
	assert(reloaded.data.events.size() == 3)
	bowl.stop()
	await get_tree().create_timer(0.2).timeout
	print("SMOKE PASS: portrait, buttons, side arrows, journal, weather, new plant, history, timer, pause, save/reload")
	get_tree().quit()

func _app_menu() -> void:
	var column := _modal("Сад ума", "Дневник и практика. Всё остальное может подождать.", 442)
	column.add_child(_button("История записей", _history))
	column.add_child(_button("Что меняется в саду", _pond))
	column.add_child(_button("О растениях", _plant_info))
	column.add_child(_button("Настройки", _settings))
	column.add_child(_button("Сейчас слишком тяжело", _support))
