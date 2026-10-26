extends Control
const BODY: Font = preload("res://assets/Body.tres")
const Icon = preload("res://scripts/pixel_icon.gd")
const Strip = preload("res://scripts/ecosystem_strip.gd")
const Model = preload("res://scripts/garden_state.gd")
const View = preload("res://scripts/garden_view.gd")
const Clock = preload("res://scripts/meditation_clock.gd")
const Journal = preload("res://scripts/journal_form.gd")
const Wheel = preload("res://scripts/minute_wheel.gd")
const Practices = preload("res://scripts/practice_catalog.gd")
const INK := Color("eee8d7")
const MUTED := Color("bdc0b2")
const GOLD := Color("e7c79f")
var model: GardenState
var world: Node2D
var hud: Control
var overlay: ColorRect
var modal_content: VBoxContainer
var modal_frame: VBoxContainer
var sheet_panel: PanelContainer
var sheet_close_button: Button
var toast_box: PanelContainer
var toast_label: Label
var toast_timer: Timer
var zone_title: Label
var zone_description: Label
var action_button: Button
var left_arrow: Button
var right_arrow: Button
var sound_button: Button
var sound_icon: Control
var ecosystem_strip: Control
var footer_update: float = 0
var page_dots: Label
var journal_form: VBoxContainer
var clock := Clock.new()
var timer_label: Label
var timer_hint: Label
var pause_button: Button
var bowl: AudioStreamPlayer
var navigating := false
var test_mode := false
var capture_mode := false
var save_elapsed: float = 0
var draft_save_elapsed: float = -1
var last_draft_pattern_ms: int = 0
var selected_minutes: int = 5
var selected_practice_id: String = ""
var last_event_id: int = 0
var start_queued := false
var original_note: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	test_mode = "--smoke" in OS.get_cmdline_user_args()
	capture_mode = "--capture" in OS.get_cmdline_user_args() or "--practice-capture" in OS.get_cmdline_user_args()
	model = Model.new("user://smoke_garden.json" if test_mode else ("user://capture_garden.json" if capture_mode else "user://garden.json"))
	if test_mode or capture_mode:
		model.fresh(_now())
	else:
		model.load_or_create(_now())
	model.pattern("opens")
	world = View.new()
	world.model = model
	add_child(world)
	world.place_pressed.connect(_place_pressed)
	world.navigate_requested.connect(_navigate)
	world.seated.connect(func() -> void:
		if start_queued:
			start_queued = false
			_start_meditation(selected_minutes*60))
	bowl = AudioStreamPlayer.new()
	bowl.stream = preload("res://assets/bowl.wav")
	bowl.volume_db = -8
	bowl.max_polyphony = 4
	add_child(bowl)
	_build_theme()
	_build_hud()
	_refresh_zone()
	_persist()
	if model.load_warning!="":
		_toast(model.load_warning)
	if test_mode:
		_run_smoke.call_deferred()
	elif "--practice-capture" in OS.get_cmdline_user_args():
		_capture_practices.call_deferred()
	elif capture_mode:
		_capture.call_deferred()
	else:
		_arrive()

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

func _now() -> int:
	return int(Time.get_unix_time_from_system())

func _build_theme() -> void:
	theme = Theme.new()
	theme.default_font = BODY
	theme.default_font_size = 16
	for type in ["Button","TextEdit","Label"]:
		theme.set_color("font_color",type,INK)
	theme.set_color("font_pressed_color","Button",GOLD)
	theme.set_stylebox("normal","Button",_style(Color("263530"),4,Color("67705d")))
	theme.set_stylebox("hover","Button",_style(Color("3a463a"),4,GOLD))
	theme.set_stylebox("pressed","Button",_style(Color("505744"),4,GOLD))
	theme.set_stylebox("focus","Button",_style(Color(0,0,0,0),4,GOLD))
	theme.set_stylebox("normal","TextEdit",_style(Color("101d1d"),4,Color("536052")))

