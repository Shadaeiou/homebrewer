class_name DrawHelpers
extends RefCounted

## Reusable drawing primitives. Every procedural visual goes through these
## so highlight/shadow direction, outline weight, and bevel depth stay
## consistent across the game.
##
## All methods take a `CanvasItem` as the first argument so they can be
## called from any node's `_draw()`:
##
##     DrawHelpers.draw_outlined_polygon(self, points, fill, outline)
##
## Conventions:
##   - Light direction is global (see Lighting autoload). Highlights face
##     upper-left, shadows fall lower-right.
##   - Outline default is 1.5 px in METAL_OUTLINE color.
##   - Bevel default is 2 px deep.

const DEFAULT_OUTLINE_WIDTH := 1.5
const BEVEL_DEPTH := 2.0

# ---------- Outlined polygon -------------------------------------------------

static func draw_outlined_polygon(
	node: CanvasItem,
	points: PackedVector2Array,
	fill: Color,
	outline_color: Color,
	outline_width: float = DEFAULT_OUTLINE_WIDTH,
) -> void:
	if points.size() < 3:
		return
	node.draw_colored_polygon(points, fill)
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	node.draw_polyline(closed, outline_color, outline_width, true)

# ---------- Beveled rect (lit edges + shadow edges) -------------------------

static func draw_beveled_rect(
	node: CanvasItem,
	rect: Rect2,
	base: Color,
	bevel_depth: float = BEVEL_DEPTH,
) -> void:
	## Draw a rectangle with lit edges on the upper-left, shadowed edges on
	## the lower-right. Looks like a slightly raised metal panel.
	var lit: Color = base.lightened(0.30)
	var shadow: Color = base.darkened(0.40)
	# Base fill
	node.draw_rect(rect, base)
	# Top lit edge
	node.draw_rect(
		Rect2(rect.position, Vector2(rect.size.x, bevel_depth)),
		lit,
	)
	# Left lit edge
	node.draw_rect(
		Rect2(rect.position, Vector2(bevel_depth, rect.size.y)),
		lit,
	)
	# Bottom shadow edge
	node.draw_rect(
		Rect2(
			Vector2(rect.position.x, rect.position.y + rect.size.y - bevel_depth),
			Vector2(rect.size.x, bevel_depth),
		),
		shadow,
	)
	# Right shadow edge
	node.draw_rect(
		Rect2(
			Vector2(rect.position.x + rect.size.x - bevel_depth, rect.position.y),
			Vector2(bevel_depth, rect.size.y),
		),
		shadow,
	)

# ---------- Soft glow (for hot surfaces, embers, highlights) ----------------

static func draw_glow(
	node: CanvasItem,
	center: Vector2,
	radius: float,
	color: Color,
	steps: int = 6,
) -> void:
	## Cheap radial glow. Stacks `steps` decreasing-alpha circles for a
	## soft falloff. Use sparingly — every glow costs N draw calls.
	for i in range(steps):
		var t: float = float(i) / float(steps - 1)
		var r: float = radius * (1.0 - t * 0.5)
		var alpha: float = (1.0 - t) * color.a / float(steps)
		node.draw_circle(center, r, Color(color.r, color.g, color.b, alpha))

# ---------- Lit edge highlight (for procedural panels/curves) ---------------

static func draw_lit_polyline(
	node: CanvasItem,
	points: PackedVector2Array,
	highlight: Color,
	width: float = 1.0,
) -> void:
	## Draws a single-pixel-thin highlight polyline offset toward the light.
	## Use to put a "rim light" along a curved metal edge.
	if points.size() < 2:
		return
	var offset: Vector2 = Lighting.highlight_offset(1.0)
	var shifted := PackedVector2Array()
	for p in points:
		shifted.append(p + offset)
	node.draw_polyline(shifted, highlight, width, true)

# ---------- Drop-shadow polygon (for floating UI / chunky icons) ------------

static func draw_drop_shadow(
	node: CanvasItem,
	points: PackedVector2Array,
	shadow_color: Color = Color(0, 0, 0, 0.45),
	offset_px: float = 4.0,
) -> void:
	## Draws a soft shadow underneath a polygon shape, offset down-right by
	## the global light direction.
	if points.size() < 3:
		return
	var offset: Vector2 = Lighting.shadow_offset(offset_px)
	var shifted := PackedVector2Array()
	for p in points:
		shifted.append(p + offset)
	node.draw_colored_polygon(shifted, shadow_color)

# ---------- Pixel snap (for crisp procedural art) ----------------------------

static func snap(p: Vector2, grid: float = 1.0) -> Vector2:
	if grid <= 0.0:
		return p
	return Vector2(roundf(p.x / grid) * grid, roundf(p.y / grid) * grid)
