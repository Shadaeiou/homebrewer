extends Control
class_name Kettle2D

## Side-view stockpot with optional water level. Procedural; consistent with
## ProceduralKettleIcon's silhouette but scaled up and aware of fill state.
##
## Anchor: top-of-rim sits at (size.x/2, 0). The pot drops down from there,
## so place the parent at the counter line where the kettle sits.

@export var fill_fraction: float = 0.0  ## 0.0 (empty) → 1.0 (rim).
@export var fill_color: Color = Palette.WATER_MID
@export var fill_meniscus: Color = Palette.WATER_MENISCUS
## Optional aim guide. If > 0, draw a horizontal band at this fill_fraction
## with `target_band_width` thickness — wider band = lower equipment precision
## (you can't really tell where 2.5 gal is in an unmarked stockpot).
@export var target_fraction: float = 0.0
@export var target_band_width: float = 36.0
@export var target_color: Color = Color(0.96, 0.78, 0.32, 0.5)

const TOP_HALF_W: float = 110.0
const BOTTOM_HALF_W: float = 92.0
const HEIGHT: float = 220.0
const RIM_THICKNESS: float = 8.0

func _ready() -> void:
	custom_minimum_size = Vector2(TOP_HALF_W * 2 + 24, HEIGHT + 12)

func set_fill(f: float) -> void:
	fill_fraction = clampf(f, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var cx: float = size.x * 0.5
	var rim_y: float = 8.0
	var bottom_y: float = rim_y + HEIGHT

	# Soft drop shadow under the pot.
	var shadow := PackedVector2Array([
		Vector2(cx - BOTTOM_HALF_W + 8, bottom_y - 2),
		Vector2(cx + BOTTOM_HALF_W + 14, bottom_y - 2),
		Vector2(cx + BOTTOM_HALF_W + 22, bottom_y + 10),
		Vector2(cx - BOTTOM_HALF_W + 16, bottom_y + 10),
	])
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.55))

	# Main body (truncated cone, narrower at base).
	var body := PackedVector2Array([
		Vector2(cx - TOP_HALF_W, rim_y),
		Vector2(cx + TOP_HALF_W, rim_y),
		Vector2(cx + BOTTOM_HALF_W, bottom_y),
		Vector2(cx - BOTTOM_HALF_W, bottom_y),
	])
	draw_colored_polygon(body, Palette.METAL_MID)

	# Lit-side strip (left, toward upper-left light).
	var lit_strip := PackedVector2Array([
		Vector2(cx - TOP_HALF_W + 6,  rim_y + 4),
		Vector2(cx - TOP_HALF_W + 28, rim_y + 4),
		Vector2(cx - BOTTOM_HALF_W + 22, bottom_y - 4),
		Vector2(cx - BOTTOM_HALF_W + 6,  bottom_y - 4),
	])
	var lit_col: Color = Palette.METAL_LIGHT
	lit_col.a = 0.65
	draw_colored_polygon(lit_strip, lit_col)

	# Specular line.
	var spec := PackedVector2Array([
		Vector2(cx - TOP_HALF_W + 12, rim_y + 6),
		Vector2(cx - TOP_HALF_W + 16, rim_y + 6),
		Vector2(cx - BOTTOM_HALF_W + 10, bottom_y - 6),
		Vector2(cx - BOTTOM_HALF_W + 6,  bottom_y - 6),
	])
	var spec_col: Color = Palette.METAL_SHINE
	spec_col.a = 0.85
	draw_colored_polygon(spec, spec_col)

	# Shadow strip on the right side.
	var shadow_strip := PackedVector2Array([
		Vector2(cx + TOP_HALF_W - 28, rim_y + 4),
		Vector2(cx + TOP_HALF_W - 6,  rim_y + 4),
		Vector2(cx + BOTTOM_HALF_W - 6,  bottom_y - 4),
		Vector2(cx + BOTTOM_HALF_W - 22, bottom_y - 4),
	])
	var shadow_col: Color = Palette.METAL_DARK
	shadow_col.a = 0.55
	draw_colored_polygon(shadow_strip, shadow_col)

	# Outline.
	var outline := PackedVector2Array([
		Vector2(cx - TOP_HALF_W, rim_y),
		Vector2(cx + TOP_HALF_W, rim_y),
		Vector2(cx + BOTTOM_HALF_W, bottom_y),
		Vector2(cx - BOTTOM_HALF_W, bottom_y),
		Vector2(cx - TOP_HALF_W, rim_y),
	])
	draw_polyline(outline, Palette.METAL_OUTLINE, 2.0, true)

	# Rim band (a stripe across the top, with lit upper edge).
	var rim := PackedVector2Array([
		Vector2(cx - TOP_HALF_W - 3, rim_y - 3),
		Vector2(cx + TOP_HALF_W + 3, rim_y - 3),
		Vector2(cx + TOP_HALF_W,     rim_y + RIM_THICKNESS),
		Vector2(cx - TOP_HALF_W,     rim_y + RIM_THICKNESS),
	])
	draw_colored_polygon(rim, Palette.METAL_LIGHT)
	var rim_lit := PackedVector2Array([
		Vector2(cx - TOP_HALF_W - 3, rim_y - 3),
		Vector2(cx + TOP_HALF_W + 3, rim_y - 3),
		Vector2(cx + TOP_HALF_W + 3, rim_y - 1),
		Vector2(cx - TOP_HALF_W - 3, rim_y - 1),
	])
	draw_colored_polygon(rim_lit, Palette.METAL_SHINE)

	# Interior dark band.
	var inner_top: float = rim_y + RIM_THICKNESS
	var inner_bottom: float = inner_top + 16
	var inner := PackedVector2Array([
		Vector2(cx - TOP_HALF_W + 8, inner_top),
		Vector2(cx + TOP_HALF_W - 8, inner_top),
		Vector2(cx + TOP_HALF_W - 14, inner_bottom),
		Vector2(cx - TOP_HALF_W + 14, inner_bottom),
	])
	draw_colored_polygon(inner, Palette.BG_DEEP)

	# Target aim band — drawn behind the water so it shows through clearly.
	if target_fraction > 0.0:
		_draw_target_band(cx, inner_top, bottom_y - 6)

	# Water — fills the interior up to fill_fraction of inner volume.
	if fill_fraction > 0.0:
		_draw_water(cx, inner_top, bottom_y - 6)

	# Handles (D-shaped).
	for side in [-1.0, 1.0]:
		var anchor_x: float = cx + side * (TOP_HALF_W - 6)
		var anchor_y: float = rim_y + 60
		_draw_handle(Vector2(anchor_x, anchor_y), side)

