extends Control
class_name Apartment2D

## Persistent apartment world. ONE big horizontal panorama drawn
## procedurally; mini-games scroll the camera to their station instead
## of mounting their own scene. The apartment IS the game world — when
## the player upgrades to garage / pro scale later, this scene grows
## new stations rather than getting replaced.
##
## Layout (1200×620 panorama):
##   x=0..240    Closet (door — fermenter goes here between bottling
##                       day and tasting; visible cue when conditioning)
##   x=240..480  Bottling table (small wooden table, where the player
##                               sits down with the capper)
##   x=480..720  Sink station (counter recess + brass faucet)
##   x=720..960  Stove station (4-burner gas range)
##   x=960..1200 Window + small decor (life, no interaction)
##
## Camera control: parent positions/tweens this Control's `position.x`
## to bring a station to viewport center. `clip_contents = true` on
## the parent viewport keeps the off-screen apartment clipped.
##
## Equipment nodes (kettle, fermenter, etc.) are children of this
## node. The apartment exposes station_world_pos(id) so equipment can
## be placed/moved between stations.

## SCALE RULE: 4 pixels = 1 inch (48 px = 1 foot).
## All wall objects, equipment, and decor are sized against this rule
## so a 30" door, a 36" counter, a 12" stockpot, and a 12" wall clock
## are all consistent with each other. If something looks too big or
## too small, FIRST check that it was sized in inches and multiplied
## by PX_PER_INCH — don't eyeball a fix.
const PX_PER_INCH: float = 4.0
const PX_PER_FOOT: float = 48.0

const PANORAMA_W: float = 1620.0
const PANORAMA_H: float = 620.0
const FLOOR_Y: float = 540.0
## Counter top sits 36" above the floor (standard US kitchen counter).
const COUNTER_Y: float = FLOOR_Y - 36.0 * PX_PER_INCH  # = 396
## Where the ceiling line sits (8 ft above floor). Decor above this is
## "out of room" / clipped; the visible kitchen wall is COUNTER_Y..FLOOR_Y
## for the cabinet face and CEILING_Y..COUNTER_Y for above-counter decor.
const CEILING_Y: float = FLOOR_Y - 96.0 * PX_PER_INCH  # = 156

## Station x-centers — the camera focuses on these.
const STATION_CLOSET: int = 0
const STATION_BOTTLING_TABLE: int = 1
const STATION_SINK: int = 2
const STATION_STOVE: int = 3
const STATION_DECOR: int = 4
const STATION_BED: int = 5
const STATION_FRONT_DOOR: int = 6

## Layout: front door (far left, way out), bare wall, bottling table,
## kitchen counter (sink+stove), bedroom wall (window above bed at same
## cx), closet at the far right (storage). Front door and closet are at
## opposite ends of the apartment so they're not next to each other.
##
## Indices:    closet, bottling, sink, stove,  decor,  bed,    front_door
const STATION_X: PackedFloat32Array = [1500.0, 480.0, 720.0, 960.0, 1200.0, 1200.0, 120.0]

## Station counter-top y — where equipment naturally sits.
func station_anchor(station: int) -> Vector2:
	var x: float = STATION_X[clampi(station, 0, STATION_X.size() - 1)]
	# Bottling table sits a hair lower than counter (it's a separate piece
	# of furniture); other stations use COUNTER_Y.
	var y: float = COUNTER_Y
	if station == STATION_BOTTLING_TABLE:
		y = COUNTER_Y + 18
	return Vector2(x, y)

func station_x(station: int) -> float:
	return STATION_X[clampi(station, 0, STATION_X.size() - 1)]

func camera_offset_for(station: int, viewport_width: float) -> Vector2:
	## How far the apartment's `position.x` should be shifted (in the
	## parent viewport) so the given station sits at viewport center.
	## Negative because we shift the panorama leftward to bring the station
	## from off-screen into the visible window.
	var target_x: float = station_x(station)
	return Vector2(viewport_width * 0.5 - target_x, 0)

