extends Control
class_name ProceduralStoveIcon

## Tiny side-view gas stove. Steel cooktop with a single burner, two red
## control knobs on the front, lit on the upper-left.

@export var icon_size: float = 96.0

func _ready() -> void:
	custom_minimum_size = Vector2(icon_size, icon_size)

func _draw() -> void:
	var sf: float = size.x / 96.0
	var cx: float = size.x * 0.5
	var ground_y: float = size.y * 0.92

	var body_w: float = 80.0 * sf
	var body_h: float = 64.0 * sf
	var body_x: float = cx - body_w * 0.5
	var body_y: float = ground_y - body_h
	var body_rect := Rect2(body_x, body_y, body_w, body_h)

	# Counter shadow
	var shadow_pts := PackedVector2Array([
		Vector2(body_x + 4 * sf, ground_y - 1),
		Vector2(body_x + body_w + 8 * sf, ground_y - 1),
		Vector2(body_x + body_w + 14 * sf, ground_y + 6 * sf),
		Vector2(body_x + 10 * sf, ground_y + 6 * sf),
	])
	draw_colored_polygon(shadow_pts, Color(0, 0, 0, 0.45))

	# Body
	draw_rect(body_rect, Palette.METAL_MID)

	# Cooktop top edge (lit, brighter)
	draw_rect(Rect2(body_x, body_y, body_w, 5 * sf), Palette.METAL_LIGHT)
	# Specular line on lit edge
	draw_rect(Rect2(body_x + 2, body_y + 1, body_w * 0.45, 1.5 * sf), Palette.METAL_SHINE)

	# Vertical lit strip on the upper-left side
	var lit_strip := Rect2(body_x + 2 * sf, body_y + 6 * sf, 6 * sf, body_h - 14 * sf)
	var lit_col: Color = Palette.METAL_LIGHT
	lit_col.a = 0.55
	draw_rect(lit_strip, lit_col)

	# Right shadow strip
	var shadow_col: Color = Palette.METAL_DARK
	shadow_col.a = 0.55
	draw_rect(
		Rect2(body_x + body_w - 8 * sf, body_y + 6 * sf, 6 * sf, body_h - 14 * sf),
		shadow_col,
	)

	# Bottom shadow strip (legs / kickplate)
	draw_rect(
		Rect2(body_x, ground_y - 6 * sf, body_w, 6 * sf),
		Palette.METAL_DARK,
	)

	# Outline
	draw_rect(body_rect, Palette.METAL_OUTLINE, false, 1.5)

	# Burner ring on top
	var burner_center := Vector2(cx, body_y + 16 * sf)
	draw_circle(burner_center, 13 * sf, Palette.METAL_DARK)
	draw_arc(burner_center, 13 * sf, 0, TAU, 24, Palette.METAL_OUTLINE, 1.2, true)
	# Inner crown
	draw_circle(burner_center, 6 * sf, Palette.BG_DEEP)
	draw_arc(burner_center, 6 * sf, 0, TAU, 18, Palette.METAL_OUTLINE, 1.0, true)
	# Tiny flame port marks (8 around the ring)
	for i in range(8):
		var theta: float = float(i) * TAU / 8.0
		var p := burner_center + Vector2(cos(theta), sin(theta)) * 9.0 * sf
		draw_circle(p, 0.9 * sf, Palette.METAL_OUTLINE)

	# Knobs on the front face (red)
	var knob_y: float = body_y + body_h - 18 * sf
	for kx in [body_x + 18.0 * sf, body_x + body_w - 18.0 * sf]:
		var center := Vector2(kx, knob_y)
		draw_circle(center, 5.5 * sf, Palette.GRADE_F.darkened(0.15))
		draw_circle(center, 4.5 * sf, Palette.GRADE_F)
		# Highlight (lit-side)
		draw_circle(center + Vector2(-1.5, -1.5) * sf, 1.6 * sf, Palette.GRADE_F.lightened(0.45))
		# Pointer notch
		draw_line(center, center + Vector2(0, -4) * sf, Palette.METAL_OUTLINE, 1.2, true)
		# Outline
		draw_arc(center, 5.5 * sf, 0, TAU, 18, Palette.METAL_OUTLINE, 1.0, true)
