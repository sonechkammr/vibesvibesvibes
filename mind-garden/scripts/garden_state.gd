class_name GardenState
extends RefCounted

const FORMAT_VERSION: int = 2
const FLOWER_CYCLE: float = 4.0 * 86400.0
const LAND_COUNT: int = 18
const SLOTS: Array[Vector2] = [Vector2(65,209),Vector2(115,205),Vector2(165,205),Vector2(215,205),Vector2(265,209),Vector2(308,216),Vector2(77,260),Vector2(130,258),Vector2(183,259),Vector2(237,259),Vector2(288,259),Vector2(331,253),Vector2(281,530),Vector2(335,520),Vector2(389,525),Vector2(279,570),Vector2(333,568),Vector2(387,566),Vector2(393,197),Vector2(435,194),Vector2(477,202),Vector2(397,247),Vector2(440,244),Vector2(480,249)]
const PATTERNS: Array[String] = ["opens", "transitions", "walks", "revisions", "draft_changes", "practices", "early_finishes", "longer_restarts", "entries"]
var path: String = "user://garden.json"
var data: Dictionary = {}
var recovered_backup: bool = false
var load_warning: String = ""

func _init(save_path: String = "user://garden.json") -> void:
	path = save_path

func fresh(now: int) -> void:
	data = {"version":2,"born_at":now,"last_tick":now,"world_age":0.0,"next_id":1,"events":[],"plants":[],"sound":true,"seed":170319,"seeds":0,"intro_seen":false,"patterns":{},"draft":{"states":{},"deeds":[],"note":""},"traces":[],"last_practice_target":0,"last_practice_early":false}
	for key in PATTERNS:
		data.patterns[key] = 0
	for i in range(3):
		data.plants.append({"id":"initial_%d" % i,"event_id":0,"slot":i,"born_age":-190000.0+float(i)*30000.0,"cycles":0,"species":i})

func valid(candidate: Variant) -> bool:
	if not candidate is Dictionary:
		return false
	var c: Dictionary = candidate
	if int(c.get("version",-1)) != 2:
		return false
	for key in ["born_at","last_tick","world_age","next_id","seed","seeds"]:
		if not (c.get(key) is float or c.get(key) is int) or not is_finite(float(c[key])):
			return false
	if float(c.world_age)<0 or int(c.next_id)<1 or not c.get("sound") is bool or not c.get("intro_seen") is bool:
		return false
	if not c.get("events") is Array or not c.get("plants") is Array or not c.get("patterns") is Dictionary or not c.get("draft") is Dictionary or not c.get("traces") is Array:
		return false
	if c.plants.size()>SLOTS.size() or c.traces.size()>48:
		return false
	if not _valid_entry(c.draft):
		return false
	for key in PATTERNS:
		if not (c.patterns.get(key) is int or c.patterns.get(key) is float) or float(c.patterns[key])<0:
			return false
	var ids: Dictionary = {}
	for event in c.events:
		if not event is Dictionary or not _valid_entry(event):
			return false
		for key in ["id","created_at","created_age","duration","intensity"]:
			if not (event.get(key) is float or event.get(key) is int) or not is_finite(float(event[key])):
				return false
		if not event.get("kind") in ["mood","deed","practice","entry"] or not event.get("emotions") is Array:
			return false
		if int(event.id)<1 or ids.has(int(event.id)) or int(event.id)>=int(c.next_id):
			return false
		ids[int(event.id)] = true
	var slots: Dictionary = {}
	for plant in c.plants:
		if not plant is Dictionary or not plant.get("id") is String:
			return false
		for key in ["event_id","slot","born_age","cycles","species"]:
			if not (plant.get(key) is int or plant.get(key) is float):
				return false
		var slot: int = int(plant.slot)
		var species: int = int(plant.species)
		if slot<0 or slot>=SLOTS.size() or slots.has(slot) or species<0 or species>6 or (slot<LAND_COUNT)!=(species<4):
			return false
		slots[slot] = true
	return true

