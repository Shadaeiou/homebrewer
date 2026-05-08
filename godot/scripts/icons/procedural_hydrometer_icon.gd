extends Control
class_name ProceduralHydrometerIcon

## Glass hydrometer: thin tube with weighted bulb at the bottom, scale tick
## marks along the tube, slight glass highlight, amber liquid in the bulb.

@export var icon_size: float = 96.0

func _ready() -> void:
	custom_minimum_size = Vector2(icon_size, icon_size)

func _draw() -> void:
	var sf: float = size.x / 96.0
	var cx: float = size.x * 0.5
	var top_y: float = size.y * 0.10
	var bottom_y: float = size.y * 0.94

	var tube_top: float = top_y
	var tube_w: float = 11.0 * sf
	var bulb_radius: float = 18.0 * sf
	var bulb_center_y: float = bottom_y - bulb_radius - 2.0 * sf
	var tube_bottom: float = bulb_center_y - bulb_radius * 0.4

	# Drop shadow on counter
	var shadow_offset: Vector2 = Lighting.shadow_offset(3.0)
	draw_circle(
		Vector2(cx, bulb_center_y) + shadow_offset,
		bulb_radius + 1 * sf,
		Color(0, 0, 0, 0.40),
	)

	# Tube body (slight glass tint)
	var tube_rect := Rect2(cx - tube_w * 0.5, tube_top, tube_w, tube_bottom - tube_top)
	draw_rect(tube_rect, Palette.GLASS_MID)
	# Glass back highlight (left edge, vertical)
	draw_rect(
		Rect2(cx - tube_w * 0.5 + 1, tube_top + 2, 1.5 * sf, tube_bottom - tube_top - 4),
		Palette.GLASS_HIGHLIGHT,
	)
	# Outline
	draw_rect(tube_rect, Palette.METAL_OUTLINE, false, 1.0)

	# Bulb (amber wort sample inside)
	draw_circle(Vector2(cx, bulb_center_y), bulb_radius, Palette.WORT_DEEP)
	# Wort body
	draw_circle(Vector2(cx, bulb_center_y), bulb_radius - 1.5 * sf, Palette.WORT_MID)
	# Top highlight cap (the bulb is liquid-filled)
	var hl_pts := PackedVector2Array()
	var arc_steps := 14
	for i in range(arc_steps + 1):
		var t: float = float(i) / float(arc_steps)
		var theta: float = lerpf(PI + 0.4, TAU - 0.4, t)
		var r: float = bulb_radius - 3 * sf
		hl_pts.append(Vector2(cx, bulb_center_y) + Vector2(cos(theta), sin(theta)) * r)
	# Close into a thin arc
	for i in range(arc_steps + 1):
		var t: float = 1.0 - float(i) / float(arc_steps)
		var theta: float = lerpf(PI + 0.4, TAU - 0.4, t)
		var r: float = bulb_radius - 5 * sf
		hl_pts.append(Vector2(cx, bulb_center_y) + Vector2(cos(theta), sin(theta)) * r)
	draw_colored_polygon(hl_pts, Palette.WORT_LIGHT)

	# Specular dot on bulb (upper-left)
	var spec_pos := Vector2(cx, bulb_center_y) + Vector2(-bulb_radius * 0.45, -bulb_radius * 0.45)
	draw_circle(spec_pos, 2.5 * sf, Palette.WORT_HIGHLIGHT)

	# Bulb outline
	draw_arc(Vector2(cx, bulb_center_y), bulb_radius, 0, TAU, 24, Palette.METAL_OUTLINE, 1.5, true)

	# Tick marks on the tube (scale)
	var tick_color: Color = Palette.METAL_OUTLINE
	for i in range(7):
		var t: float = (float(i) + 1.0) / 8.0
		var ty: float = lerpf(tube_top + 4, tube_bottom - 4, t)
		var long_tick: bool = i % 2 == 0
		var tick_w: float = (5 if long_tick else 3) * sf
		draw_line(
			Vector2(cx + tube_w * 0.5 - 1, ty),
			Vector2(cx + tube_w * 0.5 + tick_w, ty),
			tick_color,
			0.8 * sf,
			true,
		)

	# Cap at the very top of the tube
	var cap_rect := Rect2(cx - tube_w * 0.5 - 2, tube_top - 4 * sf, tube_w + 4, 4 * sf)
	draw_rect(cap_rect, Palette.METAL_LIGHT)
	draw_rect(cap_rect, Palette.METAL_OUTLINE, false, 1.0)
