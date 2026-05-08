extends Node2D
class_name FillKettleVessel

## Procedural side-view brew kettle.
##
## Draws a hammered-metal pot with a wide body, two D-handles, a heavy rim,
## and a slight inward taper. The interior is exposed at the top so a
## WaterBody node can render the rising water inside the same outline.
##
## Public geometry (used by sibling nodes):
##   - rim_top_y                    Y of the inner rim
##   - inner_left_x_at(y)           inner wall x at a given y (interior tapers)
##   - inner_right_x_at(y)          mirror
##   - inner_bottom_y               Y of the inner bottom

@export var body_height: float = 240.0
@export var body_top_half_width: float = 140.0
@export var body_bottom_half_width: float = 122.0
@export var rim_thickness: float = 10.0
@export var wall_thickness: float = 8.0
@export var handle_radius: float = 22.0
@export var rivet_radius: float = 3.0

const COLOR_BODY_LIGHT := Color(0.78, 0.80, 0.82)
const COLOR_BODY_MID := Color(0.55, 0.57, 0.60)
const COLOR_BODY_DARK := Color(0.32, 0.33, 0.36)
const COLOR_RIM := Color(0.68, 0.70, 0.72)
const COLOR_INTERIOR := Color(0.18, 0.18, 0.20)
const COLOR_OUTLINE := Color(0.10, 0.10, 0.12)
const COLOR_RIVET := Color(0.22, 0.22, 0.24)

var rim_top_y: float
var rim_inner_y: float
var inner_bottom_y: float

func _ready() -> void:
	_recompute_geometry()
	queue_redraw()

func _recompute_geometry() -> void:
	rim_top_y = -body_height
	rim_inner_y = rim_top_y + rim_thickness
	inner_bottom_y = -wall_thickness  # interior bottom sits a wall thickness above origin

func inner_left_x_at(y: float) -> float:
	# Linear taper from -body_top_half_width + wall_thickness at rim_inner_y
	# to -body_bottom_half_width + wall_thickness at inner_bottom_y.
	var top_x: float = -body_top_half_width + wall_thickness
	var bottom_x: float = -body_bottom_half_width + wall_thickness
	var t: float = clampf(_interp_t(y, rim_inner_y, inner_bottom_y), 0.0, 1.0)
	return lerpf(top_x, bottom_x, t)

func inner_right_x_at(y: float) -> float:
	return -inner_left_x_at(y)

func _interp_t(y: float, a: float, b: float) -> float:
	if is_equal_approx(a, b):
		return 0.0
	return (y - a) / (b - a)