func _valid_entry(e: Dictionary) -> bool:
	if not e.get("states") is Dictionary or not e.get("deeds") is Array or not e.get("note") is String:
		return false
	for key in e.states:
		if not key is String or not (e.states[key] is float or e.states[key] is int) or not is_finite(float(e.states[key])) or float(e.states[key])<0 or float(e.states[key])>100:
			return false
	for deed in e.deeds:
		if not deed is String:
			return false
	return true

func migrate(candidate: Dictionary) -> Dictionary:
	if int(candidate.get("version",-1)) != 1:
		return candidate
	var c: Dictionary = candidate.duplicate(true)
	if not c.get("events") is Array or not c.get("plants") is Array:
		return {}
	c.version = 2
	c.patterns = {}
	for key in PATTERNS:
		c.patterns[key] = 0
	c.draft = {"states":{},"deeds":[],"note":""}
	c.traces = []
	c.last_practice_target = 0
	c.last_practice_early = false
	for e in c.events:
		if not e is Dictionary or not e.get("emotions") is Array or not (e.get("intensity") is int or e.get("intensity") is float):
			return {}
		e.states = {}
		e.deeds = []
		e.legacy_intensity = int(e.intensity)
		if e.get("kind") == "mood":
			for emotion in e.emotions:
				e.states[emotion] = clampi(int(e.intensity)*20,0,100)
		elif e.get("kind") == "deed":
			e.deeds = e.emotions.duplicate()
	for plant in c.plants:
		if not plant is Dictionary or not (plant.get("slot") is float or plant.get("slot") is int):
			return {}
		plant.species = int(plant.slot)%4
	return c

func load_or_create(now: int) -> bool:
	for source in [path,path+".bak"]:
		if not FileAccess.file_exists(source):
			continue
		var file := FileAccess.open(source,FileAccess.READ)
		if file == null:
			continue
		var parser := JSON.new()
		if parser.parse(file.get_as_text()) != OK:
			continue
		var candidate: Variant = parser.data
		if not candidate is Dictionary:
			continue
		var legacy: bool = int(candidate.get("version",-1))==1
		candidate = migrate(candidate)
		if valid(candidate):
			if legacy and not FileAccess.file_exists(path+".v1"):
				if DirAccess.copy_absolute(source,path+".v1") != OK:
					load_warning = "Не удалось сделать копию прежнего сохранения."
			data = candidate
			_normalize()
			recovered_backup = source.ends_with(".bak")
			advance(now)
			return true
	if FileAccess.file_exists(path):
		load_warning = "Сохранение не удалось прочитать. Исходный файл сохранён отдельно."
		DirAccess.copy_absolute(path,path+".unreadable")
	fresh(now)
	return false

func _normalize() -> void:
	for key in ["version","born_at","last_tick","next_id","seed","seeds","last_practice_target"]:
		data[key] = int(data.get(key,0))
	for key in PATTERNS:
		data.patterns[key] = int(data.patterns[key])
	for event in data.events:
		for key in ["id","created_at","duration","intensity"]:
			event[key] = int(event[key])
		for key in event.states:
			event.states[key] = int(event.states[key])
	for plant in data.plants:
		for key in ["event_id","slot","cycles","species"]:
			plant[key] = int(plant[key])
	for key in data.draft.states:
		data.draft.states[key] = int(data.draft.states[key])

func advance(now: int) -> void:
	var elapsed: int = maxi(0,now-int(data.last_tick))
	data.world_age = float(data.world_age)+elapsed
	data.last_tick = maxi(int(data.last_tick),now)
	for plant in data.plants:
		var cycles: int = int(floor(maxf(0,float(data.world_age)-float(plant.born_age))/FLOWER_CYCLE))
		if cycles>int(plant.cycles):
			data.seeds = int(data.seeds)+cycles-int(plant.cycles)
			plant.cycles = cycles

func phase(plant: Dictionary) -> int:
	return mini(3,int(fmod(maxf(0,float(data.world_age)-float(plant.born_age)),FLOWER_CYCLE)/FLOWER_CYCLE*4.0))

