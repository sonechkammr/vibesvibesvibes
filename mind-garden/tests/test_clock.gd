extends SceneTree
const Clock = preload("res://scripts/meditation_clock.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var c := Clock.new()
	c.start(60,10000)
	check(c.tick(10000).strikes==1,"First strike starts at time zero")
	c.tick(10750)
	check(is_equal_approx(c.elapsed,0.75),"Opening strikes count as meditation time")
	check(c.tick(13499).strikes==0,"No second strike before interval")
	check(c.tick(13500).strikes==1,"Second strike at 3.5 seconds")
	check(c.tick(17000).strikes==1,"Third strike at 7 seconds")
	c.pause(18000)
	check(c.state=="paused" and c.elapsed==8,"Pause accounts for elapsed time")
	c.tick(50000)
	check(c.elapsed==8,"Pause time is excluded")
	c.resume(50000)
	c.tick(51000)
	check(c.elapsed==9,"Resume continues without reset")
	check(c.tick(102000).finished,"Completion catches up after a frame gap")
	check(c.elapsed==60,"Recorded duration is clamped to target")
	check(not c.tick(103000).finished,"Completion fires exactly once")
	c.start(900,100)
	var gap: Dictionary = c.tick(120100)
	check(c.elapsed==120 and c.state=="running","Timer catches up after focus loss")
	check(gap.strikes==0,"Missed opening strikes do not replay in a burst")
	c.start(0,100)
	c.tick(3600100)
	check(c.state=="running" and c.elapsed==3600,"Open-ended practice has no forced finish")
	c.stop()
	check(c.state=="idle","Early stop is explicit")
	print("CLOCK %s: %d checks, %d failures" % ["PASS" if failures==0 else "FAIL",checks,failures])
	quit(0 if failures==0 else 1)