func _draw() -> void:
	# Body silhouette as a polygon: top edge, right wall, bottom curve, left wall.
	var body := PackedVector2Array([
		Vector2(-body_top_half_width, rim_top_y),
		Vector2(body_top_half_width, rim_top_y),
		Vector2(body_bottom_half_width, 0),
		Vector2(-body_bottom_half_width, 0),
	])
	draw_colored_polygon(body, COLOR_BODY_MID)

	# Vertical light/dark bands for hammered metal feel
	var bands := 9
	for i in range(bands):
		var t: float = float(i) / float(bands - 1)
		var x_top_a: float = lerpf(-body_top_half_width, body_top_half_width, t)
		var x_top_b: float = lerpf(-body_top_half_width, body_top_half_width, t + 0.05)
		var x_bot_a: float = lerpf(-body_bottom_half_width, body_bottom_half_width, t)
		var x_bot_b: float = lerpf(-body_bottom_half_width, body_bottom_half_width, t + 0.05)
		var shade: Color = COLOR_BODY_LIGHT if (i % 2 == 0) else COLOR_BODY_DARK
		var band := PackedVector2Array([
			Vector2(x_top_a, rim_top_y + 4),
			Vector2(x_top_b, rim_top_y + 4),
			Vector2(x_bot_b, -2),
			Vector2(x_bot_a, -2),
		])
		var c: Color = shade
		c.a = 0.55 if (i % 2 == 0) else 0.7
		draw_colored_polygon(band, c)

	# Bottom shadow stripe
	var shadow := PackedVector2Array([
		Vector2(-body_bottom_half_width, -16),
		Vector2(body_bottom_half_width, -16),
		Vector2(body_bottom_half_width, 0),
		Vector2(-body_bottom_half_width, 0),
	])
	var s := COLOR_BODY_DARK
	s.a = 0.45
	draw_colored_polygon(shadow, s)

	# Rim band across the top with subtle highlight
	var rim_outer := PackedVector2Array([
		Vector2(-body_top_half_width - 2, rim_top_y - 2),
		Vector2(body_top_half_width + 2, rim_top_y - 2),
		Vector2(body_top_half_width, rim_top_y + rim_thickness),
		Vector2(-body_top_half_width, rim_top_y + rim_thickness),
	])
	draw_colored_polygon(rim_outer, COLOR_RIM)
	var rim_highlight := PackedVector2Array([
		Vector2(-body_top_half_width - 2, rim_top_y - 2),
		Vector2(body_top_half_width + 2, rim_top_y - 2),
		Vector2(body_top_half_width + 2, rim_top_y),
		Vector2(-body_top_half_width - 2, rim_top_y),
	])
	draw_colored_polygon(rim_highlight, COLOR_BODY_LIGHT)

	# Interior cavity (visible through the rim opening). Painted before water
	# so water draws over it. We draw to inner_bottom_y so we actually see a floor.
	var inner := PackedVector2Array([
		Vector2(inner_left_x_at(rim_inner_y), rim_inner_y),
		Vector2(inner_right_x_at(rim_inner_y), rim_inner_y),
		Vector2(inner_right_x_at(inner_bottom_y), inner_bottom_y),
		Vector2(inner_left_x_at(inner_bottom_y), inner_bottom_y),
	])
	draw_colored_polygon(inner, COLOR_INTERIOR)

	# Inner shadow at top-front (lip casts shadow down into the pot)
	var lip_shadow := PackedVector2Array([
		Vector2(inner_left_x_at(rim_inner_y), rim_inner_y),
		Vector2(inner_right_x_at(rim_inner_y), rim_inner_y),
		Vector2(inner_right_x_at(rim_inner_y + 22), rim_inner_y + 22),
		Vector2(inner_left_x_at(rim_inner_y + 22), rim_inner_y + 22),
	])
	var ls := Color(0, 0, 0, 0.45)
	draw_colored_polygon(lip_shadow, ls)

	# Outline strokes
	draw_polyline(PackedVector2Array([
		Vector2(-body_top_half_width, rim_top_y),
		Vector2(body_top_half_width, rim_top_y),
		Vector2(body_bottom_half_width, 0),
		Vector2(-body_bottom_half_width, 0),
		Vector2(-body_top_half_width, rim_top_y),
	]), COLOR_OUTLINE, 2.0)

	# Two D-handles
	_draw_handle(Vector2(-body_top_half_width + 4, rim_top_y + 64), -1)
	_draw_handle(Vector2(body_top_half_width - 4, rim_top_y + 64), 1)

	# Rivets
	for x in [-body_top_half_width + 18, body_top_half_width - 18]:
		draw_circle(Vector2(x, rim_top_y + 24), rivet_radius, COLOR_RIVET)
		draw_circle(Vector2(x, rim_top_y + 24 - 1), rivet_radius - 1, COLOR_BODY_LIGHT.lerp(COLOR_RIVET, 0.5))

func _draw_handle(anchor: Vector2, side: int) -> void:
	# D-handle: a half-arc sticking out from the kettle wall
	var center := anchor + Vector2(side * (handle_radius * 0.4), 0)
	var pts := PackedVector2Array()
	var steps := 18
	for i in range(steps + 1):
		var theta: float = lerpf(-PI / 2.0, PI / 2.0, float(i) / float(steps))
		pts.append(center + Vector2(side * cos(theta) * handle_radius, sin(theta) * handle_radius))
	draw_polyline(pts, COLOR_OUTLINE, 6.0)
	draw_polyline(pts, COLOR_BODY_LIGHT, 3.0)