func _process(delta: float) -> void:
	footer_update += delta
	if footer_update>1 and is_instance_valid(zone_title):
		footer_update = 0
		if world.zone==1:
			zone_title.text = "Сад ума · "+str(world.day_info.get("period",""))
			zone_title.add_theme_font_size_override("font_size",24)
		else:
			zone_title.add_theme_font_size_override("font_size",28)
	save_elapsed += delta
	if save_elapsed>30:
		model.advance(_now())
		_persist()
		save_elapsed = 0
	if draft_save_elapsed>=0:
		draft_save_elapsed += delta
		if draft_save_elapsed>0.8:
			draft_save_elapsed = -1
			_persist()
	if clock.state=="running":
		var result: Dictionary = clock.tick(Time.get_ticks_msec())
		if result.strikes>0:
			_strike()
		_update_timer()
		if result.finished:
			_finish_meditation()
	if is_instance_valid(sheet_panel):
		var keyboard: float = float(DisplayServer.virtual_keyboard_get_height() if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD) else 0)/maxf(0.5,float(DisplayServer.window_get_size().y)/960.0)
		var bottom: float = 944-keyboard
		if sheet_panel.position.y+sheet_panel.size.y>bottom:
			sheet_panel.position.y = maxf(54,bottom-sheet_panel.size.y)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]:
		if model!=null:
			_persist()
	elif what==NOTIFICATION_WM_CLOSE_REQUEST:
		if model!=null:
			_persist()
	elif what==NOTIFICATION_WM_GO_BACK_REQUEST:
		if clock.state in ["running","paused"]:
			_stop_meditation()
		elif is_instance_valid(overlay):
			_close_modal()
			world.stand_up()
		elif world.zone!=1:
			_navigate(1)

func _exit_tree() -> void:
	if model!=null:
		_persist()
	if is_instance_valid(bowl):
		bowl.stop()
		bowl.stream = null

func _style(color: Color, radius: int = 4, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
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

func _text(value: String, font_size: int = 18, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", BODY)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(value: String, callback: Callable, accent: bool = false) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(0, 44)
	button.add_theme_font_override("font", BODY)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("182037") if accent else INK)
	button.add_theme_color_override("font_hover_color", Color("182037") if accent else GOLD)
	button.add_theme_stylebox_override("normal", _style(GOLD if accent else Color("25312e"), 12, Color("566052")))
	button.add_theme_stylebox_override("hover", _style(Color("edd0a0") if accent else Color("39453c"), 12, GOLD))
	button.add_theme_stylebox_override("pressed", _style(Color("b69b74") if accent else Color("454f40"), 12))
	button.add_theme_stylebox_override("focus", _style(Color(0,0,0,0), 12, GOLD))
	button.pressed.connect(callback)
	return button

func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	var panel := ColorRect.new()
	panel.position = Vector2(0,800)
	panel.size = Vector2(540,160)
	panel.color = Color("101f1d")
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(panel)
	left_arrow = _button("",func() -> void: _navigate(world.zone-1))
	right_arrow = _button("",func() -> void: _navigate(world.zone+1))
	var arrows: Array[Button] = [left_arrow,right_arrow]
	for i in range(2):
		var arrow: Button = arrows[i]
		arrow.custom_minimum_size = Vector2(52,56)
		arrow.size = Vector2(52,56)
		arrow.position = Vector2(10 if i==0 else 478,470)
		arrow.add_theme_stylebox_override("normal",_style(Color("304333"),3,Color("b9a27c")))
		var icon := Icon.new()
		icon.kind = "left" if i==0 else "right"
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		arrow.add_child(icon)
		hud.add_child(arrow)
	zone_title = _text("",28)
	zone_title.position = Vector2(24,808)
	hud.add_child(zone_title)
	zone_description = _text("",14,MUTED)
	zone_description.position = Vector2(25,844)
	hud.add_child(zone_description)
	action_button = _button("",_zone_action,true)
	action_button.position = Vector2(24,881)
	action_button.size = Vector2(492,52)
	action_button.add_theme_font_size_override("font_size",20)
	hud.add_child(action_button)
	var more := _button("···",_app_menu)
	more.position = Vector2(464,808)
	more.size = Vector2(52,40)
	more.add_theme_font_size_override("font_size",22)
	hud.add_child(more)
	page_dots = _text("",12,MUTED)
	page_dots.position = Vector2(237,941)
	hud.add_child(page_dots)
	sound_button = _button("",_toggle_sound)
	sound_button.position = Vector2(476,16)
	sound_button.size = Vector2(48,48)
	sound_icon = Icon.new()
	sound_icon.kind = "sound"
	sound_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sound_button.add_child(sound_icon)
	hud.add_child(sound_button)
	_update_sound()
	ecosystem_strip = Strip.new()
	ecosystem_strip.world = world
	ecosystem_strip.position = Vector2(20,851)
	ecosystem_strip.size = Vector2(500,80)
	ecosystem_strip.selected.connect(func(kind: String) -> void: world.highlight(kind))
	hud.add_child(ecosystem_strip)
	toast_box = PanelContainer.new()
	toast_box.position = Vector2(24,728)
	toast_box.custom_minimum_size = Vector2(492,0)
	toast_box.add_theme_stylebox_override("panel",_style(Color("23372e"),4,GOLD))
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_box)
	toast_label = _text("",16)
	toast_label.custom_minimum_size.x = 450
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_box.add_child(toast_label)
	toast_box.hide()
	toast_timer = Timer.new()
	toast_timer.one_shot = true
	toast_timer.timeout.connect(func() -> void: toast_box.hide())
	add_child(toast_timer)