func tween_camera_to(parent: Tween, target: int, viewport_width: float, duration: float = 0.45) -> void:
	## Convenience: tween this Control's position toward the target station.
	## Caller passes a Tween created on the parent so lifecycle is managed
	## outside the apartment.
	var dest: Vector2 = camera_offset_for(target, viewport_width)
	parent.tween_property(self, "position", dest, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

## Equipment scales:
##   Kettle2D source sprite is 220 raw px tall for a 12" object → 0.218 scale.
##   Faucet2D source sprite is now drawn at display size (4 px = 1 inch
##   already baked in), so its scale is 1.0 — no further adjustment.
const KETTLE_SCALE: float = 12.0 * PX_PER_INCH / 220.0  # ≈ 0.218
const FAUCET_SCALE: float = 1.0
## Effective on-screen kettle height/half-width (for placing it).
const KETTLE_DRAWN_HEIGHT: float = 228.0 * KETTLE_SCALE
const KETTLE_DRAWN_HALF_W: float = 110.0 * KETTLE_SCALE
## Sink basin recess. Real kitchen sink ~22" deep × 8" tall recess.
const SINK_BASIN_W: float = 22.0 * PX_PER_INCH  # 88
const SINK_BASIN_H: float = 8.0 * PX_PER_INCH   # 32
## Where the kettle rests on the counter when idle (right of the basin).
const KETTLE_REST_OFFSET_X: float = SINK_BASIN_W * 0.5 + 18.0  # = 62

var faucet: Faucet2D = null

func _ready() -> void:
	custom_minimum_size = Vector2(PANORAMA_W, PANORAMA_H)
	mouse_filter = Control.MOUSE_FILTER_PASS
	# Auto-instance the faucet at the sink station — it's apartment
	# infrastructure, not movable equipment, so it lives here.
	faucet = Faucet2D.new()
	faucet.name = "SinkFaucet"
	faucet.scale = Vector2(FAUCET_SCALE, FAUCET_SCALE)
	# Faucet base mounts on the counter behind the basin. With FAUCET_SCALE
	# = 1.0, faucet local (MOUNT_X, MOUNT_Y) needs to land at world
	# (sink.x, COUNTER_Y - small_offset). The small offset puts the base
	# slightly behind the basin opening (toward the wall), not on top of it.
	var sink_anchor: Vector2 = station_anchor(STATION_SINK)
	faucet.position = Vector2(
		sink_anchor.x - Faucet2D.MOUNT_X,
		sink_anchor.y - Faucet2D.MOUNT_Y - 4.0,
	)
	add_child(faucet)
	queue_redraw()

func place_kettle_at_station(kettle: Control, station: int, offset: Vector2 = Vector2.ZERO) -> void:
	## Helper: scale + position a kettle so its bottom sits on the named
	## station's anchor (with optional offset for "rest" vs "over basin"
	## placement). Centralizes the scale math so dashboard and fill_kettle
	## don't repeat it.
	kettle.scale = Vector2(KETTLE_SCALE, KETTLE_SCALE)
	var anchor: Vector2 = station_anchor(station) + offset
	kettle.position = Vector2(
		anchor.x - KETTLE_DRAWN_HALF_W,
		anchor.y - KETTLE_DRAWN_HEIGHT,
	)

func _draw() -> void:
	# Wall fills the entire above-floor area. The "ceiling line" just
	# marks where above-ceiling decor stops; the wall texture is uniform.
	draw_rect(Rect2(0, 0, PANORAMA_W, FLOOR_Y), Palette.BG_WARM)
	# Slight darkening near the ceiling so the room feels lit from below.
	draw_rect(Rect2(0, 0, PANORAMA_W, CEILING_Y), Color(0, 0, 0, 0.18))

	# Splashback (tile) behind the working kitchen area: counter run only.
	var counter_left: float = 600.0   # right edge of bottling table
	var counter_right: float = 900.0  # left edge of stove
	var splash_h: float = 18.0 * PX_PER_INCH  # 72 px (18" backsplash)
	draw_rect(
		Rect2(counter_left, COUNTER_Y - splash_h, counter_right - counter_left, splash_h),
		Palette.BG_DEEP,
	)
	# Tile grout pattern.
	var tile_w: float = 6.0 * PX_PER_INCH  # 24 px tiles
	var grout: Color = Color(Palette.BG_WARM.r, Palette.BG_WARM.g, Palette.BG_WARM.b, 0.45)
	for x in range(int(counter_left), int(counter_right), int(tile_w)):
		draw_line(Vector2(x, COUNTER_Y - splash_h), Vector2(x, COUNTER_Y - 4), grout, 1.0)
	draw_line(
		Vector2(counter_left, COUNTER_Y - splash_h * 0.5),
		Vector2(counter_right, COUNTER_Y - splash_h * 0.5),
		grout, 1.0,
	)

	# Wall cabinets above the splashback.
	_draw_wall_cabinets(counter_left, counter_right)

	# Range hood above the stove.
	_draw_range_hood(STATION_X[STATION_STOVE])

	# Wall clock — on the bare wall to the right of the stove/hood,
	# above the wall calendar. Out of the way of the bottling-table
	# shelf (which holds the journal).
	_draw_wall_clock(Vector2(1080.0, COUNTER_Y - 36.0 * PX_PER_INCH))

	# Wall calendar — BELOW the bottling-table shelf, between the shelf
	# and the table top. Centered on the bottling-table x.
	_draw_wall_calendar(Vector2(STATION_X[STATION_BOTTLING_TABLE] - 28.0,
		COUNTER_Y - 32.0 * PX_PER_INCH))

	# Window on the decor wall (sill above counter).
	_draw_window(STATION_X[STATION_DECOR])

	# Front door (far left, way out of the apartment).
	_draw_front_door(STATION_X[STATION_FRONT_DOOR])

	# Closet door (storage, used by the brew flow).
	_draw_closet_door(STATION_X[STATION_CLOSET])

	# Floor band (below the counter level).
	_draw_floor()

	# Counter top + cabinet face.
	_draw_counter_strip(counter_left, counter_right)

	# Bottling table (free-standing furniture left of counter).
	_draw_bottling_table()

	# The brewer's journal sits on the bottling table — a physical
	# notebook the player taps to read entries. Positioned where it
	# wouldn't get knocked off during bottling work.
	_draw_journal_notebook()

	# Stove (right of counter).
	_draw_stove(STATION_X[STATION_STOVE])

	# Sink basin recessed into the counter.
	_draw_sink(STATION_X[STATION_SINK])

	# Bed on the right end of the apartment — tap to rest.
	_draw_bed(STATION_X[STATION_BED])

	# Baseboard runs along the whole wall at floor level.
	_draw_baseboard()

func _draw_counter_strip(x_left: float, x_right: float) -> void:
	# Counter top: 1.5" thick wood = 6 px.
	var top_thickness: float = 1.5 * PX_PER_INCH
	var top := Rect2(x_left, COUNTER_Y, x_right - x_left, top_thickness)
	draw_rect(top, Palette.WOOD_MID)
	draw_rect(Rect2(top.position, Vector2(top.size.x, 1)), Palette.WOOD_LIGHT)
	# Cabinet face below the counter (36" = 144 px tall).
	var cab_top: float = COUNTER_Y + top_thickness
	var cab := Rect2(x_left, cab_top, x_right - x_left, FLOOR_Y - cab_top)
	draw_rect(cab, Palette.WOOD_DARK)
	# Knob row 3" below the counter, near the top of the cabinet door
	# (real base-cabinet knobs sit close to the top edge for hand reach;
	# centered on the door reads as a button-on-a-door, not a knob).
	var knob_y: float = cab_top + 3.0 * PX_PER_INCH

	# Sink-base cabinet — two narrow doors (12" each) directly under the
	# basin, knobs on the inner edges (doors swing outward).
	var sink_cx: float = STATION_X[STATION_SINK]
	var sink_door_w: float = 12.0 * PX_PER_INCH  # 48
	var sink_doors_left: float = sink_cx - sink_door_w
	var sink_doors_right: float = sink_cx + sink_door_w
	# Vertical separators bounding the sink-base unit.
	for sep_x in [sink_doors_left, sink_cx, sink_doors_right]:
		draw_line(
			Vector2(sep_x, cab_top + 4),
			Vector2(sep_x, FLOOR_Y - 4),
			Color(0, 0, 0, 0.55), 2.0,
		)
	# Knobs on the INNER edges, 1.5" from the center seam, sat lower than
	# the adjacent base-cabinet knobs because the basin recess covers the
	# top of the sink-base doors. Real sink-base doors are shorter for
	# this reason; the knob lives near the (lower) top of that shorter
	# door, which is below the basin in our rendering.
	var sink_knob_y: float = cab_top + SINK_BASIN_H + 4.0
	var knob_inset: float = 1.5 * PX_PER_INCH  # 6 px from center seam
	draw_circle(Vector2(sink_cx - knob_inset, sink_knob_y), 2.5, Palette.BRASS_LIGHT)
	draw_circle(Vector2(sink_cx + knob_inset, sink_knob_y), 2.5, Palette.BRASS_LIGHT)

	# Adjacent regions to the left and right of the sink-base. Draw the
	# doors inside each region with the helper; the sink-base region's
	# own boundary seams (sink_doors_left / sink_doors_right) were
	# already drawn above so there's no gap between regions.
	var door_w: float = 24.0 * PX_PER_INCH  # 96
	_draw_cabinet_doors_in_region(x_left, sink_doors_left, cab_top, knob_y, door_w)
	_draw_cabinet_doors_in_region(sink_doors_right, x_right, cab_top, knob_y, door_w)

	# Counter-cabinet shadow line.
	draw_line(
		Vector2(x_left, cab_top),
		Vector2(x_right, cab_top),
		Palette.METAL_OUTLINE, 1.0, true,
	)

func _draw_cabinet_doors_in_region(x_left: float, x_right: float,
		cab_top: float, knob_y: float, target_door_w: float) -> void:
	# Lower-cabinet variant — seams run from cab_top to floor.
	_draw_cabinet_doors_in_vertical_region(
		x_left, x_right, cab_top + 4, FLOOR_Y - 4, knob_y, target_door_w,
	)

func _draw_cabinet_doors_in_vertical_region(x_left: float, x_right: float,
		seam_top_y: float, seam_bottom_y: float, knob_y: float,
		target_door_w: float) -> void:
	var width: float = x_right - x_left
	if width <= 8.0:
		return
	# Decide how many doors fit: enough that no door is wider than the
	# target. Use ceil so a 132-wide region with a 96-wide target gets
	# 2 doors, not 1.
	var n: int = max(1, int(ceil(width / target_door_w)))
	var door_w: float = width / n
	# Knobs go on the OPENING side: doors alternate hinge sides so the
	# knobs end up in pairs (door 1 hinges left → knob right; door 2
	# hinges right → knob left). When an odd door is alone, knob goes
	# on the right by default.
	var knob_inset: float = 2.0 * PX_PER_INCH  # 8 px from the door edge
	for i in range(n):
		var door_left: float = x_left + i * door_w
		var door_right: float = door_left + door_w
		# Internal seams only — skip the leftmost (region boundary).
		if i > 0:
			draw_line(
				Vector2(door_left, seam_top_y),
				Vector2(door_left, seam_bottom_y),
				Color(0, 0, 0, 0.55), 2.0,
			)
		# Knob on the side opposite the hinge: even-indexed doors hinge
		# left (knob right), odd-indexed doors hinge right (knob left).
		var knob_x: float
		if i % 2 == 0:
			knob_x = door_right - knob_inset
		else:
			knob_x = door_left + knob_inset
		draw_circle(Vector2(knob_x, knob_y), 2.5, Palette.BRASS_LIGHT)

func _draw_wall_cabinets(x_left: float, x_right: float) -> void:
	# Upper cabinets sit 18" above counter (above the splashback) and are
	# 30" tall. Width matches the counter run. The door directly above
	# the sink is a single 24"-wide door — same width as the sink-base
	# double-door below it, so the upper and lower cabinetry line up.
	var splash_h: float = 18.0 * PX_PER_INCH
	var cab_h: float = 30.0 * PX_PER_INCH  # 120 px
	var cab_bottom: float = COUNTER_Y - splash_h
	var cab_top: float = cab_bottom - cab_h
	var cab := Rect2(x_left, cab_top, x_right - x_left, cab_h)
	draw_rect(cab, Palette.WOOD_DARK)
	# Light edge along the top.
	draw_rect(Rect2(cab.position, Vector2(cab.size.x, 2)), Palette.WOOD_LIGHT)

	# Three regions: left of sink, over-sink (one wide door matching
	# the sink-base double-door width), right of sink. The region-
	# boundary seams (over_sink_left / over_sink_right) need to be
	# drawn separately — the helper only draws seams between INTERNAL
	# doors of a single region.
	var sink_cx: float = STATION_X[STATION_SINK]
	var over_sink_w: float = 24.0 * PX_PER_INCH  # 96 px (matches sink-base double)
	var over_sink_left: float = sink_cx - over_sink_w * 0.5
	var over_sink_right: float = sink_cx + over_sink_w * 0.5
	var upper_knob_y: float = cab_bottom - 6.0 * PX_PER_INCH
	# Region-boundary seams.
	for sep_x in [over_sink_left, over_sink_right]:
		draw_line(
			Vector2(sep_x, cab_top + 4),
			Vector2(sep_x, cab_bottom - 4),
			Color(0, 0, 0, 0.65), 2.0,
		)
	_draw_cabinet_doors_in_vertical_region(
		x_left, over_sink_left, cab_top + 4, cab_bottom - 4, upper_knob_y,
		18.0 * PX_PER_INCH,
	)
	_draw_cabinet_doors_in_vertical_region(
		over_sink_left, over_sink_right, cab_top + 4, cab_bottom - 4, upper_knob_y,
		over_sink_w,
	)
	_draw_cabinet_doors_in_vertical_region(
		over_sink_right, x_right, cab_top + 4, cab_bottom - 4, upper_knob_y,
		18.0 * PX_PER_INCH,
	)

	# Drop shadow under the cabinets (onto the splashback).
	draw_rect(
		Rect2(cab.position + Vector2(0, cab.size.y), Vector2(cab.size.x, 4)),
		Color(0, 0, 0, 0.45),
	)
	# Outline.
	draw_rect(cab, Palette.METAL_OUTLINE, false, 1.0)

func _draw_range_hood(cx: float) -> void:
	# 30" wide × 12" tall, mounted 30" above the cooktop. Shorter hood
	# than a full chimney-style — fits an apartment kitchen better.
	var w: float = 30.0 * PX_PER_INCH
	var h: float = 12.0 * PX_PER_INCH
	var bottom: float = COUNTER_Y - 30.0 * PX_PER_INCH
	var top: float = bottom - h
	var rect := Rect2(cx - w * 0.5, top, w, h)
	# Body (slightly lighter than stove metal so it reads against the wall).
	draw_rect(rect, Palette.METAL_MID)
	# Top bevel (lit edge).
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3)), Palette.METAL_SHINE)
	# Bottom underside (slight shadow band where the vent opening is).
	var underside_h: float = 6.0
	var underside := Rect2(
		rect.position + Vector2(8, rect.size.y - underside_h),
		Vector2(rect.size.x - 16, underside_h),
	)
	draw_rect(underside, Palette.METAL_DARK)
	# Vent slats.
	for i in range(4):
		var sx: float = underside.position.x + 6 + i * (underside.size.x - 12) / 3
		draw_line(
			Vector2(sx, underside.position.y + 1),
			Vector2(sx, underside.position.y + underside.size.y - 1),
			Color(0, 0, 0, 0.7), 1.0,
		)
	# Outline.
	draw_rect(rect, Palette.METAL_OUTLINE, false, 1.0)
	# Drop shadow on the wall just below the hood.
	draw_rect(
		Rect2(rect.position + Vector2(0, rect.size.y), Vector2(rect.size.x, 3)),
		Color(0, 0, 0, 0.40),
	)

