extends Node2D
class_name FillKettleVessel

## Procedural side-view brew kettle.
##
## All colors come from the Palette autoload; highlights and shadows respect
## the Lighting autoload's global light direction (upper-left).
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

var rim_top_y: float
var rim_inner_y: float
var inner_bottom_y: float

func _ready() -> void:
	_recompute_geometry()
	queue_redraw()

func _recompute_geometry() -> void:
	rim_top_y = -body_height
	rim_inner_y = rim_top_y + rim_thickness
	inner_bottom_y = -wall_thickness

func inner_left_x_at(y: float) -> float:
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
	# 1. Drop shadow on the counter (shadow side of the global light).
	_draw_floor_shadow()

	# 2. Body silhouette (mid metal).
	var body_silhouette := PackedVector2Array([
		Vector2(-body_top_half_width, rim_top_y),
		Vector2(body_top_half_width, rim_top_y),
		Vector2(body_bottom_half_width, 0),
		Vector2(-body_bottom_half_width, 0),
	])
	draw_colored_polygon(body_silhouette, Palette.METAL_MID)

	# 3. Lit-side gradient (left half: lighter; right half: darker).
	#    Light comes from the upper-left, so the left side of the curved body
	#    catches the most light, the right side is in shadow.
	_draw_metal_shading()

	# 4. Bottom shadow stripe — pot sits on a counter, the bottom is darker.
	var bottom_shadow := PackedVector2Array([
		Vector2(-body_bottom_half_width, -18),
		Vector2(body_bottom_half_width, -18),
		Vector2(body_bottom_half_width, 0),
		Vector2(-body_bottom_half_width, 0),
	])
	var bs := Palette.METAL_DARK
	bs.a = 0.55
	draw_colored_polygon(bottom_shadow, bs)

	# 5. Rim — thicker band across the top, with a lit edge.
	_draw_rim()

	# 6. Interior cavity (dark). Drawn before water so water layers over it.
	var inner := PackedVector2Array([
		Vector2(inner_left_x_at(rim_inner_y), rim_inner_y),
		Vector2(inner_right_x_at(rim_inner_y), rim_inner_y),
		Vector2(inner_right_x_at(inner_bottom_y), inner_bottom_y),
		Vector2(inner_left_x_at(inner_bottom_y), inner_bottom_y),
	])
	draw_colored_polygon(inner, Palette.BG_DEEP)

	# 7. Lip shadow falling into the pot (the rim casts shadow inside).
	var lip_shadow := PackedVector2Array([
		Vector2(inner_left_x_at(rim_inner_y), rim_inner_y),
		Vector2(inner_right_x_at(rim_inner_y), rim_inner_y),
		Vector2(inner_right_x_at(rim_inner_y + 24), rim_inner_y + 24),
		Vector2(inner_left_x_at(rim_inner_y + 24), rim_inner_y + 24),
	])
	draw_colored_polygon(lip_shadow, Color(0, 0, 0, 0.45))

	# 8. Body outline.
	var outline_pts := PackedVector2Array([
		Vector2(-body_top_half_width, rim_top_y),
		Vector2(body_top_half_width, rim_top_y),
		Vector2(body_bottom_half_width, 0),
		Vector2(-body_bottom_half_width, 0),
		Vector2(-body_top_half_width, rim_top_y),
	])
	draw_polyline(outline_pts, Palette.METAL_OUTLINE, 2.0, true)

	# 9. Handles + rivets.
	_draw_handle(Vector2(-body_top_half_width + 4, rim_top_y + 64), -1)
	_draw_handle(Vector2(body_top_half_width - 4, rim_top_y + 64), 1)
	for x in [-body_top_half_width + 18, body_top_half_width - 18]:
		var rivet_center := Vector2(x, rim_top_y + 26)
		draw_circle(rivet_center, 3.0, Palette.METAL_DARK)
		draw_circle(rivet_center + Vector2(-1, -1), 1.4, Palette.METAL_SHINE)


func _draw_floor_shadow() -> void:
	var shadow_offset: Vector2 = Lighting.shadow_offset(8.0)
	var pts := PackedVector2Array([
		Vector2(-body_bottom_half_width + 8, -2),
		Vector2(body_bottom_half_width + 6, -2),
		Vector2(body_bottom_half_width + 12, 8),
		Vector2(-body_bottom_half_width + 14, 8),
	])
	for i in pts.size():
		pts[i] += shadow_offset
	draw_colored_polygon(pts, Color(0, 0, 0, 0.55))


