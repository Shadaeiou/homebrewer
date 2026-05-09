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

const PANORAMA_W: float = 1200.0
const PANORAMA_H: float = 620.0
const FLOOR_Y: float = 540.0
const COUNTER_Y: float = 380.0  # Counter top across the kitchen stretch.
const SHELF_Y: float = 60.0

## Station x-centers — the camera focuses on these.
const STATION_CLOSET: int = 0
const STATION_BOTTLING_TABLE: int = 1
const STATION_SINK: int = 2
const STATION_STOVE: int = 3
const STATION_DECOR: int = 4

const STATION_X: PackedFloat32Array = [120.0, 360.0, 600.0, 840.0, 1080.0]

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

var faucet: Faucet2D = null

func _ready() -> void:
	custom_minimum_size = Vector2(PANORAMA_W, PANORAMA_H)
	mouse_filter = Control.MOUSE_FILTER_PASS
	# Auto-instance the faucet at the sink station — it's apartment
	# infrastructure, not movable equipment, so it lives here.
	faucet = Faucet2D.new()
	faucet.name = "SinkFaucet"
	# Faucet placement math:
	#   sink_anchor.y is COUNTER_Y (top of counter, where kettle bottom sits).
	#   A kettle's TOP sits ~228px above the counter (Kettle2D HEIGHT+padding).
	#   We want the faucet's spout ~22px above where the kettle's rim will be.
	#   Faucet spout_tip_local.y = size.y - 4 ≈ 106 for the 110-tall faucet.
	# So faucet.position.y = sink_anchor.y - 228 (kettle top) - 22 (gap)
	#                         + 8 (kettle's internal rim padding offset)
	#                         - 106 (where spout sits in faucet-local).
	# That puts the spout right above the kettle's rim regardless of whether
	# a kettle is currently placed.
	var sink_anchor: Vector2 = station_anchor(STATION_SINK)
	faucet.position = Vector2(
		sink_anchor.x - 40,
		sink_anchor.y - 348,
	)
	add_child(faucet)
	queue_redraw()

func _draw() -> void:
	# Wall (top portion).
	draw_rect(Rect2(0, 0, PANORAMA_W, COUNTER_Y), Palette.BG_WARM)
	# Subtle dark band right above the counter — fakes ambient occlusion.
	draw_rect(Rect2(0, COUNTER_Y - 32, PANORAMA_W, 32), Palette.BG_MID)

	# Splashback strip (slight band of "tile") behind the kitchen stretch.
	# Stops at the counter break before the bottling table, picks up at sink.
	var splash_left: float = 470
	var splash_right: float = 970
	draw_rect(
		Rect2(splash_left, COUNTER_Y - 96, splash_right - splash_left, 64),
		Palette.BG_DEEP,
	)
	for x in range(int(splash_left), int(splash_right), 60):
		draw_line(
			Vector2(x, COUNTER_Y - 96),
			Vector2(x, COUNTER_Y - 32),
			Color(Palette.BG_WARM.r, Palette.BG_WARM.g, Palette.BG_WARM.b, 0.55),
			1.0,
		)
	draw_line(
		Vector2(splash_left, COUNTER_Y - 64),
		Vector2(splash_right, COUNTER_Y - 64),
		Color(Palette.BG_WARM.r, Palette.BG_WARM.g, Palette.BG_WARM.b, 0.55),
		1.0,
	)

	# Counter — a continuous wood strip from the sink area through the stove.
	# Bottling table is a SEPARATE piece on the left.
	var counter_left: float = 470
	var counter_right: float = 970
	_draw_counter_strip(counter_left, counter_right)

	# Bottling table (separate piece of furniture, with legs).
	_draw_bottling_table()

	# Stove (right of counter).
	_draw_stove(840)

	# Closet door (far left wall).
	_draw_closet_door(120)

	# Window + decor (far right).
	_draw_window(1080)

	# Floor (whole panorama, below counter level).
	_draw_floor()

	# Sink recess in the counter at sink station.
	_draw_sink(600)

	# Subtle vignette on the wall edges so the room feels enclosed.
	draw_rect(
		Rect2(0, 0, 80, COUNTER_Y),
		Color(0, 0, 0, 0.30),
	)
	draw_rect(
		Rect2(PANORAMA_W - 80, 0, 80, COUNTER_Y),
		Color(0, 0, 0, 0.30),
	)