func _draw_wall_clock(center: Vector2) -> void:
	# Standard 12" wall clock = 48 px diameter.
	var r: float = 6.0 * PX_PER_INCH  # 24 (radius)
	# Drop shadow under the clock.
	draw_circle(center + Vector2(2, 3), r, Color(0, 0, 0, 0.4))
	# Bezel.
	draw_circle(center, r, Palette.METAL_DARK)
	# Face.
	draw_circle(center, r - 3, Palette.BG_DEEP)
	draw_arc(center, r, 0, TAU, 32, Palette.METAL_OUTLINE, 1.0, true)
	# Hour ticks (12 positions).
	for i in range(12):
		var theta: float = TAU * float(i) / 12.0 - PI * 0.5
		var p1: Vector2 = center + Vector2(cos(theta), sin(theta)) * (r - 4)
		var p2: Vector2 = center + Vector2(cos(theta), sin(theta)) * (r - 7)
		var col: Color = Palette.METAL_LIGHT if i % 3 == 0 else Palette.METAL_MID
		var thickness: float = 1.5 if i % 3 == 0 else 1.0
		draw_line(p1, p2, col, thickness, true)
	# Hour hand (pointing roughly to 10).
	var hour_theta: float = TAU * (10.0 / 12.0) - PI * 0.5
	draw_line(center, center + Vector2(cos(hour_theta), sin(hour_theta)) * (r - 10), Palette.METAL_LIGHT, 2.0, true)
	# Minute hand (pointing roughly to 2).
	var min_theta: float = TAU * (2.0 / 12.0) - PI * 0.5
	draw_line(center, center + Vector2(cos(min_theta), sin(min_theta)) * (r - 6), Palette.METAL_SHINE, 1.5, true)
	# Center pin.
	draw_circle(center, 2.0, Palette.BRASS_LIGHT)

