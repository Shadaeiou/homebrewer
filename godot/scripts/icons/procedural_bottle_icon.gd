extends Control
class_name ProceduralBottleIcon

## A finished beer bottle. Long-neck silhouette in dark amber glass, gold
## crown cap, beige label band, lit on the upper-left.

@export var icon_size: float = 96.0

func _ready() -> void:
	custom_minimum_size = Vector2(icon_size, icon_size)

func _draw() -> void:
	var sf: float = size.x / 96.0
	var cx: float = size.x * 0.5
	var top_y: float = size.y * 0.06
	var bottom_y: float = size.y * 0.94

	# Geometry
	var cap_h: float = 7.0 * sf
	var neck_w: float = 18.0 * sf
	var shoulder_y: float = top_y + 28.0 * sf
	var body_w: float = 44.0 * sf

	# Drop shadow
	var shadow_offset: Vector2 = Lighting.shadow_offset(3.0)
	var shadow_pts := PackedVector2Array([
		Vector2(cx - body_w * 0.5 + 4 * sf, bottom_y - 1) + shadow_offset,
		Vector2(cx + body_w * 0.5 + 4 * sf, bottom_y - 1) + shadow_offset,
		Vector2(cx + body_w * 0.5 + 8 * sf, bottom_y + 4 * sf) + shadow_offset,
		Vector2(cx - body_w * 0.5 + 8 * sf, bottom_y + 4 * sf) + shadow_offset,
	])
	draw_colored_polygon(shadow_pts, Color(0, 0, 0, 0.40))

	# Bottle silhouette (cap, neck, shoulder, body)
	var silhouette := PackedVector2Array([
		# Cap top
		Vector2(cx - neck_w * 0.5 - 1 * sf, top_y),
		Vector2(cx + neck_w * 0.5 + 1 * sf, top_y),
		# Cap to neck
		Vector2(cx + neck_w * 0.5 + 1 * sf, top_y + cap_h),
		Vector2(cx + neck_w * 0.5, top_y + cap_h + 2 * sf),
		# Neck down
		Vector2(cx + neck_w * 0.5, shoulder_y),
		# Shoulder out
		Vector2(cx + body_w * 0.5, shoulder_y + 8 * sf),
		# Body down
		Vector2(cx + body_w * 0.5, bottom_y - 4 * sf),
		# Bottom curve in
		Vector2(cx + body_w * 0.5 - 3 * sf, bottom_y),
		Vector2(cx - body_w * 0.5 + 3 * sf, bottom_y),
		Vector2(cx - body_w * 0.5, bottom_y - 4 * sf),
		# Body up
		Vector2(cx - body_w * 0.5, shoulder_y + 8 * sf),
		# Shoulder in
		Vector2(cx - neck_w * 0.5, shoulder_y),
		# Neck up
		Vector2(cx - neck_w * 0.5, top_y + cap_h + 2 * sf),
		Vector2(cx - neck_w * 0.5 - 1 * sf, top_y + cap_h),
	])

	# Body fill (amber/brown beer glass)
	draw_colored_polygon(silhouette, Palette.BEER_DEEP)

	# Lit-side highlight (upper-left vertical strip on the body)
	var lit_pts := PackedVector2Array([
		Vector2(cx - body_w * 0.5 + 2 * sf, shoulder_y + 9 * sf),
		Vector2(cx - body_w * 0.5 + 6 * sf, shoulder_y + 9 * sf),
		Vector2(cx - body_w * 0.5 + 6 * sf, bottom_y - 5 * sf),
		Vector2(cx - body_w * 0.5 + 2 * sf, bottom_y - 5 * sf),
	])
	var lit_col: Color = Palette.BEER_LIGHT
	lit_col.a = 0.55
	draw_colored_polygon(lit_pts, lit_col)
	# Specular streak (thinner, brighter)
	draw_rect(
		Rect2(
			Vector2(cx - body_w * 0.5 + 4 * sf, shoulder_y + 12 * sf),
			Vector2(1.6 * sf, bottom_y - shoulder_y - 18 * sf),
		),
		Palette.BEER_LIGHT.lightened(0.5),
	)

	# Highlight on neck (lit side)
	draw_rect(
		Rect2(
			Vector2(cx - neck_w * 0.5 + 1 * sf, top_y + cap_h + 4 * sf),
			Vector2(1.5 * sf, shoulder_y - top_y - cap_h - 6 * sf),
		),
		Palette.BEER_LIGHT,
	)

	# Outline
	var outline_loop := PackedVector2Array(silhouette)
	outline_loop.append(silhouette[0])
	draw_polyline(outline_loop, Palette.BG_DEEP, 1.5, true)

	# Crown cap (gold)
	var cap_rect := Rect2(
		cx - neck_w * 0.5 - 1 * sf, top_y, neck_w + 2 * sf, cap_h
	)
	draw_rect(cap_rect, Palette.BRASS_MID)
	# Cap lit edge
	draw_rect(
		Rect2(cap_rect.position, Vector2(cap_rect.size.x, 1.5 * sf)),
		Palette.BRASS_SHINE,
	)
	# Cap shadow edge
	draw_rect(
		Rect2(
			Vector2(cap_rect.position.x, cap_rect.position.y + cap_rect.size.y - 1.5 * sf),
			Vector2(cap_rect.size.x, 1.5 * sf),
		),
		Palette.BRASS_DARK,
	)
	draw_rect(cap_rect, Palette.METAL_OUTLINE, false, 1.0)
	# Crown notches
	for i in range(5):
		var nx: float = cap_rect.position.x + 1 * sf + (cap_rect.size.x - 2 * sf) * (float(i) + 0.5) / 5.0
		draw_line(
			Vector2(nx, cap_rect.position.y + 1 * sf),
			Vector2(nx, cap_rect.position.y + cap_rect.size.y - 1 * sf),
			Palette.BRASS_DARK,
			0.8 * sf,
			true,
		)

	# Label (beige rectangle on the body)
	var label_rect := Rect2(
		cx - body_w * 0.5 + 2 * sf,
		shoulder_y + 14 * sf,
		body_w - 4 * sf,
		(bottom_y - shoulder_y) * 0.45,
	)
	draw_rect(label_rect, Palette.FOAM_MID)
	draw_rect(label_rect, Palette.WOOD_DARK, false, 1.0)
	# Label "logo" — simple gold dot + stripe
	var lcx: float = label_rect.position.x + label_rect.size.x * 0.5
	var lcy: float = label_rect.position.y + label_rect.size.y * 0.5
	draw_circle(Vector2(lcx, lcy - 2 * sf), 2.5 * sf, Palette.BRASS_LIGHT)
	draw_rect(
		Rect2(label_rect.position.x + 4 * sf, lcy + 3 * sf, label_rect.size.x - 8 * sf, 1 * sf),
		Palette.WOOD_DARK,
	)