func _refresh_zone() -> void:
	zone_title.text = ["Записи","Сад ума","Практика"][world.zone]
	zone_description.text = ["Что удалось заметить?","Живые детали сада","Можно просто посидеть."][world.zone]
	action_button.text = ["Новая запись","","Сесть у чаши"][world.zone]
	action_button.visible = world.zone!=1
	ecosystem_strip.visible = world.zone==1
	if world.zone==1:
		zone_title.position.y = 804
		zone_description.hide()
	else:
		zone_title.position.y = 808
		zone_description.show()
	left_arrow.visible = world.zone>0
	right_arrow.visible = world.zone<2
	left_arrow.tooltip_text = "К записям" if world.zone==1 else "В сад"
	right_arrow.tooltip_text = "К практике" if world.zone==1 else "В сад"
	page_dots.text = ["●  ·  ·","·  ●  ·","·  ·  ●"][world.zone]

func _navigate(destination: int) -> void:
	if navigating or destination<0 or destination>2 or destination==world.zone or clock.state in ["running","paused"]:
		return
	navigating = true
	world.input_blocked = true
	_close_modal()
	start_queued = false
	world.cancel_route()
	var direction: float = 1 if destination>world.zone else -1
	var tween := create_tween()
	tween.tween_property(world,"modulate:a",0.25,0.12)
	await tween.finished
	world.set_zone(destination,direction)
	model.pattern("transitions")
	_refresh_zone()
	var arrival := create_tween()
	arrival.tween_property(world,"modulate:a",1.0,0.18)
	await arrival.finished
	navigating = false
	world.input_blocked = false

func _zone_action() -> void:
	if world.zone==1:
		await _navigate(0)
		_journal()
	elif world.zone==0:
		_journal()
	else:
		_meditation_menu()

func _place_pressed(place: String) -> void:
	match place:
		"journal": _journal()
		"meditation": _meditation_menu()
		"cat": _toast("Кот принял поглаживание. И остался котом.")
		"pond", "plant", "tree": _garden_info()