func _draw_counter_strip(x_left: float, x_right: float) -> void:
	var top := Rect2(x_left, COUNTER_Y, x_right - x_left, 28)
	draw_rect(top, Palette.WOOD_MID)
	draw_rect(Rect2(top.position, Vector2(top.size.x, 4)), Palette.WOOD_LIGHT)
	# Wood grain.
	for i in range(6):
		var ty: float = COUNTER_Y + 12 + i * 4
		draw_line(
			Vector2(x_left + 8, ty),
			Vector2(x_right - 8, ty + (i % 2) * 1),
			Color(Palette.WOOD_GRAIN.r, Palette.WOOD_GRAIN.g, Palette.WOOD_GRAIN.b, 0.20),
			1.0,
		)
	# Cabinet face below the counter.
	var cab := Rect2(x_left, COUNTER_Y + 28, x_right - x_left, FLOOR_Y - COUNTER_Y - 28)
	draw_rect(cab, Palette.WOOD_DARK)
	# Cabinet door cuts.
	for door_x in [x_left + 80, x_left + 240, x_left + 400]:
		draw_line(
			Vector2(door_x, COUNTER_Y + 32),
			Vector2(door_x, FLOOR_Y - 6),
			Color(0, 0, 0, 0.55), 2.0,
		)
		# Tiny knob.
		draw_circle(Vector2(door_x - 8, COUNTER_Y + 64), 3, Palette.BRASS_LIGHT)
	# Counter-cabinet shadow line.
	draw_line(
		Vector2(x_left, COUNTER_Y + 28),
		Vector2(x_right, COUNTER_Y + 28),
		Palette.METAL_OUTLINE, 1.0, true,
	)

func _draw_bottling_table() -> void:
	# Small free-standing wooden table, shorter than the kitchen counter.
	var top: Rect2 = Rect2(260, COUNTER_Y + 18, 200, 18)
	draw_rect(top, Palette.WOOD_MID)
	draw_rect(Rect2(top.position, Vector2(top.size.x, 3)), Palette.WOOD_LIGHT)
	# Front shadow under the tabletop.
	draw_rect(
		Rect2(top.position + Vector2(0, top.size.y), Vector2(top.size.x, 3)),
		Color(0, 0, 0, 0.55),
	)
	# Two legs.
	for leg_x in [285.0, 435.0]:
		var leg := Rect2(leg_x, COUNTER_Y + 36, 14, FLOOR_Y - COUNTER_Y - 36)
		draw_rect(leg, Palette.WOOD_DARK)
		draw_rect(Rect2(leg.position, Vector2(2, leg.size.y)), Palette.WOOD_GRAIN)

