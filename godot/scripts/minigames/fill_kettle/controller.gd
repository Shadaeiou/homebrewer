extends Control

## Fill-the-kettle mini-game controller.
##
## Player presses & holds POUR to open the faucet; release to close. Tap DONE
## when the kettle reads close to the target. Grade is based on |actual-target|.

const TARGET_LITRES: float = 4.00
const FILL_RATE_LITRES_PER_SEC: float = 1.6
const OVERFLOW_THRESHOLD: float = 6.0  # capacity_litres in WaterBody

const GRADE_THRESHOLDS := [
	{"grade": "A+", "tolerance": 0.04},  # within 40 mL
	{"grade": "A",  "tolerance": 0.10},
	{"grade": "B",  "tolerance": 0.20},
	{"grade": "C",  "tolerance": 0.40},
	{"grade": "D",  "tolerance": 0.80},
]

enum State { READY, PLAYING, DONE }

@onready var kettle: FillKettleVessel = $Stage/Kettle
@onready var water_body: FillKettleWaterBody = $Stage/Kettle/Water
@onready var faucet: FillKettleFaucet = $Stage/Faucet
@onready var stream: FillKettleWaterStream = $Stage/Faucet/Stream
@onready var splashes: CPUParticles2D = $Stage/Splashes
@onready var steam: CPUParticles2D = $Stage/Steam

@onready var target_label: Label = %TargetLabel
@onready var current_label: Label = %CurrentLabel
@onready var instruction_label: Label = %InstructionLabel
@onready var pour_button: Button = %PourButton
@onready var done_button: Button = %DoneButton
@onready var back_button: Button = %BackButton
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_grade_label: Label = %ResultGradeLabel
@onready var result_detail_label: Label = %ResultDetailLabel
@onready var retry_button: Button = %RetryButton
@onready var return_button: Button = %ReturnButton
@onready var target_zone: ColorRect = %TargetZone
@onready var gauge_fill: ColorRect = %GaugeFill

var state: int = State.READY
var pouring: bool = false

func _ready() -> void:
	target_label.text = "Target: %.2f L" % TARGET_LITRES
	pour_button.button_down.connect(_on_pour_pressed)
	pour_button.button_up.connect(_on_pour_released)
	done_button.pressed.connect(_on_done)
	back_button.pressed.connect(_return_home)
	retry_button.pressed.connect(_reset)
	return_button.pressed.connect(_return_home)
	result_panel.visible = false
	_position_target_zone()
	_update_labels()

func _position_target_zone() -> void:
	# Visual gauge target band: a narrow horizontal stripe at TARGET_LITRES
	# inside the side gauge frame.
	var gauge: Control = %Gauge
	var capacity: float = water_body.capacity_litres
	var gauge_height: float = gauge.size.y
	var center_y: float = (1.0 - TARGET_LITRES / capacity) * gauge_height
	var tolerance: float = 0.20  # visual band corresponds to "B" grade tolerance
	var band_h: float = (tolerance / capacity) * gauge_height * 2.0
	target_zone.position = Vector2(0, center_y - band_h * 0.5)
	target_zone.size = Vector2(gauge.size.x, band_h)

func _process(delta: float) -> void:
	if state == State.PLAYING and pouring:
		water_body.fill_litres = min(
			water_body.fill_litres + FILL_RATE_LITRES_PER_SEC * delta,
			OVERFLOW_THRESHOLD
		)
		water_body.time_since_last_pour = 0.0
		water_body.pour_intensity = 1.0
		_update_labels()
		_update_gauge()
		if water_body.fill_litres >= OVERFLOW_THRESHOLD:
			_on_overflow()
	elif state == State.PLAYING:
		water_body.pour_intensity = max(water_body.pour_intensity - delta * 1.5, 0.0)

	# Update the stream: it falls from faucet origin to current water surface.
	stream.target_y = _stream_target_length()
	stream.flowing = pouring and state == State.PLAYING

	# Splashes when the stream is hitting the water
	if pouring and state == State.PLAYING:
		splashes.position = _splash_position()
		splashes.emitting = true
	else:
		splashes.emitting = false

	# Steam: rises from just above the current water surface whenever the
	# kettle has water in it. Don't touch `amount` at runtime — assigning
	# CPUParticles2D.amount resets the particle pool every frame, killing
	# every particle before it can fade in.
	if water_body.fill_litres > 0.05:
		var stage := steam.get_parent() as Node2D
		var surface_world: Vector2 = kettle.global_position + Vector2(0, water_body.surface_y())
		steam.position = stage.to_local(surface_world) + Vector2(0, -8)
		steam.emitting = true
	else:
		steam.emitting = false