func _modal(title: String, description: String = "", height: float = 560) -> VBoxContainer:
	_close_modal()
	world.input_blocked = true
	toast_box.hide()
	toast_timer.stop()
	overlay = ColorRect.new()
	overlay.color = Color(0.02,0.03,0.08,0.48)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	sheet_panel = PanelContainer.new()
	var keyboard: float = float(DisplayServer.virtual_keyboard_get_height() if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD) else 0) / maxf(0.5, float(DisplayServer.window_get_size().y)/960.0)
	height = minf(height, 890-keyboard)
	sheet_panel.position = Vector2(16, 944 - keyboard - height)
	sheet_panel.size = Vector2(508, height)
	sheet_panel.add_theme_stylebox_override("panel", _style(Color("172523"), 4, Color("78836b")))
	overlay.add_child(sheet_panel)
	if is_instance_valid(sound_button):
		sound_button.z_index = 20
	modal_frame = VBoxContainer.new()
	sheet_panel.add_child(modal_frame)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	modal_frame.add_child(scroll)
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
	start_queued = false
	if is_instance_valid(world) and not navigating:
		world.input_blocked = false
	if is_instance_valid(overlay):
		overlay.hide()
		overlay.queue_free()
		overlay = null

func _journal(event_id: int=0) -> void:
	var initial: Dictionary = model.data.draft.duplicate(true)
	if event_id>0:
		for e in model.data.events:
			if int(e.id)==event_id:
				initial = {"states":e.states.duplicate(),"deeds":e.deeds.duplicate(),"note":e.note}
	var column := _modal("Исправить запись" if event_id>0 else "Новая запись","Состояния и дела могут быть рядом.",750)
	journal_form = Journal.new()
	column.add_child(journal_form)
	journal_form.build(initial,event_id)
	var save_control: Control = journal_form.get_child(journal_form.get_child_count()-2)
	var history_control: Control = journal_form.get_child(journal_form.get_child_count()-1)
	journal_form.remove_child(save_control)
	journal_form.remove_child(history_control)
	modal_frame.add_child(save_control)
	modal_frame.add_child(history_control)
	journal_form.submitted.connect(_save_entry)
	journal_form.history_requested.connect(_history)
	journal_form.draft_changed.connect(func(draft: Dictionary) -> void:
		if event_id==0:
			model.data.draft = draft
			draft_save_elapsed = 0
			if Time.get_ticks_msec()-last_draft_pattern_ms>5000:
				model.pattern("draft_changes")
				last_draft_pattern_ms = Time.get_ticks_msec())

func _save_entry(states: Dictionary,deeds: Array,note: String,event_id: int=0) -> void:
	if states.is_empty() and deeds.is_empty() and note.strip_edges()=="":
		_toast("Выберите состояние, дело или добавьте слова.")
		return
	if event_id>0:
		model.edit_entry(event_id,states,deeds,note)
	else:
		last_event_id = model.add_entry(states,deeds,note,_now())
		model.data.draft = {"states":{},"deeds":[],"note":""}
	if _persist():
		_close_modal()
		_toast("Запись сохранена. Сад немного изменился.")
	else:
		_toast("Не удалось сохранить файл. Запись пока в памяти.")

func _history() -> void:
	var column := _modal("Дневник","Записи остаются, даже когда цветение меняется.",730)
	column.add_child(_button("Новая запись",_journal,true))
	for i in range(model.data.events.size()-1,-1,-1):
		var e: Dictionary = model.data.events[i]
		var box := VBoxContainer.new()
		column.add_child(box)
		box.add_child(_text(Time.get_datetime_string_from_unix_time(int(e.created_at)).replace("T"," ").left(16)+" UTC",12,MUTED))
		var values: Array[String] = []
		for emotion in e.states:
			values.append("%s %d%%" % [emotion,int(e.states[emotion])])
		if e.has("legacy_intensity") and not e.states.is_empty():
			values = [", ".join(e.states.keys())+" · %d/5, прежняя общая шкала" % int(e.legacy_intensity)]
		values.append_array(e.deeds)
		if e.kind=="practice":
			values.append("У чаши · %d мин %d сек" % [floori(float(e.duration)/60.0),int(e.duration)%60])
		var summary := _text(" · ".join(values),17)
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(summary)
		var note := _text(e.note,17,MUTED)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(note)
		var row := HBoxContainer.new()
		box.add_child(row)
		var id: int = int(e.id)
		row.add_child(_button("Исправить",func() -> void: _journal(id)))
		row.add_child(_button("Удалить",func() -> void: _delete_confirmation(id)))
		column.add_child(HSeparator.new())

