extends Control
class_name Faucet2D

## Brass goose-neck faucet with a tap handle and an animated water stream.
## Anchor: the spout tip is at (size.x - 8, height - 8). The faucet visually
## hangs from the wall above the sink.

signal toggled(is_on: bool)

const RISER_W: float = 14.0
const HANDLE_R: float = 12.0

var is_on: bool = false
var _stream_t: float = 0.0
var _click_button: Button = null

func _ready() -> void:
	custom_minimum_size = Vector2(120, 110)
	# Click area covers the handle so the player can tap it directly.
	_click_button = Button.new()
	_click_button.flat = true
	_click_button.focus_mode = Control.FOCUS_NONE
	_click_button.size = Vector2(60, 60)
	_click_button.position = Vector2(size.x - 70, 0)
	_click_button.pressed.connect(_on_handle_pressed)
	add_child(_click_button)
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if is_on:
		_stream_t += delta
		queue_redraw()

func set_on(state: bool) -> void:
	if is_on == state:
		return
	is_on = state
	toggled.emit(is_on)
	queue_redraw()

func _on_handle_pressed() -> void:
	set_on(not is_on)

func spout_tip_local() -> Vector2:
	# Where water exits — relative to this control's origin.
	return Vector2(40, size.y - 4)

func _draw() -> void:
	var top_y: float = 2.0
	var handle_cx: float = size.x - 30
	# Wall mount bracket.
	var bracket_rect := Rect2(handle_cx - 24, top_y, 48, 10)
	draw_rect(bracket_rect, Palette.BRASS_DARK)
	draw_rect(Rect2(bracket_rect.position, Vector2(bracket_rect.size.x, 2)), Palette.BRASS_LIGHT)

	# Riser — vertical brass column from the bracket down.
	var riser_top_y: float = top_y + 10
	var riser_bottom_y: float = top_y + 36
	var riser := Rect2(handle_cx - RISER_W * 0.5, riser_top_y, RISER_W, riser_bottom_y - riser_top_y)
	draw_rect(riser, Palette.BRASS_MID)
	draw_rect(
		Rect2(riser.position, Vector2(2, riser.size.y)),
		Palette.BRASS_LIGHT,
	)
	draw_rect(
		Rect2(riser.position + Vector2(riser.size.x - 2, 0), Vector2(2, riser.size.y)),
		Palette.BRASS_DARK,
	)

	# Goose-neck arc — Bezier-ish polyline from the riser down toward the spout.
	var arc_start: Vector2 = Vector2(handle_cx, riser_bottom_y)
	var arc_end: Vector2 = Vector2(40, size.y - 22)
	_draw_neck(arc_start, arc_end)

	# Spout tip — a small downward nozzle.
	var spout_tip: Vector2 = spout_tip_local()
	var spout := PackedVector2Array([
		Vector2(spout_tip.x - 6, spout_tip.y - 14),
		Vector2(spout_tip.x + 6, spout_tip.y - 14),
		Vector2(spout_tip.x + 5, spout_tip.y),
		Vector2(spout_tip.x - 5, spout_tip.y),
	])
	draw_colored_polygon(spout, Palette.BRASS_DARK)
	draw_colored_polygon(PackedVector2Array([
		Vector2(spout_tip.x - 6, spout_tip.y - 13),
		Vector2(spout_tip.x - 4, spout_tip.y - 13),
		Vector2(spout_tip.x - 4, spout_tip.y - 1),
		Vector2(spout_tip.x - 6, spout_tip.y - 1),
	]), Palette.BRASS_LIGHT)

	# Handle — circle in front of the riser-top. Rotated when on (visual cue).
	var handle_center: Vector2 = Vector2(handle_cx + 18, riser_top_y + 12)
	draw_circle(handle_center, HANDLE_R + 2, Palette.BRASS_DARK)
	draw_circle(handle_center, HANDLE_R, Palette.BRASS_MID)
	var bar_angle: float = PI * 0.5 if is_on else 0.0
	var bar_len: float = HANDLE_R - 2
	var c: float = cos(bar_angle)
	var s: float = sin(bar_angle)
	draw_line(
		handle_center + Vector2(-c * bar_len, -s * bar_len),
		handle_center + Vector2(c * bar_len, s * bar_len),
		Palette.BRASS_LIGHT, 3.0, true,
	)
	draw_line(
		handle_center + Vector2(-s * bar_len, c * bar_len),
		handle_center + Vector2(s * bar_len, -c * bar_len),
		Palette.BRASS_LIGHT, 3.0, true,
	)
	draw_circle(handle_center, 2.5, Palette.BRASS_SHINE)
	# Update click button position to overlap the handle.
	if _click_button:
		_click_button.position = handle_center - Vector2(30, 30)
		_click_button.size = Vector2(60, 60)

	# Water stream when on.
	if is_on:
		_draw_stream(spout_tip)

func _draw_neck(a: Vector2, b: Vector2) -> void:
	# Quadratic curve from a → control → b, control offset down/left for a
	# convincing goose-neck arc.
	var control: Vector2 = Vector2(a.x - 24, a.y + 8)
	var pts := PackedVector2Array()
	var steps: int = 18
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var p: Vector2 = a.lerp(control, t).lerp(control.lerp(b, t), t)
		pts.append(p)
	# Thick brass body
	draw_polyline(pts, Palette.BRASS_DARK, 14.0, true)
	draw_polyline(pts, Palette.BRASS_MID, 11.0, true)
	# Lit highlight along the upper-left side
	var lit_pts: PackedVector2Array = PackedVector2Array()
	for p in pts:
		lit_pts.append(p + Vector2(-1.5, -1.5))
	draw_polyline(lit_pts, Palette.BRASS_LIGHT, 2.5, true)

func _draw_stream(tip_local: Vector2) -> void:
	# Stream falls from spout tip to the bottom edge of this control's
	# visible area; the kettle below catches it. Wobble for life.
	var stream_top: Vector2 = tip_local + Vector2(0, 0)
	var stream_bottom: Vector2 = Vector2(tip_local.x, size.y + 60)
	var pts := PackedVector2Array()
	var pts_right := PackedVector2Array()
	var steps: int = 12
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var y: float = lerpf(stream_top.y, stream_bottom.y, t)
		var wobble: float = sin(_stream_t * 14.0 + t * 6.28) * 1.5
		var x_center: float = lerpf(stream_top.x, stream_bottom.x, t) + wobble
		pts.append(Vector2(x_center - 3, y))
		pts_right.append(Vector2(x_center + 3, y))
	# Stream body (mid water)
	var combined := PackedVector2Array()
	for p in pts:
		combined.append(p)
	for i in range(pts_right.size() - 1, -1, -1):
		combined.append(pts_right[i])
	draw_colored_polygon(combined, Palette.WATER_MID)
	# Lit edge along the left.
	draw_polyline(pts, Palette.WATER_HIGHLIGHT, 1.5, true)
	# Splash near the spout — tiny droplets that float briefly.
	var splash_count: int = 3
	for j in range(splash_count):
		var phase: float = fmod(_stream_t * 3.0 + j * 0.3, 1.0)
		var dy: float = phase * 18.0
		var dx: float = sin(_stream_t * 8.0 + j) * 6.0
		var alpha: float = (1.0 - phase) * 0.8
		draw_circle(
			Vector2(tip_local.x + dx, tip_local.y + dy),
			1.5,
			Color(Palette.WATER_HIGHLIGHT.r, Palette.WATER_HIGHLIGHT.g, Palette.WATER_HIGHLIGHT.b, alpha),
		)