func _draw_wall_calendar(top_left: Vector2) -> void:
	# Wall calendar: 14"w × 17"h pad.
	var w: float = 14.0 * PX_PER_INCH  # 56
	var h: float = 17.0 * PX_PER_INCH  # 68
	var rect := Rect2(top_left, Vector2(w, h))
	# Drop shadow.
	draw_rect(Rect2(rect.position + Vector2(2, 3), rect.size), Color(0, 0, 0, 0.35))
	# Backing card (warm cream).
	draw_rect(rect, Color(0.92, 0.88, 0.78, 1))
	# Header band: month name (red).
	var header := Rect2(rect.position, Vector2(rect.size.x, h * 0.22))
	draw_rect(header, Color(0.62, 0.22, 0.18, 1))
	# Two staple dots in the header.
	draw_circle(rect.position + Vector2(8, header.size.y * 0.5), 2, Color(0.8, 0.8, 0.8, 0.9))
	draw_circle(rect.position + Vector2(rect.size.x - 8, header.size.y * 0.5), 2, Color(0.8, 0.8, 0.8, 0.9))
	# Tiny "month" text suggested by a dark stripe.
	draw_rect(
		Rect2(rect.position + Vector2(10, header.size.y * 0.6), Vector2(w - 20, 3)),
		Color(0.92, 0.88, 0.78, 0.6),
	)
	# Date grid (5 rows × 7 cols of tiny squares).
	var grid_top: float = rect.position.y + header.size.y + 4
	var cell_w: float = (w - 8) / 7.0
	var cell_h: float = (h - header.size.y - 8) / 5.0
	for row in range(5):
		for col in range(7):
			var px: float = rect.position.x + 4 + col * cell_w + cell_w * 0.5 - 1
			var py: float = grid_top + row * cell_h + cell_h * 0.5 - 1
			draw_rect(Rect2(px, py, 2, 2), Color(0.30, 0.27, 0.22, 0.85))
	# Outline.
	draw_rect(rect, Palette.METAL_OUTLINE, false, 1.0)

## World position of the journal notebook (in apartment-local coords).
## Sits upright on a small wall shelf above the bottling table.
const JOURNAL_W: float = 6.0 * PX_PER_INCH   # 24 px (book spine width)
const JOURNAL_H: float = 9.0 * PX_PER_INCH   # 36 px (book height upright)
## Where the wall shelf hangs.
const SHELF_BOTTOM_Y: float = COUNTER_Y - 36.0 * PX_PER_INCH  # 36" above counter
const SHELF_W: float = 36.0 * PX_PER_INCH  # 144 px wide

func _shelf_center_x() -> float:
	# Above the bottling table.
	return station_anchor(STATION_BOTTLING_TABLE).x

func journal_rect_world() -> Rect2:
	# Journal stands upright on the shelf, slightly right of center so
	# there's room for other future trinkets.
	var shelf_cx: float = _shelf_center_x()
	var shelf_top_y: float = SHELF_BOTTOM_Y - 1.5 * PX_PER_INCH  # shelf board top
	var x: float = shelf_cx + 18.0
	# Book bottom rests on the shelf top.
	return Rect2(x - JOURNAL_W * 0.5, shelf_top_y - JOURNAL_H, JOURNAL_W, JOURNAL_H)