func _delete_confirmation(id: int) -> void:
	var column := _modal("Удалить запись?","Связанный с ней росток тоже исчезнет.",300)
	column.add_child(_button("Оставить",_history,true))
	column.add_child(_button("Удалить",func() -> void:
		model.remove_event(id)
		_persist()
		_history()))

func _meditation_menu() -> void:
	selected_practice_id = ""
	world.go_to_cushion()
	var column := _modal("Сесть у чаши","Выберите короткую практику или обычный таймер.",420)
	overlay.color.a = 0.15
	for practice in Practices.ITEMS:
		var practice_id: String = practice.id
		column.add_child(_button(practice.title,func() -> void: _practice_card(practice_id)))
	column.add_child(_button("Таймер без инструкции",_duration_menu,true))
	column.add_child(_button("Сейчас слишком тяжело",_support))
	sheet_close_button.pressed.connect(func() -> void: world.stand_up())

func _practice_card(practice_id: String) -> void:
	var practice: Dictionary = Practices.find(practice_id)
	if practice.is_empty():
		return
	var column := _modal(practice.title,"Адаптация для приложения",720)
	overlay.color.a = 0.15
	var instruction := _text(practice.instruction,20)
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(instruction)
	column.add_child(_text("Источник",16,GOLD))
	var source := _text(practice.source,15,MUTED)
	source.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(source)
	column.add_child(_button("Открыть источник",func() -> void: OS.shell_open(practice.url)))
	var continue_button := _button("Выбрать время",func() -> void:
		selected_practice_id = practice_id
		selected_minutes = int(practice.minutes)
		_duration_menu(),true)
	modal_frame.add_child(continue_button)
	modal_frame.add_child(_button("К выбору практики",_meditation_menu))
	sheet_close_button.pressed.connect(func() -> void: world.stand_up())

func _duration_menu() -> void:
	var column := _modal("Сесть у чаши","Три удара в начале, один в конце.",650)
	overlay.color.a = 0.15
	var wheel := Wheel.new()
	column.add_child(wheel)
	wheel.value = selected_minutes
	wheel.value_changed.connect(func(value: int) -> void: selected_minutes = value)
	var row := HBoxContainer.new()
	column.add_child(row)
	for minutes in [5,10,15,30]:
		var b := _button(str(minutes),func() -> void: wheel.set_value(minutes))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	column.add_child(_button("Начать",func() -> void: _request_start(selected_minutes*60),true))
	column.add_child(_button("Без обратного отсчёта",func() -> void: _request_start(0)))
	column.add_child(_button("К выбору практики",_meditation_menu))
	column.add_child(_button("Сейчас слишком тяжело",_support))
	sheet_close_button.pressed.connect(func() -> void: world.stand_up())

func _request_start(seconds: int) -> void:
	if not world.meditating:
		start_queued = true
		selected_minutes = floori(float(seconds)/60.0)
		_toast("Устраиваемся у чаши…")
		return
	_start_meditation(seconds)

func _start_meditation(seconds: int) -> void:
	if clock.state in ["running","paused"]:
		return
	if bool(model.data.last_practice_early) and seconds>int(model.data.last_practice_target):
		model.pattern("longer_restarts")
	model.data.last_practice_target = seconds
	world.meditating = true
	clock.start(seconds,Time.get_ticks_msec())
	var result: Dictionary = clock.tick(Time.get_ticks_msec())
	if result.strikes>0:
		_strike()
	var practice: Dictionary = Practices.find(selected_practice_id)
	var column := _modal(str(practice.get("title","У чаши")),"Можно закончить раньше.",320)
	overlay.color.a = 0.08
	sheet_close_button.pressed.disconnect(_close_modal)
	sheet_close_button.pressed.connect(_stop_meditation)
	timer_label = _text("",58)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(timer_label)
	timer_hint = _text("Чаша звучит. Время уже идёт.",15,MUTED)
	timer_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(timer_hint)
	var row := HBoxContainer.new()
	column.add_child(row)
	pause_button = _button("Пауза",_pause_meditation)
	pause_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(pause_button)
	row.add_child(_button("Завершить",_stop_meditation,true))
	_update_timer()

