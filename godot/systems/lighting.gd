extends Node

## Global light direction + helpers.
##
## Convention: light comes from the upper-left at 45°. Surface normals that
## face the light get lightened; ones that face away get darkened. Procedural
## drawing code calls `shade()` to apply this consistently so every kettle,
## bottle, and pot has highlights and shadows on the SAME side.
##
## In Godot 2D screen coords, +Y is down. So upper-left direction from a
## surface is (-1, -1) normalized.

const LIGHT_DIR: Vector2 = Vector2(-0.7071, -0.7071)  # normalized (-1,-1)

# Strength of highlight/shadow modulation. Tuned so the effect is visible
# without being cartoonish. Bump these to 0.30 / 0.50 if you want the look
# more dramatic later.
const HIGHLIGHT_AMOUNT: float = 0.18
const SHADOW_AMOUNT: float = 0.32

# Pixel offset for moving features toward/away from the light (e.g., putting
# a highlight band 2px toward the light, a shadow 2px away).
const HIGHLIGHT_OFFSET_PX: float = 2.0

func shade(base: Color, surface_normal: Vector2) -> Color:
	## Returns `base` lit by the global light. `surface_normal` points OUT of
	## the surface, in screen-space. A surface facing the light gets brighter,
	## a surface facing away gets darker.
	var n: Vector2 = surface_normal.normalized() if surface_normal.length() > 0.0 else Vector2.ZERO
	var dot_value: float = n.dot(-LIGHT_DIR)  # negate because LIGHT_DIR points FROM the light
	if dot_value > 0.0:
		return base.lightened(dot_value * HIGHLIGHT_AMOUNT)
	return base.darkened(-dot_value * SHADOW_AMOUNT)

func highlight_offset(magnitude: float = HIGHLIGHT_OFFSET_PX) -> Vector2:
	## Pixel offset toward the light source — use to place a highlight band.
	return -LIGHT_DIR * magnitude

func shadow_offset(magnitude: float = HIGHLIGHT_OFFSET_PX) -> Vector2:
	## Pixel offset away from the light source — use to place a drop shadow.
	return LIGHT_DIR * magnitude

func is_lit_side(normal: Vector2) -> bool:
	return normal.dot(-LIGHT_DIR) > 0.0
