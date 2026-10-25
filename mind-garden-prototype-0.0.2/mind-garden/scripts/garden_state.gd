class_name GardenState
extends RefCounted

const FORMAT_VERSION: int = 1
const FLOWER_CYCLE: float = 4.0 * 86400.0
const SLOTS: Array[Vector2] = [Vector2(252, 222), Vector2(272, 211), Vector2(243, 201), Vector2(184, 236), Vector2(208, 250), Vector2(355, 239), Vector2(388, 248), Vector2(424, 240), Vector2(163, 224), Vector2(469, 206), Vector2(462, 242), Vector2(226, 274)]

var path: String = "user://garden.json"
var data: Dictionary = {}
var recovered_backup: bool = false
var load_warning: String = ""

func _init(save_path: String = "user://garden.json") -> void:
	path = save_path

func fresh(now: int) -> void:
	data = {"version": FORMAT_VERSION, "born_at": now, "last_tick": now,
		"world_age": 0.0, "next_id": 1, "events": [], "plants": [],
		"sound": true, "seed": 170319, "seeds": 0, "intro_seen": false}
	for i in range(3):
		data.plants.append({"id": "initial_%d" % i, "event_id": 0,
			"slot": i, "born_age": -float(i) * 25000.0, "cycles": 0})

func valid(candidate: Variant) -> bool:
	if not candidate is Dictionary:
		return false
	var c: Dictionary = candidate
	if int(c.get("version", -1)) != FORMAT_VERSION:
		return false
	for key in ["born_at", "last_tick", "world_age", "next_id", "seed", "seeds"]:
		if not (c.get(key) is float or c.get(key) is int):
			return false
	if not is_finite(float(c.world_age)) or float(c.world_age) < 0:
		return false
	if int(c.next_id) < 1 or not c.get("sound") is bool or not c.get("intro_seen") is bool:
		return false
	if not c.get("events") is Array or not c.get("plants") is Array:
		return false
	if c.plants.size() > SLOTS.size():
		return false
	var ids: Dictionary = {}
	for event in c.events:
		if not event is Dictionary:
			return false
		for key in ["id", "created_at", "created_age", "duration", "intensity"]:
			if not (event.get(key) is float or event.get(key) is int):
				return false
		if not event.get("kind") in ["mood", "deed", "practice"] or not event.get("note") is String or not event.get("emotions") is Array:
			return false
		for emotion in event.emotions:
			if not emotion is String:
				return false
		if ids.has(int(event.id)) or int(event.id) >= int(c.next_id):
			return false
		ids[int(event.id)] = true
	for plant in c.plants:
		if not plant is Dictionary or not plant.get("id") is String:
			return false
		for key in ["event_id", "slot", "born_age", "cycles"]:
			if not (plant.get(key) is float or plant.get(key) is int):
				return false
		if int(plant.slot) < 0 or int(plant.slot) >= SLOTS.size():
			return false
	return true

func load_or_create(now: int) -> bool:
	for source in [path, path + ".bak"]:
		if not FileAccess.file_exists(source):
			continue
		var file := FileAccess.open(source, FileAccess.READ)
		if file == null:
			continue
		var parser := JSON.new()
		if parser.parse(file.get_as_text()) != OK:
			continue
		var candidate: Variant = parser.data
		if valid(candidate):
			data = candidate
			# JSON represents all numbers as floats. Restore discrete counters.
			for key in ["version", "born_at", "last_tick", "next_id", "seed", "seeds"]:
				data[key] = int(data[key])
			for event in data.events:
				for key in ["id", "created_at", "duration", "intensity"]:
					event[key] = int(event[key])
			for plant in data.plants:
				for key in ["event_id", "slot", "cycles"]:
					plant[key] = int(plant[key])
			recovered_backup = source.ends_with(".bak")
			advance(now)
			return true
	if FileAccess.file_exists(path):
		load_warning = "Сохранение не удалось прочитать. Исходный файл сохранён отдельно."
		DirAccess.copy_absolute(path, path + ".unreadable")
	fresh(now)
	return false

func advance(now: int) -> void:
	var previous: int = int(data.last_tick)
	var elapsed: int = maxi(0, now - previous)
	data.world_age = float(data.world_age) + elapsed
	# A clock moved backwards must not age the same interval for a second time.
	data.last_tick = maxi(previous, now)
	for plant in data.plants:
		var age: float = maxf(0, float(data.world_age) - float(plant.born_age))
		var cycles: int = int(floor(age / FLOWER_CYCLE))
		if cycles > int(plant.cycles):
			data.seeds = int(data.seeds) + cycles - int(plant.cycles)
			plant.cycles = cycles

func phase(plant: Dictionary) -> int:
	var age: float = maxf(0, float(data.world_age) - float(plant.born_age))
	var progress: float = fmod(age, FLOWER_CYCLE) / FLOWER_CYCLE
	return mini(3, int(progress * 4.0))

func add_event(kind: String, note: String, emotions: Array, intensity: int, duration: int, now: int) -> int:
	assert(kind in ["mood", "deed", "practice"])
	advance(now)
	var event_id: int = int(data.next_id)
	data.next_id = event_id + 1
	data.events.append({"id": event_id, "kind": kind, "note": note.left(2000),
		"emotions": emotions.duplicate(), "intensity": clampi(intensity, 1, 5),
		"duration": maxi(0, duration), "created_at": now, "created_age": data.world_age})
	if kind == "deed":
		var used: Array = []
		for plant in data.plants:
			used.append(int(plant.slot))
		for slot in range(SLOTS.size()):
			if not slot in used:
				data.plants.append({"id": "event_%d" % event_id, "event_id": event_id,
					"slot": slot, "born_age": data.world_age, "cycles": 0})
				break
	return event_id

func remove_event(event_id: int) -> bool:
	var found: bool = false
	for i in range(data.events.size() - 1, -1, -1):
		if int(data.events[i].id) == event_id:
			data.events.remove_at(i)
			found = true
	for i in range(data.plants.size() - 1, -1, -1):
		if int(data.plants[i].event_id) == event_id:
			data.plants.remove_at(i)
	return found

func practice_seconds() -> int:
	var total: int = 0
	for event in data.events:
		if event.kind == "practice":
			total += int(event.duration)
	return total

func atmosphere() -> String:
	for i in range(data.events.size() - 1, -1, -1):
		var event: Dictionary = data.events[i]
		if event.kind != "mood":
			continue
		if float(data.world_age) - float(event.created_age) > 21600:
			return "clear"
		if "Грусть" in event.emotions:
			return "rain"
		if "Тревога" in event.emotions or "Злость" in event.emotions:
			return "wind"
		if "Не знаю" in event.emotions or "Усталость" in event.emotions:
			return "cloud"
		return "clear"
	return "clear"

func save() -> Error:
	var temporary := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if temporary == null:
		return FileAccess.get_open_error()
	temporary.store_string(JSON.stringify(data, "\t"))
	temporary.flush()
	var write_error: Error = temporary.get_error()
	temporary.close()
	if write_error != OK:
		return write_error
	# Never rotate a broken primary over the last readable backup.
	if FileAccess.file_exists(path) and not recovered_backup:
		var backup_error: Error = DirAccess.copy_absolute(path, path + ".bak")
		if backup_error != OK:
			return backup_error
	var error: Error = DirAccess.rename_absolute(path + ".tmp", path)
	if error == OK:
		recovered_backup = false
	return error