func _update_timer() -> void:
	if not is_instance_valid(timer_label):
		return
	var seconds: int = int(ceil(maxf(0,clock.target-clock.elapsed))) if clock.target>0 else int(clock.elapsed)
	timer_label.text = "%02d:%02d" % [floori(float(seconds)/60.0),seconds%60]
	pause_button.text = "Продолжить" if clock.state=="paused" else "Пауза"
	timer_hint.text = "Пауза. Можно продолжить, когда удобно." if clock.state=="paused" else "Чаша звучит. Время уже идёт." if clock.elapsed<8 else "Опора под телом. Звуки вокруг."

func _pause_meditation() -> void:
	if clock.state=="paused":
		clock.resume(Time.get_ticks_msec())
	else:
		clock.pause(Time.get_ticks_msec())
		bowl.stop()
	_update_timer()

func _stop_meditation() -> void:
	if clock.state=="running":
		clock.tick(Time.get_ticks_msec())
	_finish_meditation()

func _finish_meditation() -> void:
	if clock.state=="idle":
		return
	var duration: int = int(clock.elapsed)
	var early: bool = clock.target>0 and clock.elapsed<clock.target
	clock.stop()
	start_queued = false
	model.data.last_practice_early = early
	if early:
		model.pattern("early_finishes")
	if duration>0:
		var practice: Dictionary = Practices.find(selected_practice_id)
		var note: String = "Практика: "+str(practice.title) if not practice.is_empty() else "Практика у поющей чаши"
		last_event_id = model.add_entry({},[],note,_now(),"practice",duration)
		_persist()
	_strike()
	world.stand_up()
	var column := _modal("Можно закончить здесь","У практики остался небольшой след.",285)
	column.add_child(_text("%d мин %d сек" % [floori(float(duration)/60.0),duration%60],30))
	column.add_child(_button("Вернуться в сад",_return_to_garden,true))
	column.add_child(_button("Посидеть ещё",_meditation_menu))

func _strike() -> void:
	world.strike()
	if bool(model.data.sound) and not capture_mode:
		bowl.play()

func _toggle_sound() -> void:
	model.data.sound = not bool(model.data.sound)
	if not model.data.sound:
		bowl.stop()
	_update_sound()
	_persist()

func _update_sound() -> void:
	sound_icon.active = bool(model.data.sound)
	sound_icon.queue_redraw()
	sound_button.tooltip_text = "Выключить звук" if model.data.sound else "Включить звук"

func _support() -> void:
	start_queued = false
	world.stand_up()
	var column := _modal("Можно сделать меньше","Почувствуйте опору под ногами. Посмотрите вокруг. Практику можно отложить.",330)
	column.add_child(_button("Вернуться в сад",_return_to_garden,true))

func _return_to_garden() -> void:
	_close_modal()
	world.stand_up()
	if world.zone!=1:
		_navigate(1)