func _draw_journal_notebook() -> void:
	# Draw the wall shelf first — a simple wood plank with under-shadow.
	var shelf_cx: float = _shelf_center_x()
	var shelf_thick: float = 1.5 * PX_PER_INCH  # 6 px
	var shelf_rect := Rect2(
		shelf_cx - SHELF_W * 0.5,
		SHELF_BOTTOM_Y - shelf_thick,
		SHELF_W,
		shelf_thick,
	)
	# Wall mount drop shadow under the shelf.
	draw_rect(
		Rect2(shelf_rect.position + Vector2(0, shelf_rect.size.y), Vector2(shelf_rect.size.x, 4)),
		Color(0, 0, 0, 0.45),
	)
	# Shelf board.
	draw_rect(shelf_rect, Palette.WOOD_MID)
	draw_rect(Rect2(shelf_rect.position, Vector2(shelf_rect.size.x, 1)), Palette.WOOD_LIGHT)
	draw_rect(
		Rect2(shelf_rect.position + Vector2(0, shelf_rect.size.y - 1), Vector2(shelf_rect.size.x, 1)),
		Palette.WOOD_DARK,
	)
	# Two small mounting brackets under the shelf.
	for bx in [shelf_rect.position.x + 12, shelf_rect.position.x + shelf_rect.size.x - 18]:
		draw_rect(
			Rect2(bx, shelf_rect.position.y + shelf_rect.size.y, 6, 8),
			Palette.METAL_DARK,
		)

	# Standing upright on the shelf, what's visible is the SPINE, not the
	# cover — a tall narrow rectangle with decorative gold bands.
	var rect: Rect2 = journal_rect_world()
	# Drop shadow.
	draw_rect(
		Rect2(rect.position + Vector2(1, 2), rect.size),
		Color(0, 0, 0, 0.45),
	)
	# Spine body (forest-green leather).
	var spine_color: Color = Color(0.18, 0.30, 0.22, 1)
	draw_rect(rect, spine_color)
	# Lit edge along the left of the spine.
	draw_rect(Rect2(rect.position, Vector2(2, rect.size.y)), Color(0.28, 0.40, 0.30, 1))
	# Top and bottom decorative gold bands.
	var band_h: float = 3.0
	draw_rect(
		Rect2(rect.position + Vector2(2, 4), Vector2(rect.size.x - 4, band_h)),
		Palette.BRASS_LIGHT,
	)
	draw_rect(
		Rect2(rect.position + Vector2(2, rect.size.y - 8), Vector2(rect.size.x - 4, band_h)),
		Palette.BRASS_LIGHT,
	)
	# Title plate in the middle of the spine (small faded gold rectangle).
	var title_h: float = rect.size.y * 0.30
	draw_rect(
		Rect2(rect.position + Vector2(3, rect.size.y * 0.42), Vector2(rect.size.x - 6, title_h)),
		Palette.BRASS_DARK,
	)
	# Outline.
	draw_rect(rect, Color(0, 0, 0, 0.6), false, 1.0)

## Bed dimensions for hit-testing.
const BED_W: float = 60.0 * PX_PER_INCH   # 240 px (~5')
const BED_H: float = 30.0 * PX_PER_INCH   # 120 px (mattress + frame + headboard area)
const BED_HEADBOARD_H: float = 30.0 * PX_PER_INCH  # 120 px (top of headboard above mattress)
func bed_rect_world() -> Rect2:
	# Bed footprint including the headboard tower above the mattress.
	var bed_cx: float = STATION_X[STATION_BED]
	var x_left: float = bed_cx - BED_W * 0.5
	var frame_h: float = 18.0 * PX_PER_INCH  # 72 px (box-spring height)
	var mattress_h: float = 6.0 * PX_PER_INCH  # 24 px
	var top_y: float = FLOOR_Y - frame_h - mattress_h - BED_HEADBOARD_H
	var height: float = FLOOR_Y - top_y
	return Rect2(x_left, top_y, BED_W, height)

func _draw_bed(cx: float) -> void:
	var frame_h: float = 18.0 * PX_PER_INCH  # 72 px box-spring height
	var mattress_h: float = 6.0 * PX_PER_INCH  # 24 px
	var x_left: float = cx - BED_W * 0.5
	var x_right: float = cx + BED_W * 0.5
	var frame_top: float = FLOOR_Y - frame_h
	var mattress_top: float = frame_top - mattress_h

	# 1. Headboard at the LEFT end (closer to the window). 6" thick, ~30" above mattress.
	var hb_w: float = 3.0 * PX_PER_INCH  # 12 px
	var hb_top: float = mattress_top - BED_HEADBOARD_H
	var headboard := Rect2(x_left, hb_top, hb_w, mattress_top - hb_top)
	# Drop shadow on the wall behind the headboard.
	draw_rect(
		Rect2(headboard.position + Vector2(headboard.size.x, 4), Vector2(8, headboard.size.y)),
		Color(0, 0, 0, 0.30),
	)
	draw_rect(headboard, Palette.WOOD_DARK)
	draw_rect(Rect2(headboard.position, Vector2(headboard.size.x, 2)), Palette.WOOD_LIGHT)
	# Headboard top finial — slightly wider cap.
	draw_rect(
		Rect2(headboard.position + Vector2(-2, 0), Vector2(headboard.size.x + 4, 4)),
		Palette.WOOD_MID,
	)

	# 2. Box-spring / frame — thick wooden rail under the mattress.
	var frame := Rect2(x_left + hb_w, frame_top, x_right - x_left - hb_w, frame_h)
	draw_rect(frame, Palette.WOOD_DARK)
	# Lit edge along top of frame.
	draw_rect(Rect2(frame.position, Vector2(frame.size.x, 2)), Palette.WOOD_LIGHT)
	# Bed feet showing under the frame at each end.
	for fx in [frame.position.x + 4, frame.position.x + frame.size.x - 16]:
		draw_rect(Rect2(fx, FLOOR_Y - 6, 12, 6), Palette.WOOD_DARK)

	# 3. Mattress — light cream cushion on top of the frame.
	var mattress := Rect2(x_left + hb_w, mattress_top, x_right - x_left - hb_w, mattress_h)
	var mattress_color: Color = Color(0.92, 0.88, 0.78, 1)
	draw_rect(mattress, mattress_color)
	# Top edge highlight.
	draw_rect(Rect2(mattress.position, Vector2(mattress.size.x, 2)), Color(0.96, 0.92, 0.82, 1))
	# Tufting buttons across the mattress side.
	for tx in range(int(mattress.position.x + 16), int(mattress.position.x + mattress.size.x - 8), 32):
		draw_circle(Vector2(tx, mattress.position.y + mattress.size.y * 0.5), 1.5, Color(0.78, 0.72, 0.62, 1))

	# 4. Comforter draped over the mattress (slightly thicker top layer).
	var comforter := Rect2(
		mattress.position + Vector2(0, -3),
		Vector2(mattress.size.x, 6),
	)
	draw_rect(comforter, Color(0.42, 0.30, 0.28, 1))  # warm muted brown
	draw_rect(Rect2(comforter.position, Vector2(comforter.size.x, 1)), Color(0.55, 0.42, 0.38, 1))

	# 5. Pillows at the head of the mattress (left end).
	var pillow_w: float = 16.0 * PX_PER_INCH  # 64 px
	var pillow_h: float = 5.0 * PX_PER_INCH  # 20 px
	var pillow_x: float = mattress.position.x + 4
	var pillow_y: float = mattress.position.y - pillow_h + 2
	var pillow := Rect2(pillow_x, pillow_y, pillow_w, pillow_h)
	draw_rect(pillow, Color(0.96, 0.94, 0.88, 1))
	draw_rect(Rect2(pillow.position, Vector2(pillow.size.x, 2)), Color(1, 0.98, 0.94, 1))
	# Subtle pillow seam.
	draw_line(
		Vector2(pillow.position.x + 4, pillow.position.y + pillow.size.y * 0.5),
		Vector2(pillow.position.x + pillow.size.x - 4, pillow.position.y + pillow.size.y * 0.5),
		Color(0.78, 0.74, 0.68, 0.5), 0.5,
	)
	# Outline around the pillow.
	draw_rect(pillow, Color(0, 0, 0, 0.4), false, 1.0)

	# 6. Bed outline (frame edge for crispness).
	draw_rect(frame, Color(0, 0, 0, 0.45), false, 1.0)
	draw_rect(mattress, Color(0, 0, 0, 0.35), false, 1.0)

