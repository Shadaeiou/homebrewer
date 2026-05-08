extends Control
class_name ProceduralKettleIcon

## Tiny side-view brew kettle drawn from primitives.
##
## Used as a tile in inventory grids. Same Palette + Lighting as the in-game
## kettle so the home screen and the mini-game look like they share a world.

@export var icon_size: float = 96.0

func _ready() -> void:
	custom_minimum_size = Vector2(icon_size, icon_size)

func _draw() -> void:
	var scale_factor: float = size.x / 96.0
	var cx: float = size.x * 0.5
	var ground_y: float = size.y * 0.86
	var top_half_w: float = 38.0 * scale_factor
	var bottom_half_w: float = 32.0 * scale_factor
	var height: float = 56.0 * scale_factor
	var rim_top_y: float = ground_y - height
	var rim_thickness: float = 4.0 * scale_factor

	# Shadow on counter
	var shadow_pts := PackedVector2Array([
		Vector2(cx - bottom_half_w + 4 * scale_factor, ground_y - 1),
		Vector2(cx + bottom_half_w + 8 * scale_factor, ground_y - 1),
		Vector2(cx + bottom_half_w + 14 * scale_factor, ground_y + 6 * scale_factor),
		Vector2(cx - bottom_half_w + 10 * scale_factor, ground_y + 6 * scale_factor),
	])
	draw_colored_polygon(shadow_pts, Color(0, 0, 0, 0.45))

	# Body silhouette
	var body := PackedVector2Array([
		Vector2(cx - top_half_w, rim_top_y),
		Vector2(cx + top_half_w, rim_top_y),
		Vector2(cx + bottom_half_w, ground_y),
		Vector2(cx - bottom_half_w, ground_y),
	])
	draw_colored_polygon(body, Palette.METAL_MID)

	# Lit-side strip (left)
	var lit := PackedVector2Array([
		Vector2(cx - top_half_w + 2 * scale_factor, rim_top_y + 2 * scale_factor),
		Vector2(cx - top_half_w + 12 * scale_factor, rim_top_y + 2 * scale_factor),
		Vector2(cx - bottom_half_w + 8 * scale_factor, ground_y - 2),
		Vector2(cx - bottom_half_w + 2 * scale_factor, ground_y - 2),
	])
	var lit_col: Color = Palette.METAL_LIGHT
	lit_col.a = 0.65
	draw_colored_polygon(lit, lit_col)

	# Specular streak
	var spec := PackedVector2Array([
		Vector2(cx - top_half_w + 4 * scale_factor, rim_top_y + 3 * scale_factor),
		Vector2(cx - top_half_w + 6 * scale_factor, rim_top_y + 3 * scale_factor),
		Vector2(cx - bottom_half_w + 4 * scale_factor, ground_y - 4),
		Vector2(cx - bottom_half_w + 2 * scale_factor, ground_y - 4),
	])
	var spec_col: Color = Palette.METAL_SHINE
	spec_col.a = 0.75
	draw_colored_polygon(spec, spec_col)

	# Shadow strip (right)
	var shadow_strip := PackedVector2Array([
		Vector2(cx + top_half_w - 12 * scale_factor, rim_top_y + 2 * scale_factor),
		Vector2(cx + top_half_w - 2 * scale_factor, rim_top_y + 2 * scale_factor),
		Vector2(cx + bottom_half_w - 2 * scale_factor, ground_y - 2),
		Vector2(cx + bottom_half_w - 8 * scale_factor, ground_y - 2),
	])
	var shadow_col: Color = Palette.METAL_DARK
	shadow_col.a = 0.55
	draw_colored_polygon(shadow_strip, shadow_col)

	# Rim band
	var rim_pts := PackedVector2Array([
		Vector2(cx - top_half_w - 1 * scale_factor, rim_top_y - 1 * scale_factor),
		Vector2(cx + top_half_w + 1 * scale_factor, rim_top_y - 1 * scale_factor),
		Vector2(cx + top_half_w, rim_top_y + rim_thickness),
		Vector2(cx - top_half_w, rim_top_y + rim_thickness),
	])
	draw_colored_polygon(rim_pts, Palette.METAL_LIGHT)
	# Lit top edge of rim
	var rim_lit := PackedVector2Array([
		Vector2(cx - top_half_w - 1 * scale_factor, rim_top_y - 1 * scale_factor),
		Vector2(cx + top_half_w + 1 * scale_factor, rim_top_y - 1 * scale_factor),
		Vector2(cx + top_half_w + 1 * scale_factor, rim_top_y),
		Vector2(cx - top_half_w - 1 * scale_factor, rim_top_y),
	])
	draw_colored_polygon(rim_lit, Palette.METAL_SHINE)

	# Outline
	draw_polyline(PackedVector2Array([
		Vector2(cx - top_half_w, rim_top_y),
		Vector2(cx + top_half_w, rim_top_y),
		Vector2(cx + bottom_half_w, ground_y),
		Vector2(cx - bottom_half_w, ground_y),
		Vector2(cx - top_half_w, rim_top_y),
	]), Palette.METAL_OUTLINE, 1.5, true)

	# Interior darkness
	var inner_top_y: float = rim_top_y + rim_thickness
	var inner := PackedVector2Array([
		Vector2(cx - top_half_w + 4 * scale_factor, inner_top_y),
		Vector2(cx + top_half_w - 4 * scale_factor, inner_top_y),
		Vector2(cx + top_half_w - 6 * scale_factor, inner_top_y + 4 * scale_factor),
		Vector2(cx - top_half_w + 6 * scale_factor, inner_top_y + 4 * scale_factor),
	])
	draw_colored_polygon(inner, Palette.BG_DEEP)

	# Tiny D-handles
	for side in [-1, 1]:
		var anchor_x: float = cx + side * (top_half_w - 2 * scale_factor)
		var anchor_y: float = rim_top_y + 18 * scale_factor
		var handle_r: float = 7.0 * scale_factor
		var pts := PackedVector2Array()
		var steps := 14
		for i in range(steps + 1):
			var theta: float = lerpf(-PI / 2.0, PI / 2.0, float(i) / float(steps))
			pts.append(Vector2(
				anchor_x + side * cos(theta) * handle_r,
				anchor_y + sin(theta) * handle_r,
			))
		draw_polyline(pts, Palette.METAL_OUTLINE, 3.0 * scale_factor, true)
		var handle_color: Color = Palette.METAL_LIGHT if side == -1 else Palette.METAL_MID
		draw_polyline(pts, handle_color, 1.5 * scale_factor, true)
