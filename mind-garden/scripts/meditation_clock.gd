class_name MeditationClock
extends RefCounted

var state: String = "idle"
var target: float = 0.0
var elapsed: float = 0.0
var anchor_ms: int = 0
var carried: float = 0.0
var next_strike: int = 0
const INTERVAL: float = 3.5

func start(seconds: int,now_ms: int) -> void:
	target = seconds
	elapsed = 0
	carried = 0
	anchor_ms = now_ms
	next_strike = 0
	state = "running"

func tick(now_ms: int) -> Dictionary:
	var strikes: int = 0
	var finished := false
	if state=="running":
		elapsed = carried+maxf(0,float(now_ms-anchor_ms)/1000.0)
		if target>0 and elapsed>=target:
			elapsed = target
			state = "finished"
			finished = true
		elif next_strike<3 and elapsed>=next_strike*INTERVAL:
			# Missed opening sounds after suspension are skipped, never replayed in a burst.
			strikes = 1 if elapsed-next_strike*INTERVAL<0.6 else 0
			next_strike = mini(3,int(elapsed/INTERVAL)+1)
	return {"strikes":strikes,"finished":finished}

func pause(now_ms: int) -> void:
	tick(now_ms)
	if state=="running":
		carried = elapsed
		state = "paused"

func resume(now_ms: int) -> void:
	if state=="paused":
		anchor_ms = now_ms
		state = "running"

func stop() -> void:
	state = "idle"