func _draw_baseboard() -> void:
	# Baseboard runs along the visible wall gaps just above floor: 4" tall.
	# Closet/counter/stove/bottling-table cover their own floor footprint.
	var bb_h: float = 4.0 * PX_PER_INCH  # 16 px
	var bb_y: float = FLOOR_Y - bb_h
	# Visible wall segments (everywhere NOT covered by furniture/closet):
	# Layout: front door 48-192, bottling table 360-600, counter+stove
	# 600-1020, bed 1080-1320, closet 1436-1564. Visible wall gaps where
	# the baseboard runs along the floor:
	var segments := [
		Rect2(0, bb_y, 48, bb_h),       # left of front door
		Rect2(192, bb_y, 168, bb_h),    # front door → bottling table
		Rect2(1020, bb_y, 60, bb_h),    # stove → bed
		Rect2(1320, bb_y, 116, bb_h),   # bed → closet
		Rect2(1564, bb_y, 56, bb_h),    # right of closet → end
	]
	for seg in segments:
		draw_rect(seg, Palette.WOOD_DARK)
		draw_line(seg.position, Vector2(seg.position.x + seg.size.x, seg.position.y),
			Palette.WOOD_LIGHT, 1.0)

func _draw_bottling_table() -> void:
	# Free-standing wooden table: 60" wide × 30" tall × 30" deep.
	# We draw the side view: 240 wide × 120 tall, top sits at FLOOR_Y - 120.
	var w: float = 60.0 * PX_PER_INCH  # 240
	var top_thick: float = 1.5 * PX_PER_INCH  # 6
	var leg_w: float = 2.5 * PX_PER_INCH  # 10
	var x_left: float = 240.0  # bottling-table left edge
	var top_y: float = FLOOR_Y - 30.0 * PX_PER_INCH  # 420
	# Tabletop.
	var top := Rect2(x_left, top_y, w, top_thick)
	draw_rect(top, Palette.WOOD_MID)
	draw_rect(Rect2(top.position, Vector2(top.size.x, 1)), Palette.WOOD_LIGHT)
	# Apron under the top (small skirt).
	var apron := Rect2(x_left + 4, top_y + top_thick, w - 8, 4)
	draw_rect(apron, Palette.WOOD_DARK)
	# Two legs (square, set in 4" from each end).
	var leg_inset: float = 4.0 * PX_PER_INCH
	for lx in [x_left + leg_inset, x_left + w - leg_inset - leg_w]:
		var leg := Rect2(lx, top_y + top_thick + 4, leg_w, FLOOR_Y - (top_y + top_thick + 4))
		draw_rect(leg, Palette.WOOD_DARK)
		draw_rect(Rect2(leg.position, Vector2(1, leg.size.y)), Palette.WOOD_LIGHT)
	# Front shadow under tabletop.
	draw_line(
		Vector2(x_left, top_y + top_thick),
		Vector2(x_left + w, top_y + top_thick),
		Color(0, 0, 0, 0.45), 1.0,
	)

func _draw_stove(cx: float) -> void:
	# Freestanding range: 30" wide × 36" tall (cooktop top sits at counter top).
	var w: float = 30.0 * PX_PER_INCH  # 120
	var top_y: float = COUNTER_Y      # cooktop flush with counter
	var bottom_y: float = FLOOR_Y     # range bottom on floor
	var unit := Rect2(cx - w * 0.5, top_y, w, bottom_y - top_y)
	# Body.
	draw_rect(unit, Palette.METAL_DARK)
	# Top deck with burners.
	var deck := Rect2(unit.position, Vector2(unit.size.x, 36))
	draw_rect(deck, Palette.METAL_MID)
	draw_rect(Rect2(deck.position, Vector2(deck.size.x, 3)), Palette.METAL_SHINE)
	# 4 burners in a 2x2 layout on the deck. Burner = 4" diameter = 16 px.
	var br: float = 2.0 * PX_PER_INCH  # 8 (radius)
	for col in range(2):
		for row in range(2):
			var bx: float = unit.position.x + unit.size.x * 0.30 + col * unit.size.x * 0.40
			var by: float = unit.position.y + 10 + row * 14
			draw_circle(Vector2(bx, by), br, Palette.METAL_DARK)
			draw_arc(Vector2(bx, by), br - 1, 0, TAU, 18, Palette.METAL_OUTLINE, 1.5, true)
	# Front face — control panel area.
	var panel := Rect2(unit.position + Vector2(0, 36), Vector2(unit.size.x, 24))
	draw_rect(panel, Palette.METAL_MID)
	draw_rect(Rect2(panel.position, Vector2(panel.size.x, 1)), Palette.METAL_SHINE)
	draw_rect(
		Rect2(panel.position + Vector2(0, panel.size.y - 1), Vector2(panel.size.x, 1)),
		Palette.METAL_OUTLINE,
	)
	# 4 dials on the panel, sized to fit within the panel width.
	for d in range(4):
		var dx: float = unit.position.x + unit.size.x * 0.15 + d * unit.size.x * 0.235
		var dy: float = panel.position.y + panel.size.y * 0.5
		draw_circle(Vector2(dx, dy), 5, Palette.METAL_DARK)
		draw_circle(Vector2(dx, dy), 3.5, Palette.BRASS_DARK)
		draw_line(
			Vector2(dx, dy - 3), Vector2(dx, dy),
			Palette.BRASS_SHINE, 1.0, true,
		)
	# Oven door.
	var oven := Rect2(unit.position + Vector2(8, 64), Vector2(unit.size.x - 16, unit.size.y - 70))
	draw_rect(oven, Palette.METAL_DARK)
	draw_rect(Rect2(oven.position, Vector2(oven.size.x, 1)), Palette.METAL_OUTLINE)
	# Window in oven door.
	var window := Rect2(oven.position + Vector2(20, 16), Vector2(oven.size.x - 40, oven.size.y - 32))
	draw_rect(window, Color(0.06, 0.05, 0.04, 1))
	draw_rect(Rect2(window.position, Vector2(window.size.x, 1)), Palette.METAL_OUTLINE)
	draw_rect(Rect2(
		window.position + Vector2(0, window.size.y - 1),
		Vector2(window.size.x, 1),
	), Palette.METAL_OUTLINE)
	# Oven handle bar.
	var handle: Rect2 = Rect2(oven.position + Vector2(20, 6), Vector2(oven.size.x - 40, 5))
	draw_rect(handle, Palette.METAL_LIGHT)
	# Outline of the whole stove.
	draw_rect(unit, Palette.METAL_OUTLINE, false, 1.0)

