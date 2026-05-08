extends Node2D
class_name FillKettleWaterStream

## Falling water stream from a faucet to a target Y. Renders a slightly
## wobbling translucent column with a bright core. Disappears when
## `flowing` is false; persists for a brief tail-off afterward.

@export var stream_width: float = 9.0
@export var max_length: float = 600.0
@export var flow_rate_visual: float = 1200.0  # cosmetic px/sec for the falling specks

var flowing: bool = false
var target_y: float = 200.0
var _t: float = 0.0
var _tail_off: float = 0.0

func _process(delta: float) -> void:
	_t += delta
	if not flowing:
		_tail_off = maxf(_tail_off - delta, 0.0)
	else:
		_tail_off = 0.18
	queue_redraw()

func is_visible_now() -> bool:
	return flowing or _tail_off > 0.0

func _draw() -> void:
	if not is_visible_now():
		return
	if target_y <= 0.0:
		return

	var length: float = minf(target_y, max_length)
	var segments := 14
	var left_pts := PackedVector2Array()
	var right_pts := PackedVector2Array()
	var core_left := PackedVector2Array()
	var core_right := PackedVector2Array()

	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var y: float = lerpf(0.0, length, t)
		var wobble: float = sin(_t * 9.0 - t * 5.0) * (1.2 + t * 1.6)
		wobble += sin(_t * 13.0 - t * 8.0) * (0.6 + t * 0.8)
		var width: float = stream_width * (0.92 + sin(_t * 7.0 - t * 4.0) * 0.08)
		width *= lerpf(1.0, 0.78, t)

		left_pts.append(Vector2(wobble - width * 0.5, y))
		right_pts.append(Vector2(wobble + width * 0.5, y))
		core_left.append(Vector2(wobble - width * 0.18, y))
		core_right.append(Vector2(wobble + width * 0.18, y))

	var alpha_scale: float = 1.0
	if not flowing and _tail_off > 0.0:
		alpha_scale = clampf(_tail_off / 0.18, 0.0, 1.0)

	# Outer translucent body
	var body := PackedVector2Array()
	for p in left_pts:
		body.append(p)
	for i in range(right_pts.size() - 1, -1, -1):
		body.append(right_pts[i])
	var body_color: Color = Palette.WATER_LIGHT
	body_color.a = 0.70 * alpha_scale
	draw_colored_polygon(body, body_color)

	# Bright core
	var core := PackedVector2Array()
	for p in core_left:
		core.append(p)
	for i in range(core_right.size() - 1, -1, -1):
		core.append(core_right[i])
	var core_color: Color = Palette.WATER_HIGHLIGHT
	core_color.a = 0.85 * alpha_scale
	draw_colored_polygon(core, core_color)

	# Edge polylines (cool deeper rim)
	var edge_color: Color = Palette.WATER_MID
	edge_color.a = 0.60 * alpha_scale
	draw_polyline(left_pts, edge_color, 1.5, true)
	draw_polyline(right_pts, edge_color, 1.5, true)

	# Falling specks for motion
	for j in range(2):
		var phase: float = fmod(_t * flow_rate_visual + j * 60.0, 120.0)
		var y: float = phase
		while y < length:
			var t: float = y / length
			var wobble: float = sin(_t * 9.0 - t * 5.0) * (1.2 + t * 1.6)
			var c: Color = Palette.WATER_HIGHLIGHT
			c.a = 0.55 * alpha_scale
			draw_circle(Vector2(wobble + (1 if j == 0 else -1) * 1.5, y), 1.2, c)
			y += 18.0
