extends Control
class_name KitchenScene

## Apartment kitchen visual base shared by every brewing-day mini-game.
## Procedural — no sprite assets. Counter, wall, faux-tile splashback,
## upper shelf hint. Equipment (kettle, fermenter, etc.) mounts at known
## anchor points so each mini-game stages props consistently across the
## shared room.
##
## Layout (in local coords, 540×620 footprint):
##   y=0..360         wall
##   y=360..380       counter front-edge bevel
##   y=380..620       counter top + apron
## Anchor points:
##   counter_y           = 380  (top of counter, where things sit)
##   stove_anchor        = (340, counter_y)
##   sink_anchor         = (110, counter_y)  — faucet hangs above this
##   shelf_y             = 90   (overhead shelf bottom edge)
##
## Fits naturally inside a 540×960 viewport with 100px header above + 240px
## controls below; that's the standard brewing-stage layout.

const COUNTER_Y: float = 380.0
const STOVE_ANCHOR: Vector2 = Vector2(340, 380)
const SINK_ANCHOR: Vector2  = Vector2(150, 380)
const SHELF_Y: float = 90.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	# Wall (top 60% — warm dark, slightly gradient toward the floor for
	# atmospheric falloff).
	draw_rect(Rect2(0, 0, size.x, COUNTER_Y), Palette.BG_WARM)
	# Subtle bottom-of-wall darken — fakes a soft shadow under the upper shelf.
	draw_rect(
		Rect2(0, COUNTER_Y - 24, size.x, 24),
		Palette.BG_MID,
	)

	# Upper shelf: a thin ledge with two small jars + the wall-bracket cue.
	_draw_shelf()

	# Splashback band — a strip of slightly lighter wall just above the counter,
	# the way real apartment kitchens have tile or paint break.
	draw_rect(
		Rect2(0, COUNTER_Y - 96, size.x, 72),
		Palette.BG_DEEP,
	)
	# Soft horizontal tile lines.
	for x in range(0, int(size.x), 60):
		draw_line(
			Vector2(x, COUNTER_Y - 96),
			Vector2(x, COUNTER_Y - 24),
			Color(Palette.BG_WARM.r, Palette.BG_WARM.g, Palette.BG_WARM.b, 0.55),
			1.0,
		)
	for y in [COUNTER_Y - 60, COUNTER_Y - 36]:
		draw_line(
			Vector2(0, y), Vector2(size.x, y),
			Color(Palette.BG_WARM.r, Palette.BG_WARM.g, Palette.BG_WARM.b, 0.55),
			1.0,
		)

	# Counter front edge — brass-lit upper bevel on the bullnose, dark below.
	var counter_top := Rect2(0, COUNTER_Y, size.x, size.y - COUNTER_Y)
	draw_rect(counter_top, Palette.WOOD_MID)
	# Lit top of counter — toward upper-left.
	draw_rect(
		Rect2(0, COUNTER_Y, size.x, 6),
		Palette.WOOD_LIGHT,
	)
	# Wood grain — a few thin horizontal lines, slightly randomized via
	# deterministic pseudo-random so the grain is stable per render.
	for i in range(8):
		var ty: float = COUNTER_Y + 18 + i * 22 + (i % 3) * 4
		if ty > size.y - 8:
			break
		var alpha: float = 0.22 if i % 2 == 0 else 0.15
		draw_line(
			Vector2(8, ty),
			Vector2(size.x - 8, ty + (i % 2) * 2),
			Color(Palette.WOOD_GRAIN.r, Palette.WOOD_GRAIN.g, Palette.WOOD_GRAIN.b, alpha),
			1.5,
		)
	# Apron under the counter — darker, suggests the cabinet face below.
	draw_rect(
		Rect2(0, size.y - 60, size.x, 60),
		Palette.WOOD_DARK,
	)
	draw_line(
		Vector2(0, size.y - 60),
		Vector2(size.x, size.y - 60),
		Palette.METAL_OUTLINE,
		1.0,
	)

	# Sink: a dark recess in the counter where the faucet sits.
	_draw_sink()

	# Stove cue: 4 burner circles + a faint front-edge dial line.
	_draw_stove_hint()