func _stream_target_length() -> float:
	# Convert kettle interior coordinates (kettle origin) to the stream's
	# parent-local coordinates (faucet origin). Stream falls straight down
	# from (0,0) of its parent.
	var faucet_origin_world := faucet.global_position
	var surface_world := kettle.global_position + Vector2(0, water_body.surface_y())
	return max(surface_world.y - faucet_origin_world.y, 0.0)

func _splash_position() -> Vector2:
	# Splashes spawn at the water surface, in the stage's coordinate space.
	# `splashes` lives under $Stage so we return stage-local coords.
	var stage := splashes.get_parent() as Node2D
	var surface_world := kettle.global_position + Vector2(0, water_body.surface_y())
	return stage.to_local(surface_world)

func _on_pour_pressed() -> void:
	if state == State.DONE:
		return
	if state == State.READY:
		state = State.PLAYING
	pouring = true
	faucet.open = true
	faucet.queue_redraw()

func _on_pour_released() -> void:
	pouring = false
	faucet.open = false
	faucet.queue_redraw()

func _on_done() -> void:
	if state == State.DONE:
		return
	if state == State.READY:
		# Nothing poured — grade as F immediately
		state = State.PLAYING
	pouring = false
	faucet.open = false
	faucet.queue_redraw()
	_finish()

func _on_overflow() -> void:
	pouring = false
	faucet.open = false
	faucet.queue_redraw()
	_finish(true)

func _finish(overflowed: bool = false) -> void:
	state = State.DONE
	var actual := water_body.fill_litres
	var diff := absf(actual - TARGET_LITRES)
	var grade := "F"
	if not overflowed:
		for entry in GRADE_THRESHOLDS:
			if diff <= entry.tolerance:
				grade = entry.grade
				break
	result_grade_label.text = grade
	result_grade_label.modulate = _color_for_grade(grade)
	if overflowed:
		result_detail_label.text = "Boil over! Kettle overflowed at %.2f L (target %.2f L)." % [actual, TARGET_LITRES]
	else:
		var dir := "over" if actual > TARGET_LITRES else "under"
		result_detail_label.text = "%.2f L poured · %.2f L %s target" % [actual, diff, dir]
	result_panel.visible = true

func _color_for_grade(grade: String) -> Color:
	match grade:
		"A+": return Color(0.55, 0.95, 0.55)
		"A": return Color(0.65, 0.92, 0.55)
		"B": return Color(0.92, 0.92, 0.45)
		"C": return Color(0.95, 0.75, 0.30)
		"D": return Color(0.95, 0.55, 0.30)
		_: return Color(0.95, 0.40, 0.40)

func _reset() -> void:
	state = State.READY
	pouring = false
	water_body.fill_litres = 0.0
	water_body.pour_intensity = 0.0
	water_body.time_since_last_pour = 999.0
	faucet.open = false
	faucet.queue_redraw()
	result_panel.visible = false
	_update_labels()
	_update_gauge()

func _return_home() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _update_labels() -> void:
	current_label.text = "%.2f L" % water_body.fill_litres
	if state == State.READY:
		instruction_label.text = "Hold POUR to fill the kettle. Tap DONE when ready."
	elif state == State.PLAYING:
		instruction_label.text = "Hold POUR. Watch the gauge."
	else:
		instruction_label.text = ""

func _update_gauge() -> void:
	var gauge: Control = %Gauge
	var capacity: float = water_body.capacity_litres
	var gauge_height: float = gauge.size.y
	var fill_h: float = (water_body.fill_litres / capacity) * gauge_height
	gauge_fill.position = Vector2(0, gauge_height - fill_h)
	gauge_fill.size = Vector2(gauge.size.x, fill_h)