func _draw_target_band(cx: float, top_y: float, bottom_y: float) -> void:
	var span: float = bottom_y - top_y
	var center_y: float = bottom_y - span * target_fraction
	var band_top: float = center_y - target_band_width * 0.5
	var band_bot: float = center_y + target_band_width * 0.5
	# Band trapezoid follows the kettle's interior taper.
	var t_top: float = (band_top - top_y) / max(span, 0.01)
	var t_bot: float = (band_bot - top_y) / max(span, 0.01)
	var top_w: float = lerpf(TOP_HALF_W - 14, BOTTOM_HALF_W - 8, clampf(t_top, 0.0, 1.0))
	var bot_w: float = lerpf(TOP_HALF_W - 14, BOTTOM_HALF_W - 8, clampf(t_bot, 0.0, 1.0))
	var band := PackedVector2Array([
		Vector2(cx - top_w, band_top),
		Vector2(cx + top_w, band_top),
		Vector2(cx + bot_w, band_bot),
		Vector2(cx - bot_w, band_bot),
	])
	draw_colored_polygon(band, target_color)
	# Center hairline through the band.
	var hairline: Color = target_color
	hairline.a = clampf(target_color.a + 0.3, 0.0, 1.0)
	draw_line(
		Vector2(cx - top_w, center_y),
		Vector2(cx + top_w, center_y),
		hairline, 1.5, true,
	)

func _draw_water(cx: float, top_y: float, bottom_y: float) -> void:
	# Map fill_fraction from 0..1 to the inside-of-pot vertical range.
	var span: float = bottom_y - top_y
	var water_top: float = bottom_y - span * fill_fraction
	# Water polygon is a trapezoid shrinking toward the bottom (matches body taper).
	# Lerp half-widths from rim to base.
	var t: float = (water_top - top_y) / max(span, 0.01)
	var top_inner_w: float = lerpf(TOP_HALF_W - 14, BOTTOM_HALF_W - 8, t)
	var water_top_polygon := PackedVector2Array([
		Vector2(cx - top_inner_w, water_top),
		Vector2(cx + top_inner_w, water_top),
		Vector2(cx + BOTTOM_HALF_W - 8, bottom_y),
		Vector2(cx - BOTTOM_HALF_W + 8, bottom_y),
	])
	draw_colored_polygon(water_top_polygon, fill_color)
	# Meniscus band — thin highlight at the surface.
	var meniscus := PackedVector2Array([
		Vector2(cx - top_inner_w + 4, water_top),
		Vector2(cx + top_inner_w - 4, water_top),
		Vector2(cx + top_inner_w - 4, water_top + 2),
		Vector2(cx - top_inner_w + 4, water_top + 2),
	])
	var m: Color = fill_meniscus
	m.a = 0.85
	draw_colored_polygon(meniscus, m)
	# Subtle highlight on the lit side of the surface.
	draw_circle(Vector2(cx - top_inner_w + 12, water_top + 2), 3, Color(1, 1, 1, 0.45))

func _draw_handle(anchor: Vector2, side: float) -> void:
	var radius: float = 16.0
	var pts := PackedVector2Array()
	var steps := 18
	for i in range(steps + 1):
		var theta: float = lerpf(-PI / 2.0, PI / 2.0, float(i) / float(steps))
		pts.append(Vector2(
			anchor.x + side * cos(theta) * radius,
			anchor.y + sin(theta) * radius,
		))
	draw_polyline(pts, Palette.METAL_OUTLINE, 5.0, true)
	var color: Color = Palette.METAL_LIGHT if side < 0 else Palette.METAL_MID
	draw_polyline(pts, color, 2.5, true)

func target_fraction_y(target_fraction: float) -> float:
	## Returns the local y-coord where a target line at `target_fraction` would
	## sit inside the kettle. Useful for drawing a faint "aim here" guide.
	var rim_y: float = 8.0
	var top_inner: float = rim_y + RIM_THICKNESS + 16
	var bottom_inner: float = rim_y + HEIGHT - 6
	var span: float = bottom_inner - top_inner
	return bottom_inner - span * clampf(target_fraction, 0.0, 1.0)