func _garden_info() -> void:
	var detail: Dictionary = model.atmosphere_detail()
	var weather: String = {"rain":"Дождь откликнулся на отметку грусти.","wind":"Ветер связан с тревогой или злостью.","cloud":"Облака связаны с усталостью или неопределённостью.","clear":"Свет меняется со временем суток."}[detail.kind]
	var column := _modal("Что меняется",weather+" Сила эффекта зависит от вашей отметки и постепенно стихает.",620)
	var info := _text("Растения появляются после дел и практики. Посещения, переходы, прогулки, правки записей и смена длительности оставляют другие следы: плоды, траву, светлячков и облака.

Это местная жизнь сада, без оценки ваших намерений. Мы учитываем только действия внутри приложения. Тексты и нажатия клавиш никуда не отправляются.",17)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(info)
	for key in model.data.patterns:
		if int(model.data.patterns[key])>0:
			var names := {"opens":"Посещения","transitions":"Переходы","walks":"Прогулки","revisions":"Исправленные записи","draft_changes":"Изменения черновика","practices":"Практики","early_finishes":"Ранние завершения","longer_restarts":"Более долгие повторные сессии","entries":"Записи"}
			column.add_child(_text("%s: %d" % [names[key],int(model.data.patterns[key])],14,MUTED))
	column.add_child(_text("Все места заняты? Следующие растения оставляют семена.
Дневник продолжает сохраняться.",16,MUTED))

func _app_menu() -> void:
	var column := _modal("Сад ума","Можно выбрать другое занятие.",400)
	column.add_child(_button("История записей",_history))
	column.add_child(_button("Что меняется в саду",_garden_info))
	column.add_child(_button("Сейчас слишком тяжело",_support))
	column.add_child(_text("Версия 0.0.5 · всё хранится на устройстве.",15,MUTED))

func _persist() -> bool:
	var error: Error = model.save()
	if error!=OK:
		push_error("Garden save failed: "+error_string(error))
	return error==OK

func _toast(message: String,duration: float=4.0) -> void:
	toast_label.text = message
	toast_box.show()
	toast_box.z_index = 30
	toast_timer.start(duration)

func _capture() -> void:
	# Separate demonstration state never touches the real diary.
	for i in range(12):
		model.add_entry({"Радость":65},["Помогли"],"",_now()-i*100)
	for plant in model.data.plants:
		plant.born_age = float(model.data.world_age)-GardenState.FLOWER_CYCLE*0.57
	model.pattern("transitions",40)
	model.pattern("practices",6)
	world.preview_hour = 12
	await get_tree().create_timer(0.8).timeout
	await _shot("home")
	world.debug_navigation = true
	await _shot("navigation")
	world.debug_navigation = false
	for phase in [["dawn",6.0],["morning",9.0],["day",13.0],["sunset",18.25],["night",23.0]]:
		world.preview_hour = float(phase[1])
		world._update_day()
		footer_update = 2
		await _shot(str(phase[0]))
	world.preview_hour = 12
	world._update_day()
	footer_update = 2
	DirAccess.make_dir_recursive_absolute("res://../artifacts/motion-v4")
	var frame_index: int = 0
	for point in [Vector2(420,410),Vector2(420,360),Vector2(260,430),Vector2(260,650)]:
		world.walk_to(point)
		for frame in range(15):
			await get_tree().create_timer(0.1).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://../artifacts/motion-v4/frame%03d.png" % frame_index)
			frame_index += 1
	await _navigate(0)
	await _shot("left")
	model.data.draft = {"states":{"Тревога":37,"Благодарность":82},"deeds":["Помогли"],"note":"Удалось заметить напряжение и сделать паузу."}
	_journal()
	await _shot("journal")
	_close_modal()
	await _navigate(2)
	await _shot("right")
	_meditation_menu()
	_duration_menu()
	await get_tree().create_timer(5.0).timeout
	assert(world.meditating)
	await _shot("duration")
	world.meditating = true
	_start_meditation(300)
	await _shot("meditation")
	var struck_image := false
	for bowl_frame in range(80):
		await get_tree().create_timer(0.1).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://../artifacts/motion-v4/bowl%03d.png" % bowl_frame)
		if not struck_image and world.strike_age>0.15 and world.strike_age<0.4:
			get_viewport().get_texture().get_image().save_png("res://../artifacts/mind-garden-v4-bowl-strike.png")
			struck_image = true
	assert(world.strike_count==3)
	clock.stop()
	bowl.stop()
	get_tree().quit()

func _shot(suffix: String) -> void:
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../artifacts/mind-garden-v4-%s.png" % suffix)

func _run_smoke() -> void:
	await get_tree().create_timer(0.2).timeout
	assert(ProjectSettings.get_setting("debug/gdscript/warnings/treat_warnings_as_errors"))
	assert(not action_button.visible and ecosystem_strip.visible)
	await _navigate(0)
	assert(not left_arrow.visible and right_arrow.visible)
	assert(world.actor_rects.size()==36 and world.flora_rects.size()==28 and world.cat_rects.size()==16 and world.walk_rects.size()==16)
	for rect in world.actor_rects:
		assert(rect.size.x>5 and rect.size.y>5)
	assert(world.depth_scale(650)>world.depth_scale(450))
	world.gesture(Vector2(400,250),Vector2(150,250))
	await get_tree().create_timer(0.4).timeout
	assert(world.zone==1)
	await _navigate(0)
	_journal()
	_save_entry({"Грусть":37,"Благодарность":82},["Помогли"],"Проверка")
	assert(model.data.events.size()==1)
	assert(model.atmosphere()=="rain")
	_journal(1)
	assert(journal_form.sliders.size()==2)
	journal_form.sliders["Грусть"].value = 74
	assert(journal_form.draft.states["Грусть"]==74)
	_save_entry(journal_form.draft.states,["Помогли"],"Правка",1)
	assert(model.data.events.size()==1 and model.data.patterns.revisions==1)
	await _navigate(2)
	_meditation_menu()
	var events_before: int = model.data.events.size()
	var plants_before: int = model.data.plants.size()
	# Follow the actual button signals through both instructions and back.
	for practice in Practices.ITEMS:
		var choice_index: int = 2 if practice.id=="breathing" else 3
		modal_content.get_child(choice_index).pressed.emit()
		assert(modal_content.get_child(1).text=="Адаптация для приложения")
		assert(modal_content.get_child(2).text==practice.instruction)
		assert(modal_content.get_child(4).text==practice.source)
		assert(clock.state=="idle" and not start_queued)
		assert(model.data.events.size()==events_before and model.data.plants.size()==plants_before)
		modal_frame.get_child(1).pressed.emit()
		assert(selected_practice_id==practice.id and selected_minutes==3)
		modal_content.get_child(6).pressed.emit()
	assert(selected_practice_id=="")
	modal_content.get_child(4).pressed.emit()
	var wheel: Control = modal_content.get_child(2)
	wheel.set_value(17)
	assert(selected_minutes==17)
	_support()
	_return_to_garden()
	await get_tree().create_timer(0.4).timeout
	assert(world.zone==1 and not is_instance_valid(overlay))
	await _navigate(2)
	selected_practice_id = "breathing"
	world.meditating = true
	_start_meditation(1)
	await get_tree().create_timer(0.2).timeout
	assert(clock.elapsed>0.1)
	_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(clock.state=="running")
	_pause_meditation()
	assert(clock.state=="paused")
	_pause_meditation()
	await get_tree().create_timer(1.2).timeout
	assert(clock.state=="idle" and model.practice_seconds()==1)
	assert(model.data.events.back().note=="Практика: Внимание к дыханию")
	_finish_meditation()
	assert(model.data.events.size()==2)
	var restored := Model.new(model.path)
	assert(restored.load_or_create(_now()) and restored.data.events.size()==2)
	_meditation_menu()
	modal_content.get_child(4).pressed.emit()
	assert(selected_practice_id=="")
	world.meditating = true
	_request_start(0)
	assert(clock.state=="running" and clock.target==0)
	await get_tree().create_timer(1.1).timeout
	_stop_meditation()
	assert(model.data.events.size()==3 and model.data.events.back().note=="Практика у поющей чаши")
	_finish_meditation()
	assert(model.data.events.size()==3)
	_toggle_sound()
	assert(not model.data.sound)
	bowl.stop()
	await get_tree().create_timer(0.3).timeout
	print("SMOKE PASS: journal, navigation, both sourced practices, instruction back/continue, no rewards on reading, named practice result, plain unlimited timer, pause, exactly-once finish, reload, mute")
	get_tree().quit()

func _capture_practices() -> void:
	await _navigate(2)
	DirAccess.make_dir_recursive_absolute("res://previews/practices")
	for screen in ["menu","breathing","goodwill","timer"]:
		_meditation_menu()
		if screen in ["breathing","goodwill"]:
			_practice_card(screen)
		elif screen=="timer":
			_duration_menu()
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://previews/practices/%s.png" % screen)
	get_tree().quit()