func _draw_shelf() -> void:
	# Right-side shelf only — leaves the left half of the wall clear for the
	# faucet + sink area. Hangs above the stove for spice-rack character.
	var plank_x: float = 290
	var plank_w: float = size.x - plank_x - 30
	var plank := Rect2(plank_x, SHELF_Y, plank_w, 16)
	draw_rect(plank, Palette.WOOD_MID)
	draw_rect(Rect2(plank.position, Vector2(plank.size.x, 3)), Palette.WOOD_LIGHT)
	draw_rect(
		Rect2(plank.position + Vector2(0, plank.size.y), Vector2(plank.size.x, 3)),
		Color(0, 0, 0, 0.45),
	)
	# Three amber bottles, casually staggered.
	for cx in [plank_x + 26, plank_x + 80, plank_x + 156]:
		_draw_shelf_bottle(Vector2(cx, SHELF_Y))

func _draw_shelf_bottle(top_anchor: Vector2) -> void:
	var w: float = 14.0
	var h: float = 38.0
	var neck_w: float = 6.0
	var neck_h: float = 10.0
	var bottle := PackedVector2Array([
		Vector2(top_anchor.x - neck_w * 0.5, top_anchor.y - neck_h - h),
		Vector2(top_anchor.x + neck_w * 0.5, top_anchor.y - neck_h - h),
		Vector2(top_anchor.x + neck_w * 0.5, top_anchor.y - h),
		Vector2(top_anchor.x + w * 0.5, top_anchor.y - h + 4),
		Vector2(top_anchor.x + w * 0.5, top_anchor.y - 1),
		Vector2(top_anchor.x - w * 0.5, top_anchor.y - 1),
		Vector2(top_anchor.x - w * 0.5, top_anchor.y - h + 4),
		Vector2(top_anchor.x - neck_w * 0.5, top_anchor.y - h),
	])
	draw_colored_polygon(bottle, Palette.BEER_DEEP)
	# Lit-side highlight
	var highlight := PackedVector2Array([
		Vector2(top_anchor.x - w * 0.5 + 2, top_anchor.y - h + 6),
		Vector2(top_anchor.x - w * 0.5 + 4, top_anchor.y - h + 6),
		Vector2(top_anchor.x - w * 0.5 + 4, top_anchor.y - 4),
		Vector2(top_anchor.x - w * 0.5 + 2, top_anchor.y - 4),
	])
	draw_colored_polygon(highlight, Color(Palette.BEER_LIGHT.r, Palette.BEER_LIGHT.g, Palette.BEER_LIGHT.b, 0.65))

func _draw_sink() -> void:
	# Recessed dark rectangle just under SINK_ANCHOR; the faucet renders above it.
	var sink_w: float = 130.0
	var sink_h: float = 18.0
	var sink_rect := Rect2(
		SINK_ANCHOR.x - sink_w * 0.5,
		COUNTER_Y - 2,
		sink_w, sink_h,
	)
	draw_rect(sink_rect, Palette.METAL_DARK)
	# Inner edge highlight — very thin metal rim.
	draw_rect(
		Rect2(sink_rect.position, Vector2(sink_rect.size.x, 1)),
		Palette.METAL_OUTLINE,
	)
	# Rim band along the front of the sink (the bullnose where it meets counter).
	draw_rect(
		Rect2(sink_rect.position + Vector2(0, sink_rect.size.y - 2), Vector2(sink_rect.size.x, 2)),
		Palette.METAL_MID,
	)

func _draw_stove_hint() -> void:
	# Faint stovetop suggestion — 2x2 burner circles at right side of counter.
	# Just enough to read as "kitchen", not a working stove for this scene.
	var x0: float = STOVE_ANCHOR.x - 60
	var y0: float = COUNTER_Y + 18
	for col in range(2):
		for row in range(2):
			var cx: float = x0 + col * 60
			var cy: float = y0 + row * 32
			# Burner well
			draw_circle(Vector2(cx, cy), 16, Palette.METAL_DARK)
			# Burner ring
			draw_arc(Vector2(cx, cy), 14, 0, TAU, 24, Palette.METAL_MID, 1.5, true)
			# Subtle inner shadow
			draw_circle(Vector2(cx, cy), 10, Color(0, 0, 0, 0.35))