func _draw_front_door(cx: float) -> void:
	# Apartment exterior door. Visually distinct from the closet:
	# slightly wider casing, single tall inset panel with a small
	# upper window pane, deadbolt above the knob, and a doormat in
	# front. Player taps it to leave the apartment (deliveries, bar,
	# beer festivals, research).
	var w: float = 32.0 * PX_PER_INCH  # 128 px (slightly wider than interior 30")
	var h: float = 80.0 * PX_PER_INCH  # 320 px
	var bot_y: float = FLOOR_Y
	var top_y: float = bot_y - h
	# Heavier casing for the exterior door.
	var casing_w: float = 8.0
	var casing := Rect2(cx - w * 0.5 - casing_w, top_y - casing_w,
		w + casing_w * 2, h + casing_w)
	draw_rect(casing, Color(0.10, 0.07, 0.05, 1))  # dark stained casing
	draw_rect(Rect2(casing.position, Vector2(casing.size.x, 3)), Palette.WOOD_LIGHT)
	# Door slab — painted-deep-color (not the warm interior wood).
	var door := Rect2(cx - w * 0.5, top_y, w, h)
	var door_paint: Color = Color(0.22, 0.16, 0.13, 1)
	draw_rect(door, door_paint)
	# Single tall inset panel from middle of door upward, with a small
	# 4-pane window at the top.
	var panel_inset_x: float = 4.0 * PX_PER_INCH  # 16
	var panel_top: float = top_y + 6.0 * PX_PER_INCH
	var panel_bot: float = bot_y - 24.0 * PX_PER_INCH
	var panel := Rect2(
		cx - w * 0.5 + panel_inset_x, panel_top,
		w - panel_inset_x * 2, panel_bot - panel_top,
	)
	draw_rect(panel, Color(0.16, 0.11, 0.09, 1))
	# Inset highlight.
	draw_line(panel.position, panel.position + Vector2(panel.size.x, 0),
		Color(0, 0, 0, 0.6), 1.0)
	draw_line(panel.position + Vector2(0, panel.size.y),
		panel.position + panel.size, Palette.WOOD_LIGHT, 1.0)
	# Window in upper portion of panel — 4 small panes.
	var window_h: float = panel.size.y * 0.32
	var window := Rect2(panel.position + Vector2(8, 8),
		Vector2(panel.size.x - 16, window_h))
	draw_rect(window, Color(0.40, 0.46, 0.48, 1))  # soft daylight
	# Cross mullions (4-pane).
	draw_line(
		Vector2(window.position.x + window.size.x * 0.5, window.position.y),
		Vector2(window.position.x + window.size.x * 0.5, window.position.y + window.size.y),
		door_paint, 2.0,
	)
	draw_line(
		Vector2(window.position.x, window.position.y + window.size.y * 0.5),
		Vector2(window.position.x + window.size.x, window.position.y + window.size.y * 0.5),
		door_paint, 2.0,
	)
	draw_rect(window, Color(0, 0, 0, 0.6), false, 1.0)
	# Doorknob 36" up from floor, on the right.
	var knob_y: float = FLOOR_Y - 36.0 * PX_PER_INCH
	var knob_x: float = door.position.x + door.size.x - 5.0 * PX_PER_INCH
	draw_circle(Vector2(knob_x + 1, knob_y + 1), 4, Color(0, 0, 0, 0.55))
	draw_circle(Vector2(knob_x, knob_y), 4, Palette.METAL_LIGHT)
	draw_circle(Vector2(knob_x - 1, knob_y - 1), 1.5, Palette.METAL_SHINE)
	# Deadbolt 6" above the knob.
	var deadbolt_y: float = knob_y - 6.0 * PX_PER_INCH
	draw_rect(
		Rect2(knob_x - 4, deadbolt_y - 3, 8, 6),
		Palette.METAL_DARK,
	)
	draw_rect(
		Rect2(knob_x - 3, deadbolt_y - 1, 2, 2),
		Palette.BRASS_LIGHT,
	)
	# Doormat in front of the door on the floor.
	var mat_w: float = 36.0 * PX_PER_INCH  # 144
	var mat_h: float = 4.0 * PX_PER_INCH  # 16
	var mat := Rect2(cx - mat_w * 0.5, FLOOR_Y, mat_w, mat_h)
	draw_rect(mat, Color(0.42, 0.30, 0.20, 1))  # warm bristle brown
	# Mat texture — short horizontal hash marks.
	for hx in range(int(mat.position.x + 6), int(mat.position.x + mat.size.x - 6), 6):
		draw_line(
			Vector2(hx, mat.position.y + 4),
			Vector2(hx, mat.position.y + mat.size.y - 4),
			Color(0.32, 0.22, 0.14, 1), 1.0,
		)
	# Mat outline.
	draw_rect(mat, Color(0, 0, 0, 0.5), false, 1.0)