func add_event(kind: String,note: String,emotions: Array,intensity: int,duration: int,now: int) -> int:
	var states: Dictionary = {}
	if kind == "mood":
		for emotion in emotions:
			states[emotion] = clampi(intensity*20,0,100)
	return add_entry(states,emotions if kind=="deed" else [],note,now,kind,duration)

func add_entry(states: Dictionary,deeds: Array,note: String,now: int,kind: String="entry",duration: int=0) -> int:
	advance(now)
	var event_id: int = int(data.next_id)
	data.next_id = event_id+1
	data.events.append({"id":event_id,"kind":kind,"note":note.left(2000),"states":states.duplicate(true),"deeds":deeds.duplicate(),"emotions":states.keys() if kind!="deed" else deeds.duplicate(),"intensity":1,"duration":maxi(0,duration),"created_at":now,"created_age":data.world_age})
	pattern("practices" if kind=="practice" else "entries")
	if kind in ["practice","deed"] or not deeds.is_empty():
		spawn_plant(event_id)
	return event_id

func edit_entry(id: int,states: Dictionary,deeds: Array,note: String) -> void:
	for e in data.events:
		if int(e.id)==id:
			e.states = states.duplicate(true)
			e.deeds = deeds.duplicate()
			e.emotions = states.keys()
			e.note = note.left(2000)
			e.erase("legacy_intensity")
			pattern("revisions")
			return

func spawn_plant(event_id: int=0) -> void:
	var used: Dictionary = {}
	for p in data.plants:
		used[int(p.slot)] = true
	var order: int = int(data.patterns.entries)+int(data.patterns.practices)+int(data.patterns.opens)
	for offset in range(SLOTS.size()):
		var slot: int = (order*7+offset)%SLOTS.size()
		if not used.has(slot):
			data.plants.append({"id":"plant_%d_%d" % [event_id,slot],"event_id":event_id,"slot":slot,"born_age":data.world_age,"cycles":0,"species":order%4 if slot<LAND_COUNT else 4+(slot-LAND_COUNT)%3})
			return
	data.seeds = int(data.seeds)+1

func pattern(key: String,amount: int=1) -> void:
	if not key in PATTERNS:
		return
	var old: int = int(data.patterns[key])
	data.patterns[key] = old+maxi(0,amount)
	var step: int = 3 if key in ["opens","practices","entries","longer_restarts"] else 8
	if floori(float(data.patterns[key])/float(step))>floori(float(old)/float(step)):
		data.traces.append({"kind":key,"variant":floori(float(data.patterns[key])/float(step)),"age":data.world_age})
		if data.traces.size()>48:
			data.traces.pop_front()

func remove_event(event_id: int) -> bool:
	var found := false
	for i in range(data.events.size()-1,-1,-1):
		if int(data.events[i].id)==event_id:
			data.events.remove_at(i)
			found = true
	for i in range(data.plants.size()-1,-1,-1):
		if int(data.plants[i].event_id)==event_id:
			data.plants.remove_at(i)
	return found

func practice_seconds() -> int:
	var total: int = 0
	for e in data.events:
		if e.kind=="practice":
			total += int(e.duration)
	return total

func atmosphere_detail() -> Dictionary:
	var mapping := {"Грусть":"rain","Тревога":"wind","Злость":"wind","Усталость":"cloud","Не знаю":"cloud"}
	for i in range(data.events.size()-1,-1,-1):
		var e: Dictionary = data.events[i]
		if e.states.is_empty():
			continue
		var age: float = float(data.world_age)-float(e.created_age)
		if age>21600:
			break
		var result := {"kind":"clear","strength":0.0}
		for key in mapping:
			var strength: float = float(e.states.get(key,0))/100.0*(1.0-age/21600.0)
			if strength>float(result.strength):
				result = {"kind":mapping[key],"strength":strength}
		return result
	return {"kind":"clear","strength":0.0}

func atmosphere() -> String:
	return atmosphere_detail().kind

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