func _draw_stove(cx: float) -> void:
	# Rectangular stove unit centered at cx.
	var w: float = 200.0
	var top_y: float = COUNTER_Y - 8
	var bottom_y: float = FLOOR_Y - 6
	var unit := Rect2(cx - w * 0.5, top_y, w, bottom_y - top_y)
	# Body.
	draw_rect(unit, Palette.METAL_DARK)
	# Top deck with burners.
	var deck := Rect2(unit.position, Vector2(unit.size.x, 36))
	draw_rect(deck, Palette.METAL_MID)
	draw_rect(Rect2(deck.position, Vector2(deck.size.x, 3)), Palette.METAL_SHINE)
	# 4 burners in a 2x2 layout on the deck.
	for col in range(2):
		for row in range(2):
			var bx: float = unit.position.x + 32 + col * 70
			var by: float = unit.position.y + 12 + row * 14
			# Burner well
			draw_circle(Vector2(bx, by), 10, Palette.METAL_DARK)
			# Burner ring
			draw_arc(Vector2(bx, by), 9, 0, TAU, 18, Palette.METAL_OUTLINE, 1.5, true)
	# Front face — control panel area.
	var panel := Rect2(unit.position + Vector2(0, 36), Vector2(unit.size.x, 24))
	draw_rect(panel, Palette.METAL_MID)
	draw_rect(Rect2(panel.position, Vector2(panel.size.x, 1)), Palette.METAL_SHINE)
	draw_rect(
		Rect2(panel.position + Vector2(0, panel.size.y - 1), Vector2(panel.size.x, 1)),
		Palette.METAL_OUTLINE,
	)
	# 4 dials on the panel.
	for d in range(4):
		var dx: float = unit.position.x + 30 + d * 48
		var dy: float = panel.position.y + panel.size.y * 0.5
		draw_circle(Vector2(dx, dy), 7, Palette.METAL_DARK)
		draw_circle(Vector2(dx, dy), 5, Palette.BRASS_DARK)
		draw_line(
			Vector2(dx, dy - 4), Vector2(dx, dy),
			Palette.BRASS_SHINE, 1.5, true,
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

func _draw_closet_door(cx: float) -> void:
	# Tall door against the left wall with a small handle.
	var w: float = 140.0
	var top_y: float = 60.0
	var bot_y: float = FLOOR_Y - 4
	var door := Rect2(cx - w * 0.5, top_y, w, bot_y - top_y)
	draw_rect(door, Palette.WOOD_DARK)
	# Frame.
	draw_rect(door, Palette.METAL_OUTLINE, false, 2.0)
	# Inset panel.
	var panel := Rect2(door.position + Vector2(14, 24), door.size - Vector2(28, 56))
	draw_rect(panel, Palette.WOOD_GRAIN)
	draw_rect(panel, Palette.METAL_OUTLINE, false, 1.0)
	# Light strip on left edge of door (toward upper-left light).
	draw_rect(Rect2(door.position, Vector2(3, door.size.y)), Palette.WOOD_LIGHT)
	# Doorknob.
	draw_circle(Vector2(door.position.x + door.size.x - 16, door.position.y + door.size.y * 0.5), 4, Palette.BRASS_LIGHT)
	# "Cool, dry place" hint — a strip of light leaking from under the door.
	draw_rect(
		Rect2(door.position.x - 3, FLOOR_Y - 6, door.size.x + 6, 4),
		Color(Palette.BRASS_SHINE.r, Palette.BRASS_SHINE.g, Palette.BRASS_SHINE.b, 0.20),
	)

func _draw_window(cx: float) -> void:
	# Frame.
	var w: float = 160.0
	var h: float = 180.0
	var frame := Rect2(cx - w * 0.5, 90, w, h)
	draw_rect(frame, Palette.WOOD_MID)
	# Pane (night sky-ish dark blue).
	var pane := Rect2(frame.position + Vector2(8, 8), frame.size - Vector2(16, 16))
	draw_rect(pane, Color("#0F1E2E"))
	# Cross dividers.
	draw_line(
		Vector2(pane.position.x + pane.size.x * 0.5, pane.position.y),
		Vector2(pane.position.x + pane.size.x * 0.5, pane.position.y + pane.size.y),
		Palette.WOOD_MID, 4.0, true,
	)
	draw_line(
		Vector2(pane.position.x, pane.position.y + pane.size.y * 0.5),
		Vector2(pane.position.x + pane.size.x, pane.position.y + pane.size.y * 0.5),
		Palette.WOOD_MID, 4.0, true,
	)
	# A few "stars" in the pane.
	for s in [Vector2(20, 28), Vector2(40, 60), Vector2(110, 36), Vector2(85, 95), Vector2(130, 130)]:
		var sp: Vector2 = pane.position + s
		draw_circle(sp, 1.5, Color(0.85, 0.78, 0.70, 0.85))
	# Frame outline.
	draw_rect(frame, Palette.METAL_OUTLINE, false, 2.0)
	# Sill below window.
	draw_rect(Rect2(frame.position + Vector2(-8, h), Vector2(w + 16, 8)), Palette.WOOD_LIGHT)

func _draw_floor() -> void:
	var floor_rect := Rect2(0, FLOOR_Y, PANORAMA_W, PANORAMA_H - FLOOR_Y)
	draw_rect(floor_rect, Palette.WOOD_DARK)
	# Tile lines for that linoleum-but-warmer feel.
	for tx in range(0, int(PANORAMA_W), 80):
		draw_line(
			Vector2(tx, FLOOR_Y),
			Vector2(tx, PANORAMA_H),
			Color(0, 0, 0, 0.30), 1.0,
		)
	# Subtle horizontal seam line.
	draw_line(
		Vector2(0, FLOOR_Y + 30), Vector2(PANORAMA_W, FLOOR_Y + 30),
		Color(0, 0, 0, 0.25), 1.0,
	)

func _draw_sink(cx: float) -> void:
	var sw: float = 180.0
	var sh: float = 24.0
	var sink := Rect2(cx - sw * 0.5, COUNTER_Y - 4, sw, sh)
	draw_rect(sink, Palette.METAL_DARK)
	draw_rect(Rect2(sink.position, Vector2(sink.size.x, 1)), Palette.METAL_OUTLINE)
	draw_rect(
		Rect2(sink.position + Vector2(0, sink.size.y - 2), Vector2(sink.size.x, 2)),
		Palette.METAL_MID,
	)
	# Drain in the middle.
	var drain := Vector2(cx, sink.position.y + sink.size.y * 0.5)
	draw_circle(drain, 5, Color(0, 0, 0, 0.85))
	draw_arc(drain, 5, 0, TAU, 16, Palette.METAL_OUTLINE, 1.0, true)