func _draw_closet_door(cx: float) -> void:
	# Standard interior door: 30" wide × 80" tall.
	var w: float = 30.0 * PX_PER_INCH  # 120
	var h: float = 80.0 * PX_PER_INCH  # 320
	var bot_y: float = FLOOR_Y
	var top_y: float = bot_y - h
	# Door casing/frame (1" wider on each side).
	var casing_w: float = 4.0  # 1" frame
	var casing := Rect2(cx - w * 0.5 - casing_w, top_y - casing_w, w + casing_w * 2, h + casing_w)
	draw_rect(casing, Palette.WOOD_DARK)
	draw_rect(Rect2(casing.position, Vector2(casing.size.x, 2)), Palette.WOOD_LIGHT)
	# Door slab.
	var door := Rect2(cx - w * 0.5, top_y, w, h)
	draw_rect(door, Palette.WOOD_MID)
	# Two stacked inset panels (typical 6-panel door simplified to 2).
	var panel_inset_x: float = 3.0 * PX_PER_INCH  # 12
	var panel_inset_y: float = 4.0 * PX_PER_INCH  # 16
	var panel_gap: float = 2.0 * PX_PER_INCH  # 8 between top and bottom panel
	var panel_h: float = (h - panel_inset_y * 2 - panel_gap) * 0.5
	for i in range(2):
		var p_y: float = top_y + panel_inset_y + i * (panel_h + panel_gap)
		var panel := Rect2(door.position.x + panel_inset_x, p_y, w - panel_inset_x * 2, panel_h)
		# Inset shadow (top + left dark).
		draw_rect(panel, Palette.WOOD_DARK)
		# Inset highlight (bottom + right light edge).
		draw_line(panel.position + Vector2(0, 1), panel.position + Vector2(panel.size.x, 1),
			Color(0, 0, 0, 0.55), 1.0)
		draw_line(panel.position + Vector2(0, panel.size.y - 1), panel.position + panel.size - Vector2(0, 1),
			Palette.WOOD_LIGHT, 1.0)
	# Light edge on the hinge side (left, toward upper-left light).
	draw_rect(Rect2(door.position, Vector2(2, door.size.y)), Palette.WOOD_LIGHT)
	# Doorknob 36" up from floor (waist height) on the right side.
	var knob_y: float = FLOOR_Y - 36.0 * PX_PER_INCH
	var knob_x: float = door.position.x + door.size.x - 5.0 * PX_PER_INCH  # 5" from edge
	draw_circle(Vector2(knob_x + 1, knob_y + 1), 3.5, Color(0, 0, 0, 0.5))
	draw_circle(Vector2(knob_x, knob_y), 3.5, Palette.BRASS_LIGHT)
	draw_circle(Vector2(knob_x - 1, knob_y - 1), 1.0, Palette.BRASS_SHINE)
	# Faint warm strip under the door.
	draw_rect(
		Rect2(door.position.x, FLOOR_Y - 2, door.size.x, 2),
		Color(Palette.BRASS_SHINE.r, Palette.BRASS_SHINE.g, Palette.BRASS_SHINE.b, 0.18),
	)

func _draw_window(cx: float) -> void:
	# 36" wide × 48" tall window with sill 6" above counter level.
	var w: float = 36.0 * PX_PER_INCH  # 144
	var h: float = 48.0 * PX_PER_INCH  # 192
	var sill_y: float = COUNTER_Y - 6.0 * PX_PER_INCH  # 6" above counter
	var top_y: float = sill_y - h
	var frame_t: float = 1.5 * PX_PER_INCH  # 6
	var frame := Rect2(cx - w * 0.5, top_y, w, h)
	# Frame.
	draw_rect(frame, Palette.WOOD_MID)
	# Pane (night sky).
	var pane := Rect2(frame.position + Vector2(frame_t, frame_t), frame.size - Vector2(frame_t * 2, frame_t * 2))
	draw_rect(pane, Color("#0F1E2E"))
	# Cross dividers (mullions): horizontal at mid-pane, vertical at mid-pane.
	draw_line(
		Vector2(pane.position.x + pane.size.x * 0.5, pane.position.y),
		Vector2(pane.position.x + pane.size.x * 0.5, pane.position.y + pane.size.y),
		Palette.WOOD_MID, 3.0, true,
	)
	draw_line(
		Vector2(pane.position.x, pane.position.y + pane.size.y * 0.5),
		Vector2(pane.position.x + pane.size.x, pane.position.y + pane.size.y * 0.5),
		Palette.WOOD_MID, 3.0, true,
	)
	# Stars (random-ish positions inside the pane).
	var star_positions := [
		Vector2(0.18, 0.22), Vector2(0.32, 0.45), Vector2(0.78, 0.18),
		Vector2(0.62, 0.62), Vector2(0.88, 0.74), Vector2(0.45, 0.78),
		Vector2(0.22, 0.66), Vector2(0.92, 0.40),
	]
	for s in star_positions:
		var sp: Vector2 = pane.position + Vector2(pane.size.x * s.x, pane.size.y * s.y)
		draw_circle(sp, 1.0, Color(0.92, 0.88, 0.78, 0.85))
	# Frame outline.
	draw_rect(frame, Palette.METAL_OUTLINE, false, 1.0)
	# Sill below window: 2" thick × wider than the frame.
	var sill_h: float = 2.0 * PX_PER_INCH
	draw_rect(Rect2(frame.position.x - 8, sill_y, w + 16, sill_h), Palette.WOOD_LIGHT)
	draw_line(
		Vector2(frame.position.x - 8, sill_y + sill_h),
		Vector2(frame.position.x + w + 8, sill_y + sill_h),
		Color(0, 0, 0, 0.4), 1.0,
	)

func _draw_floor() -> void:
	var floor_rect := Rect2(0, FLOOR_Y, PANORAMA_W, PANORAMA_H - FLOOR_Y)
	draw_rect(floor_rect, Palette.WOOD_DARK)
	# Tile lines every 12" (real linoleum tile width).
	var tile_w: float = 12.0 * PX_PER_INCH  # 48 px
	for tx in range(0, int(PANORAMA_W), int(tile_w)):
		draw_line(
			Vector2(tx, FLOOR_Y),
			Vector2(tx, PANORAMA_H),
			Color(0, 0, 0, 0.30), 1.0,
		)
	# Subtle horizontal seam ~24" back from camera.
	draw_line(
		Vector2(0, FLOOR_Y + 24), Vector2(PANORAMA_W, FLOOR_Y + 24),
		Color(0, 0, 0, 0.25), 1.0,
	)

func _draw_sink(cx: float) -> void:
	# Recessed kitchen sink basin in the counter top: 22" wide × ~8" tall
	# visual footprint (the basin's drop-in flange shows as a metal lip
	# around a darker recess).
	var sink := Rect2(
		cx - SINK_BASIN_W * 0.5,
		COUNTER_Y - 2,
		SINK_BASIN_W,
		SINK_BASIN_H,
	)
	# Stainless rim.
	draw_rect(sink, Palette.METAL_MID)
	draw_rect(Rect2(sink.position, Vector2(sink.size.x, 1)), Palette.METAL_SHINE)
	# Recessed bowl.
	var bowl := Rect2(sink.position + Vector2(4, 3), sink.size - Vector2(8, 5))
	draw_rect(bowl, Color(0.10, 0.09, 0.08, 1))
	# Bowl rim shadow.
	draw_rect(Rect2(bowl.position, Vector2(bowl.size.x, 1)), Color(0, 0, 0, 0.7))
	# Drain in the middle of the bowl.
	var drain := Vector2(cx, bowl.position.y + bowl.size.y * 0.6)
	draw_circle(drain, 3.5, Color(0, 0, 0, 0.95))
	draw_arc(drain, 3.5, 0, TAU, 16, Palette.METAL_OUTLINE, 1.0, true)
	# Outline around the whole sink unit.
	draw_rect(sink, Palette.METAL_OUTLINE, false, 1.0)
