extends Node2D
class_name FillKettleFaucet

## Procedural wall-mounted faucet. Origin is the lip of the spout where water
## emerges so a sibling WaterStream can be at this transform.origin and fall
## straight down.
##
## Body uses brass coloring (warmer, contrasts with the steel kettle).

@export var pipe_length: float = 80.0
@export var pipe_radius: float = 14.0
@export var spout_length: float = 70.0
@export var handle_length: float = 36.0

var open: bool = false

func _draw() -> void:
	# Vertical down-spout (brass body)
	var spout_top: float = -spout_length
	var spout_rect := Rect2(-pipe_radius, spout_top, pipe_radius * 2.0, spout_length + 2.0)
	draw_rect(spout_rect, Palette.BRASS_MID)
	# Lit edge on left (toward light)
	draw_rect(
		Rect2(-pipe_radius, spout_top, pipe_radius * 0.32, spout_length + 2.0),
		Palette.BRASS_LIGHT,
	)
	# Specular streak on left edge
	draw_rect(
		Rect2(-pipe_radius + 2, spout_top + 6, 2, spout_length - 8),
		Palette.BRASS_SHINE,
	)
	# Shadow on right
	draw_rect(
		Rect2(pipe_radius * 0.5, spout_top, pipe_radius * 0.5, spout_length + 2.0),
		Palette.BRASS_DARK,
	)
	draw_rect(spout_rect, Palette.METAL_OUTLINE, false, 1.5)

	# Spout cap (a wider lip at the bottom where water exits)
	var cap := Rect2(-pipe_radius - 4.0, -10.0, (pipe_radius + 4.0) * 2.0, 12.0)
	draw_rect(cap, Palette.BRASS_MID)
	# Cap lit top
	draw_rect(
		Rect2(-pipe_radius - 4.0, -10.0, (pipe_radius + 4.0) * 2.0, 3.0),
		Palette.BRASS_LIGHT,
	)
	draw_rect(cap, Palette.METAL_OUTLINE, false, 1.5)

	# Horizontal arm to the right joining the spout near its top
	var arm_height: float = 22.0
	var arm_y: float = spout_top - arm_height + 8.0
	var arm_w: float = pipe_length
	var arm_rect := Rect2(-pipe_radius * 0.4, arm_y, arm_w, arm_height)
	draw_rect(arm_rect, Palette.BRASS_MID)
	# Arm lit top
	draw_rect(
		Rect2(-pipe_radius * 0.4, arm_y, arm_w, 3.0),
		Palette.BRASS_LIGHT,
	)
	# Arm shadow bottom
	draw_rect(
		Rect2(-pipe_radius * 0.4, arm_y + arm_height - 3.0, arm_w, 3.0),
		Palette.BRASS_DARK,
	)
	draw_rect(arm_rect, Palette.METAL_OUTLINE, false, 1.5)

	# Wall flange where arm meets the wall
	var flange := Rect2(arm_w - 10.0, arm_y - 8.0, 18.0, arm_height + 16.0)
	draw_rect(flange, Palette.BRASS_DARK)
	draw_rect(
		Rect2(flange.position.x, flange.position.y, 18.0, 3.0),
		Palette.BRASS_MID,
	)
	draw_rect(flange, Palette.METAL_OUTLINE, false, 1.5)

	# Bolts on the flange
	for dy in [4.0, 24.0]:
		var bolt_pos := Vector2(arm_w + 9.0, arm_y - 8.0 + dy)
		draw_circle(bolt_pos, 2.0, Palette.METAL_OUTLINE)
		draw_circle(bolt_pos + Vector2(-0.5, -0.5), 0.9, Palette.BRASS_LIGHT)

	# Handle
	var handle_anchor := Vector2(arm_w * 0.45, arm_y + 2.0)
	var tilt: float = -0.55 if open else 0.0
	var handle_color: Color = Palette.GRADE_A if open else Palette.GRADE_F
	draw_rect(Rect2(handle_anchor.x - 5.0, handle_anchor.y - 6.0, 10.0, 8.0), Palette.BRASS_DARK)
	var bar_origin := handle_anchor + Vector2(0, -6)
	var bar_dir := Vector2(cos(-PI / 2.0 + tilt), sin(-PI / 2.0 + tilt))
	var bar_perp := Vector2(-bar_dir.y, bar_dir.x)
	var bar_far := bar_origin + bar_dir * handle_length
	var bar_w: float = 7.0
	var bar_pts := PackedVector2Array([
		bar_origin + bar_perp * bar_w,
		bar_far + bar_perp * bar_w,
		bar_far - bar_perp * bar_w,
		bar_origin - bar_perp * bar_w,
	])
	draw_colored_polygon(bar_pts, handle_color)
	# Lit edge on the side facing the light
	var lit_edge := PackedVector2Array([
		bar_origin + bar_perp * bar_w,
		bar_far + bar_perp * bar_w,
	])
	draw_polyline(lit_edge, handle_color.lightened(0.45), 1.5, true)
	# Outline
	draw_polyline(PackedVector2Array([
		bar_origin + bar_perp * bar_w,
		bar_far + bar_perp * bar_w,
		bar_far - bar_perp * bar_w,
		bar_origin - bar_perp * bar_w,
		bar_origin + bar_perp * bar_w,
	]), Palette.METAL_OUTLINE, 1.5, true)

	# Knob at the far end
	draw_circle(bar_far, 8.0, handle_color)
	draw_circle(bar_far + Vector2(-1.5, -1.5), 3.0, handle_color.lightened(0.45))
	draw_arc(bar_far, 8.0, 0, TAU, 18, Palette.METAL_OUTLINE, 1.5, true)