func _draw_metal_shading() -> void:
	# Three vertical bands across the kettle: lit (left), neutral (center),
	# shadowed (right). Each band fades by alpha so the underlying body color
	# blends through.
	var lit := Palette.METAL_LIGHT
	lit.a = 0.55
	var shine := Palette.METAL_SHINE
	shine.a = 0.65
	var shadow := Palette.METAL_DARK
	shadow.a = 0.50

	# Lit hard-light strip on the upper-left side
	var lit_strip := PackedVector2Array([
		Vector2(-body_top_half_width + 4, rim_top_y + 4),
		Vector2(-body_top_half_width + 38, rim_top_y + 4),
		Vector2(-body_bottom_half_width + 30, -2),
		Vector2(-body_bottom_half_width + 4, -2),
	])
	draw_colored_polygon(lit_strip, lit)

	# Specular streak — thin bright slash on the topmost lit area
	var shine_strip := PackedVector2Array([
		Vector2(-body_top_half_width + 12, rim_top_y + 6),
		Vector2(-body_top_half_width + 22, rim_top_y + 6),
		Vector2(-body_bottom_half_width + 18, rim_top_y + body_height * 0.6),
		Vector2(-body_bottom_half_width + 10, rim_top_y + body_height * 0.6),
	])
	draw_colored_polygon(shine_strip, shine)

	# Shadow on the right (away from light)
	var shadow_strip := PackedVector2Array([
		Vector2(body_top_half_width - 36, rim_top_y + 4),
		Vector2(body_top_half_width - 4, rim_top_y + 4),
		Vector2(body_bottom_half_width - 4, -2),
		Vector2(body_bottom_half_width - 30, -2),
	])
	draw_colored_polygon(shadow_strip, shadow)

	# Even deeper edge shadow flush against the right outline
	var deep_shadow := PackedVector2Array([
		Vector2(body_top_half_width - 14, rim_top_y + 4),
		Vector2(body_top_half_width - 4, rim_top_y + 4),
		Vector2(body_bottom_half_width - 4, -2),
		Vector2(body_bottom_half_width - 12, -2),
	])
	var ds := Palette.METAL_OUTLINE
	ds.a = 0.55
	draw_colored_polygon(deep_shadow, ds)


func _draw_rim() -> void:
	# Outer rim band
	var rim := PackedVector2Array([
		Vector2(-body_top_half_width - 4, rim_top_y - 3),
		Vector2(body_top_half_width + 4, rim_top_y - 3),
		Vector2(body_top_half_width, rim_top_y + rim_thickness),
		Vector2(-body_top_half_width, rim_top_y + rim_thickness),
	])
	draw_colored_polygon(rim, Palette.METAL_LIGHT)

	# Lit top edge of the rim (catches light directly)
	var rim_top_lit := PackedVector2Array([
		Vector2(-body_top_half_width - 4, rim_top_y - 3),
		Vector2(body_top_half_width + 4, rim_top_y - 3),
		Vector2(body_top_half_width + 4, rim_top_y),
		Vector2(-body_top_half_width - 4, rim_top_y),
	])
	draw_colored_polygon(rim_top_lit, Palette.METAL_SHINE)

	# Hard right shadow on rim where it curves away from light
	var rim_right_shadow := PackedVector2Array([
		Vector2(body_top_half_width - 30, rim_top_y - 3),
		Vector2(body_top_half_width + 4, rim_top_y - 3),
		Vector2(body_top_half_width, rim_top_y + rim_thickness),
		Vector2(body_top_half_width - 26, rim_top_y + rim_thickness),
	])
	var rs := Palette.METAL_DARK
	rs.a = 0.45
	draw_colored_polygon(rim_right_shadow, rs)

	# Outline
	draw_polyline(PackedVector2Array([
		Vector2(-body_top_half_width - 4, rim_top_y - 3),
		Vector2(body_top_half_width + 4, rim_top_y - 3),
		Vector2(body_top_half_width, rim_top_y + rim_thickness),
		Vector2(-body_top_half_width, rim_top_y + rim_thickness),
		Vector2(-body_top_half_width - 4, rim_top_y - 3),
	]), Palette.METAL_OUTLINE, 1.5, true)


func _draw_handle(anchor: Vector2, side: int) -> void:
	var center := anchor + Vector2(side * (handle_radius * 0.4), 0)
	var pts := PackedVector2Array()
	var steps := 22
	for i in range(steps + 1):
		var theta: float = lerpf(-PI / 2.0, PI / 2.0, float(i) / float(steps))
		pts.append(center + Vector2(side * cos(theta) * handle_radius, sin(theta) * handle_radius))
	# Outline
	draw_polyline(pts, Palette.METAL_OUTLINE, 6.0, true)
	# Lit / shadow split: handles facing left (side=-1) get full highlight; right get less.
	var handle_color: Color = Palette.METAL_LIGHT if side == -1 else Palette.METAL_MID
	draw_polyline(pts, handle_color, 3.0, true)
	# Specular dot at top of left handle
	if side == -1:
		var top_pt: Vector2 = pts[int(steps * 0.25)]
		draw_circle(top_pt, 1.6, Palette.METAL_SHINE)
