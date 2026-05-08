extends Node2D
class_name FillKettleFaucet

## Procedural faucet: a wall-mounted spout. Origin is the lip of the spout
## where water emerges (so a sibling WaterStream node can be positioned at
## this transform.origin and fall straight down).

@export var pipe_length: float = 80.0
@export var pipe_radius: float = 14.0
@export var spout_length: float = 70.0
@export var handle_length: float = 36.0

var open: bool = false

const COLOR_FIXTURE_LIGHT := Color(0.84, 0.86, 0.88)
const COLOR_FIXTURE := Color(0.62, 0.64, 0.66)
const COLOR_FIXTURE_DARK := Color(0.36, 0.38, 0.40)
const COLOR_OUTLINE := Color(0.10, 0.10, 0.12)
const COLOR_HANDLE := Color(0.80, 0.30, 0.22)
const COLOR_HANDLE_OPEN := Color(0.45, 0.78, 0.40)

func _draw() -> void:
	# The spout (vertical pipe terminating at origin pointing down) is the
	# anchor; we draw a horizontal arm leading off to the right + a hot/cold
	# handle on top of the arm.

	# Vertical down-spout: wall-thick rectangle ending at origin
	var spout_top := -spout_length
	var spout_rect := Rect2(-pipe_radius, spout_top, pipe_radius * 2.0, spout_length + 2.0)
	draw_rect(spout_rect, COLOR_FIXTURE)
	# Highlight on left
	var hl := Rect2(-pipe_radius, spout_top, pipe_radius * 0.35, spout_length + 2.0)
	draw_rect(hl, COLOR_FIXTURE_LIGHT)
	# Shadow on right
	var sh := Rect2(pipe_radius * 0.55, spout_top, pipe_radius * 0.45, spout_length + 2.0)
	draw_rect(sh, COLOR_FIXTURE_DARK)
	draw_rect(spout_rect, COLOR_OUTLINE, false, 2.0)

	# Spout cap (a wider lip at the bottom where water exits)
	var cap := Rect2(-pipe_radius - 4.0, -10.0, (pipe_radius + 4.0) * 2.0, 12.0)
	draw_rect(cap, COLOR_FIXTURE)
	draw_rect(cap, COLOR_OUTLINE, false, 2.0)

	# Horizontal arm going up and to the right, joining the spout near its top
	var arm_height := 22.0
	var arm_y := spout_top - arm_height + 8.0
	var arm_w := pipe_length
	var arm_rect := Rect2(-pipe_radius * 0.4, arm_y, arm_w, arm_height)
	draw_rect(arm_rect, COLOR_FIXTURE)
	draw_rect(arm_rect, COLOR_OUTLINE, false, 2.0)

	# Wall flange where arm meets the wall
	var flange := Rect2(arm_w - 10.0, arm_y - 8.0, 18.0, arm_height + 16.0)
	draw_rect(flange, COLOR_FIXTURE_DARK)
	draw_rect(flange, COLOR_OUTLINE, false, 2.0)

	# Handle on top of the arm. Tilts when open.
	var handle_anchor := Vector2(arm_w * 0.45, arm_y + 2.0)
	var tilt := -0.55 if open else 0.0
	var handle_color := COLOR_HANDLE_OPEN if open else COLOR_HANDLE
	# Handle stem (a small base block)
	draw_rect(Rect2(handle_anchor.x - 5.0, handle_anchor.y - 6.0, 10.0, 8.0), COLOR_FIXTURE_DARK)
	# Handle bar (rotates around its base)
	var bar_origin := handle_anchor + Vector2(0, -6)
	var bar_dir := Vector2(cos(-PI / 2.0 + tilt), sin(-PI / 2.0 + tilt))
	var bar_perp := Vector2(-bar_dir.y, bar_dir.x)
	var bar_far := bar_origin + bar_dir * handle_length
	var bar_w := 7.0
	var bar_pts := PackedVector2Array([
		bar_origin + bar_perp * bar_w,
		bar_far + bar_perp * bar_w,
		bar_far - bar_perp * bar_w,
		bar_origin - bar_perp * bar_w,
	])
	draw_colored_polygon(bar_pts, handle_color)
	draw_polyline(PackedVector2Array([
		bar_origin + bar_perp * bar_w,
		bar_far + bar_perp * bar_w,
		bar_far - bar_perp * bar_w,
		bar_origin - bar_perp * bar_w,
		bar_origin + bar_perp * bar_w,
	]), COLOR_OUTLINE, 1.5)

	# Knob at far end of the handle bar
	draw_circle(bar_far, 8.0, handle_color)
	draw_arc(bar_far, 8.0, 0, TAU, 18, COLOR_OUTLINE, 1.5)

	# Tiny "H/C" mark on the flange
	var mark_pos := Vector2(arm_w + 2.0, arm_y + arm_height * 0.5 - 4.0)
	draw_circle(mark_pos, 2.0, COLOR_HANDLE)
