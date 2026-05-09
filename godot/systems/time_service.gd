extends Node

## TimeService — the two clocks per DESIGN.md 4.1.
##
## Two clocks that never run simultaneously:
##   - day_clock: int. Advances only on Dashboard's "Get some rest" tap.
##   - scene_clock: float seconds. Runs only inside an active mini-game scene.
##
## Pause semantics:
##   - Closing the app freezes the scene clock cleanly (engine pause).
##   - Phone or modal up: get_tree().paused = true short-circuits _process.
##   - The day clock is monotonic; only advance_day() increments it.
##
## Pending events are an ordered list of {id, t} dicts; emit event_pending
## with `time_until_seconds = event.t - scene_clock` whenever the gap crosses
## one of the warning thresholds. Mini-game scenes consume these to drive
## hop drops, boil-over warnings, etc.

signal day_advanced(new_day: int)
signal tick(delta: float)
signal event_pending(event_id: String, time_until_seconds: float)
signal scene_started
signal scene_ended

const WARNING_THRESHOLDS_S := [10.0, 5.0, 2.0, 0.0]

var day_clock: int = 0
var scene_clock: float = 0.0

var _scene_clock_running: bool = false
var _pending_events: Array = []  # Array of {"id": String, "t": float, "warned": Array[float]}

func advance_day() -> void:
	# Called only by the Dashboard's "Get some rest" button.
	# It is a hard error to advance the day while a mini-game scene is live.
	assert(not _scene_clock_running, "TimeService.advance_day() while scene_clock is running")
	day_clock += 1
	day_advanced.emit(day_clock)

func start_scene(events: Array = []) -> void:
	# Called by ActiveSceneContainer when a new mini-game scene mounts.
	# `events` is a list of {"id": String, "t": float} sorted by t ascending.
	scene_clock = 0.0
	_pending_events.clear()
	for e in events:
		var rec := {"id": String(e.get("id", "")), "t": float(e.get("t", 0.0)), "warned": []}
		_pending_events.append(rec)
	_scene_clock_running = true
	scene_started.emit()

func end_scene() -> void:
	_scene_clock_running = false
	_pending_events.clear()
	scene_clock = 0.0
	scene_ended.emit()

func is_scene_running() -> bool:
	return _scene_clock_running

func _process(delta: float) -> void:
	if not _scene_clock_running:
		return
	if get_tree().paused:
		# Phone or modal is up — don't tick.
		return
	scene_clock += delta
	tick.emit(delta)
	_check_pending_events()

func _check_pending_events() -> void:
	for event in _pending_events:
		var until: float = float(event["t"]) - scene_clock
		var warned: Array = event["warned"]
		for thresh in WARNING_THRESHOLDS_S:
			if until <= float(thresh) and not warned.has(thresh):
				warned.append(thresh)
				event_pending.emit(String(event["id"]), max(until, 0.0))
				break
