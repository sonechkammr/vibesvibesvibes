extends SceneTree

const Model = preload("res://scripts/garden_state.gd")
var checks: int = 0
var failures: int = 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func _initialize() -> void:
	var state := Model.new("user://state_test.json")
	state.fresh(1000000)
	check(state.data.plants.size() == 3, "A fresh garden has three plants")
	check(state.valid(state.data), "Initial schema is valid")
	var start_age: float = state.data.world_age
	state.advance(1000000 + 86400)
	check(is_equal_approx(state.data.world_age, start_age + 86400), "One day passes offline")
	state.advance(1000000 + 86400)
	check(is_equal_approx(state.data.world_age, start_age + 86400), "Reopening is idempotent")
	state.advance(1000000 - 100)
	check(is_equal_approx(state.data.world_age, start_age + 86400), "Clock rollback never de-ages the garden")
	state.advance(1000000 + 86400)
	check(is_equal_approx(state.data.world_age, start_age + 86400), "Clock recovery never double-counts elapsed time")
	state.advance(1000000 + 86400 * 9)
	var seeds: int = state.data.seeds
	check(seeds > 0, "Flowers leave seeds over time")
	state.advance(1000000 + 86400 * 9)
	check(state.data.seeds == seeds, "Reopening never grants duplicate seeds")
	check(state.data.plants.size() == 3, "Absence never removes plants")
	var now: int = 1000000 + 86400 * 9
	var sad_id: int = state.add_event("mood", "Трудный день", ["Грусть"], 4, 0, now)
	check(state.atmosphere() == "rain", "Sadness changes atmosphere")
	check(state.data.plants.size() == 3, "Sadness never damages or removes a plant")
	state.advance(now + 21601)
	check(state.atmosphere() == "clear", "Mood atmosphere expires without another check-in")
	state.remove_event(sad_id)
	var deed_id: int = state.add_event("deed", "Помогли другу", ["Помогли"], 1, 0, now + 21601)
	check(state.data.plants.size() == 4, "A deed leaves a visible plant")
	check(state.valid(state.data), "New events keep a valid schema")
	state.remove_event(deed_id)
	check(state.data.plants.size() == 3, "Deleting a mistaken deed removes only its own plant")
	var practice_id: int = state.add_event("practice", "Практика", [], 1, 180, now + 21601)
	check(state.practice_seconds() == 180, "Meditation duration is recorded")
	state.remove_event(practice_id)
	check(state.practice_seconds() == 0, "Deleting a practice recalculates its trace")
	check(state.save() == OK, "Atomic save succeeds")
	var restored := Model.new("user://state_test.json")
	check(restored.load_or_create(now + 21601), "Save loads")
	check(JSON.stringify(restored.data) == JSON.stringify(state.data), "Round-trip preserves serialized values")
	check(state.save() == OK, "Second save creates a backup")
	var broken := FileAccess.open("user://state_test.json", FileAccess.WRITE)
	broken.store_string("{not valid json")
	broken.close()
	var recovered := Model.new("user://state_test.json")
	check(recovered.load_or_create(now + 21601), "Backup recovers a damaged primary")
	check(recovered.recovered_backup, "Backup recovery is reported")
	check(recovered.save() == OK, "Recovered data can be saved")
	var many := Model.new()
	many.fresh(now)
	for i in range(40):
		many.add_event("deed", "Дело", [], 1, 0, now)
	check(many.data.plants.size() == Model.SLOTS.size(), "A full garden does not stack infinite sprites")
	check(many.data.events.size() == 40, "A full garden retains every journal entry")
	check(not state.valid({"version": 99}), "Unknown format is rejected")
	var malformed: Dictionary = state.data.duplicate(true)
	malformed.events.append({"id": "bad"})
	check(not state.valid(malformed), "Malformed imported entries are rejected")
	print("STATE %s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
