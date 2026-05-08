extends Node2D
class_name FillKettleWaterStream

## Falling water stream from a faucet to a target Y. Renders a slightly
## wobbling translucent column with a brighter core. Disappears when
## `flowing` is false; persists for a brief tail-off afterward.
##
## Stream origin is this node's local (0,0). `target_y_func` is supplied
## by the controller — typically the current water surface inside the kettle.

@export var stream_width: float = 9.0
@export var max_length: float = 600.0
@export var flow_rate_visual: float = 1200.0  # px/sec — purely cosmetic for the falling motion

var flowing: bool = false
var target_y: float = 200.0
var _t: float = 0.0
var _tail_off: float = 0.0  # remaining seconds of "still falling but tap closed" stream

const STREAM_BODY := Color(0.55, 0.80, 0.95, 0.70)
const STREAM_CORE := Color(0.90, 0.97, 1.00, 0.85)
const STREAM_EDGE := Color(0.30, 0.55, 0.80, 0.55)

func _process(delta: float) -> void:
	_t += delta
	if not flowing:
		_tail_off = maxf(_tail_off - delta, 0.0)
	else:
		_tail_off = 0.18  # carry-over so the column doesn't snap to nothing
	queue_redraw()

func is_visible_now() -> bool:
	return flowing or _tail_off > 0.0

func _draw() -> void:
	if not is_visible_now():
		return
	if target_y <= 0.0:
		return

	var length: float = minf(target_y, max_length)
	# Stream is a vertical band with a small horizontal sine wobble that
	# accelerates downward, evoking accelerating fall.
	var segments := 14
	var left_pts := PackedVector2Array()
	var right_pts := PackedVector2Array()
	var core_left := PackedVector2Array()
	var core_right := PackedVector2Array()

	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var y: float = lerpf(0.0, length, t)
		# Wobble grows slightly with depth so the stream feels like falling water,
		# not a rigid pipe. Two sines for non-periodic look.
		var wobble: float = sin(_t * 9.0 - t * 5.0) * (1.2 + t * 1.6)
		wobble += sin(_t * 13.0 - t * 8.0) * (0.6 + t * 0.8)
		var width: float = stream_width * (0.92 + sin(_t * 7.0 - t * 4.0) * 0.08)
		# Slight narrowing as it falls (water column thins under acceleration)
		width *= lerpf(1.0, 0.78, t)

		left_pts.append(Vector2(wobble - width * 0.5, y))
		right_pts.append(Vector2(wobble + width * 0.5, y))
		core_left.append(Vector2(wobble - width * 0.18, y))
		core_right.append(Vector2(wobble + width * 0.18, y))

	# Outer translucent body (left points then right reversed)
	var body := PackedVector2Array()
	for p in left_pts:
		body.append(p)
	for i in range(right_pts.size() - 1, -1, -1):
		body.append(right_pts[i])

	var alpha_scale: float = 1.0
	if not flowing and _tail_off > 0.0:
		alpha_scale = clampf(_tail_off / 0.18, 0.0, 1.0)

	var body_color := STREAM_BODY
	body_color.a *= alpha_scale
	draw_colored_polygon(body, body_color)

	# Bright core
	var core := PackedVector2Array()
	for p in core_left:
		core.append(p)
	for i in range(core_right.size() - 1, -1, -1):
		core.append(core_right[i])
	var core_color := STREAM_CORE
	core_color.a *= alpha_scale
	draw_colored_polygon(core, core_color)

	# Edge highlights as polylines
	var edge_color := STREAM_EDGE
	edge_color.a *= alpha_scale
	draw_polyline(left_pts, edge_color, 1.5)
	draw_polyline(right_pts, edge_color, 1.5)

	# Falling specks for motion (two staggered stripes scrolling downward)
	for j in range(2):
		var phase: float = fmod(_t * flow_rate_visual + j * 60.0, 120.0)
		var y: float = phase
		while y < length:
			var t: float = y / length
			var wobble: float = sin(_t * 9.0 - t * 5.0) * (1.2 + t * 1.6)
			var c := Color(1, 1, 1, 0.55 * alpha_scale)
			draw_circle(Vector2(wobble + (1 if j == 0 else -1) * 1.5, y), 1.2, c)
			y += 18.0
