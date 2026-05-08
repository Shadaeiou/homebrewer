extends Control
class_name ProceduralPaddleIcon

## Wooden mash paddle. Vertical handle with a hole at the top, wide flat blade
## at the bottom. Wood grain lines + a soft drop shadow.

@export var icon_size: float = 96.0

func _ready() -> void:
	custom_minimum_size = Vector2(icon_size, icon_size)

func _draw() -> void:
	var sf: float = size.x / 96.0
	var cx: float = size.x * 0.5
	var top_y: float = size.y * 0.10
	var bottom_y: float = size.y * 0.92

	# Drop shadow (offset down-right per global lighting)
	var shadow_offset: Vector2 = Lighting.shadow_offset(3.0)

	# Geometry
	var handle_top: float = top_y
	var handle_top_w: float = 12.0 * sf
	var handle_bottom: float = bottom_y - 38.0 * sf
	var handle_bottom_w: float = 14.0 * sf

	var blade_top: float = handle_bottom
	var blade_top_w: float = 22.0 * sf
	var blade_bottom: float = bottom_y
	var blade_bottom_w: float = 38.0 * sf

	# Build silhouette: handle (slight taper) + blade trapezoid below
	var silhouette := PackedVector2Array([
		Vector2(cx - handle_top_w * 0.5, handle_top),
		Vector2(cx + handle_top_w * 0.5, handle_top),
		Vector2(cx + handle_bottom_w * 0.5, handle_bottom),
		Vector2(cx + blade_top_w * 0.5, blade_top),
		Vector2(cx + blade_bottom_w * 0.5, blade_bottom),
		Vector2(cx - blade_bottom_w * 0.5, blade_bottom),
		Vector2(cx - blade_top_w * 0.5, blade_top),
		Vector2(cx - handle_bottom_w * 0.5, handle_bottom),
	])

	# Drop shadow (translated silhouette, dark)
	var shadow_pts := PackedVector2Array()
	for p in silhouette:
		shadow_pts.append(p + shadow_offset)
	draw_colored_polygon(shadow_pts, Color(0, 0, 0, 0.40))

	# Body fill (mid wood)
	draw_colored_polygon(silhouette, Palette.WOOD_MID)

	# Lit side (left half) — lighter strip running down
	var lit_pts := PackedVector2Array([
		Vector2(cx - handle_top_w * 0.5 + 1, handle_top),
		Vector2(cx - 1, handle_top),
		Vector2(cx - 1, blade_bottom),
		Vector2(cx - blade_bottom_w * 0.5 + 2, blade_bottom),
		Vector2(cx - blade_top_w * 0.5 + 2, blade_top),
		Vector2(cx - handle_bottom_w * 0.5 + 1, handle_bottom),
	])
	var lit_col: Color = Palette.WOOD_LIGHT
	lit_col.a = 0.55
	draw_colored_polygon(lit_pts, lit_col)

	# Specular streak on the upper-left of the blade
	var spec := PackedVector2Array([
		Vector2(cx - blade_top_w * 0.5 + 4, blade_top + 2),
		Vector2(cx - blade_top_w * 0.5 + 7, blade_top + 2),
		Vector2(cx - blade_bottom_w * 0.5 + 8, blade_bottom - 4),
		Vector2(cx - blade_bottom_w * 0.5 + 5, blade_bottom - 4),
	])
	var spec_col: Color = Palette.WOOD_LIGHT.lightened(0.35)
	spec_col.a = 0.55
	draw_colored_polygon(spec, spec_col)

	# Outline
	var outline_loop := PackedVector2Array(silhouette)
	outline_loop.append(silhouette[0])
	draw_polyline(outline_loop, Palette.WOOD_DARK, 1.5, true)

	# Wood grain lines on the blade (subtle, curved)
	var grain := Palette.WOOD_GRAIN
	grain.a = 0.55
	for i in range(3):
		var t: float = (float(i) + 1.0) * 0.25
		var grain_x_top: float = lerpf(cx - blade_top_w * 0.5 + 3, cx + blade_top_w * 0.5 - 3, t)
		var grain_x_bot: float = lerpf(cx - blade_bottom_w * 0.5 + 4, cx + blade_bottom_w * 0.5 - 4, t)
		draw_line(
			Vector2(grain_x_top, blade_top + 2),
			Vector2(grain_x_bot, blade_bottom - 3),
			grain,
			1.0 * sf,
			true,
		)

	# Hanging hole at top of handle
	var hole_pos := Vector2(cx, handle_top + 6 * sf)
	draw_circle(hole_pos, 2.0 * sf, Palette.BG_DEEP)
	draw_arc(hole_pos, 2.0 * sf, 0, TAU, 12, Palette.WOOD_DARK, 1.0, true)
