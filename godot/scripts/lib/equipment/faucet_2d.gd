extends Control
class_name Faucet2D

## Counter-mounted brass gooseneck faucet — front-3/4 view. Mounts on a
## visible base disc that sits on the counter behind the sink basin;
## a vertical riser rises from the base; an arch curves forward over
## the basin; a short downward spout dispenses water; a side lever
## handle toggles the flow.
##
## Anchor: the base disc sits at (size.x/2, size.y - 4) — the bottom of
## the bounding box is the counter mount line. Place the faucet so its
## bottom edge is at the counter top behind the basin.

signal toggled(is_on: bool)

# All measurements are in DISPLAY pixels (no Faucet2D-internal scaling).
# Sized against the apartment scale rule: 4 px = 1 inch. A 21"-reach
# gooseneck — tall enough that a 12" stockpot slides in under the spout.
const RAW_W: float = 44.0
const RAW_H: float = 84.0

## Mount point — bottom of the bounding box, slightly back from the
## front edge so the arch sweeps forward into the bounding box.
const MOUNT_X: float = 12.0
const MOUNT_Y: float = 84.0

## Riser column: 1.25" wide × ~14" tall.
const RISER_W: float = 5.0
const RISER_TOP_Y: float = 28.0  # riser height = 56 px

## Arch sweeps up from riser top and arcs forward (right) over the basin.
const ARCH_PEAK_Y: float = 8.0
const ARCH_FORWARD_X: float = 36.0  # 24 px forward of riser (~6" reach)

## Spout: short downturn from the arch's forward end.
const SPOUT_TIP_X: float = 36.0
const SPOUT_TIP_Y: float = 28.0

var is_on: bool = false
var _stream_t: float = 0.0
var _click_button: Button = null

func _ready() -> void:
	custom_minimum_size = Vector2(RAW_W, RAW_H)
	# Click area covers the lever handle on the left of the riser. Smaller
	# than the visual lever — fingers find it via the larger station-level
	# hit-test on dashboard, this is just the secondary local target.
	_click_button = Button.new()
	_click_button.flat = true
	_click_button.focus_mode = Control.FOCUS_NONE
	_click_button.size = Vector2(20, 24)
	_click_button.position = Vector2(0, 18)
	_click_button.pressed.connect(_on_handle_pressed)
	add_child(_click_button)
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if is_on:
		_stream_t += delta
		queue_redraw()

func set_on(state: bool) -> void:
	if is_on == state:
		return
	is_on = state
	toggled.emit(is_on)
	queue_redraw()

func _on_handle_pressed() -> void:
	set_on(not is_on)

func spout_tip_local() -> Vector2:
	return Vector2(SPOUT_TIP_X, SPOUT_TIP_Y)

func _draw() -> void:
	# 1. Base flange on the counter (perspective ellipse).
	var base_center := Vector2(MOUNT_X, MOUNT_Y - 1)
	# Soft shadow.
	_draw_ellipse(base_center + Vector2(0, 1), 7, 2.5, Color(0, 0, 0, 0.45))
	_draw_ellipse(base_center, 7, 2.5, Palette.BRASS_DARK)
	_draw_ellipse(base_center, 6, 2, Palette.BRASS_MID)
	_draw_ellipse(base_center + Vector2(-1, -0.5), 4, 1, Palette.BRASS_LIGHT)

	# 2. Riser column from base up to arch start.
	var riser_top: Vector2 = Vector2(MOUNT_X, RISER_TOP_Y)
	var riser_bottom: Vector2 = Vector2(MOUNT_X, MOUNT_Y - 2)
	var riser_rect := Rect2(
		Vector2(MOUNT_X - RISER_W * 0.5, riser_top.y),
		Vector2(RISER_W, riser_bottom.y - riser_top.y),
	)
	draw_rect(riser_rect, Palette.BRASS_MID)
	# Lit edge on the left (upper-left light source).
	draw_rect(
		Rect2(riser_rect.position, Vector2(2, riser_rect.size.y)),
		Palette.BRASS_LIGHT,
	)
	# Dark edge on the right.
	draw_rect(
		Rect2(riser_rect.position + Vector2(riser_rect.size.x - 2, 0), Vector2(2, riser_rect.size.y)),
		Palette.BRASS_DARK,
	)
	# Outline.
	draw_rect(riser_rect, Palette.BRASS_DARK, false, 1.0)

	# 3. Gooseneck arch from riser top to spout top, drawn as a thick
	# brass tube.
	var arch_pts: PackedVector2Array = _arch_points()
	# Drop shadow for the arch.
	var shadow_pts := PackedVector2Array()
	for p in arch_pts:
		shadow_pts.append(p + Vector2(1.5, 1.5))
	draw_polyline(shadow_pts, Color(0, 0, 0, 0.35), 7.0, true)
	# Arch body.
	draw_polyline(arch_pts, Palette.BRASS_DARK, 7.0, true)
	draw_polyline(arch_pts, Palette.BRASS_MID, 5.0, true)
	# Lit edge.
	var lit_pts := PackedVector2Array()
	for p in arch_pts:
		lit_pts.append(p + Vector2(-0.8, -0.8))
	draw_polyline(lit_pts, Palette.BRASS_LIGHT, 1.5, true)

	# 4. Spout — short downturn at the forward end of the arch.
	var spout_top := Vector2(SPOUT_TIP_X, ARCH_PEAK_Y + 8.0)
	var spout_bottom := Vector2(SPOUT_TIP_X, SPOUT_TIP_Y)
	# Slight outward flare at the bottom (aerator).
	var spout_poly := PackedVector2Array([
		Vector2(spout_top.x - 2, spout_top.y),
		Vector2(spout_top.x + 2, spout_top.y),
		Vector2(spout_bottom.x + 3, spout_bottom.y - 1),
		Vector2(spout_bottom.x + 3, spout_bottom.y),
		Vector2(spout_bottom.x - 3, spout_bottom.y),
		Vector2(spout_bottom.x - 3, spout_bottom.y - 1),
	])
	draw_colored_polygon(spout_poly, Palette.BRASS_MID)
	# Lit edge.
	draw_line(
		Vector2(spout_top.x - 2, spout_top.y),
		Vector2(spout_bottom.x - 3, spout_bottom.y),
		Palette.BRASS_LIGHT, 0.5, true,
	)
	# Aerator band.
	draw_rect(
		Rect2(spout_bottom.x - 3, spout_bottom.y - 1, 6, 1),
		Palette.BRASS_DARK,
	)

	# 5. Lever handle — sticks out to the left of the riser, angled up
	# when off, angled forward (down-left) when on.
	_draw_lever()

	# 6. Water stream when on.
	if is_on:
		_draw_stream(Vector2(SPOUT_TIP_X, SPOUT_TIP_Y))

func _arch_points() -> PackedVector2Array:
	# Quadratic Bezier from riser-top to spout-top, curving up over the basin.
	var p0 := Vector2(MOUNT_X, RISER_TOP_Y)
	var p2 := Vector2(SPOUT_TIP_X, RISER_TOP_Y)
	# Control point pulled high above the midpoint to make a wide arch.
	var p1 := Vector2((p0.x + p2.x) * 0.5, ARCH_PEAK_Y - 6.0)
	var pts := PackedVector2Array()
	var steps: int = 16
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		# Quadratic Bezier.
		var a: Vector2 = p0.lerp(p1, t)
		var b: Vector2 = p1.lerp(p2, t)
		pts.append(a.lerp(b, t))
	return pts

func _draw_lever() -> void:
	# Lever pivot is on the left side of the riser at handle height.
	var pivot := Vector2(MOUNT_X - RISER_W * 0.5 - 1.0, 32.0)
	var length: float = 9.0
	# Off: handle pointing up and to the left (resting position).
	# On:  handle pulled forward and down (water flows).
	var angle_off: float = -2.4  # ~ -137° (up-left)
	var angle_on: float = -1.0   # ~ -57° (forward-down-left)
	var angle: float = angle_on if is_on else angle_off
	var tip: Vector2 = pivot + Vector2(cos(angle), sin(angle)) * length
	# Lever body.
	draw_line(pivot + Vector2(0.5, 0.5), tip + Vector2(0.5, 0.5), Color(0, 0, 0, 0.4), 2.5, true)
	draw_line(pivot, tip, Palette.BRASS_DARK, 2.5, true)
	draw_line(pivot, tip, Palette.BRASS_MID, 1.5, true)
	# Tip cap.
	draw_circle(tip, 1.6, Palette.BRASS_DARK)
	draw_circle(tip + Vector2(-0.4, -0.4), 1.0, Palette.BRASS_LIGHT)
	# Pivot collar.
	draw_circle(pivot, 2.0, Palette.BRASS_DARK)
	draw_circle(pivot + Vector2(-0.4, -0.4), 1.2, Palette.BRASS_LIGHT)

func _draw_ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	var steps: int = 24
	for i in range(steps):
		var theta: float = TAU * float(i) / float(steps)
		pts.append(center + Vector2(cos(theta) * rx, sin(theta) * ry))
	draw_colored_polygon(pts, color)

func _draw_stream(tip_local: Vector2) -> void:
	var stream_top: Vector2 = tip_local + Vector2(0, 0)
	var stream_bottom: Vector2 = Vector2(tip_local.x, size.y + 60)
	var pts := PackedVector2Array()
	var pts_right := PackedVector2Array()
	var steps: int = 12
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var y: float = lerpf(stream_top.y, stream_bottom.y, t)
		var wobble: float = sin(_stream_t * 14.0 + t * 6.28) * 1.5
		var x_center: float = lerpf(stream_top.x, stream_bottom.x, t) + wobble
		pts.append(Vector2(x_center - 3, y))
		pts_right.append(Vector2(x_center + 3, y))
	var combined := PackedVector2Array()
	for p in pts:
		combined.append(p)
	for i in range(pts_right.size() - 1, -1, -1):
		combined.append(pts_right[i])
	draw_colored_polygon(combined, Palette.WATER_MID)
	draw_polyline(pts, Palette.WATER_HIGHLIGHT, 1.5, true)
	# Splash droplets near the spout.
	for j in range(3):
		var phase: float = fmod(_stream_t * 3.0 + j * 0.3, 1.0)
		var dy: float = phase * 18.0
		var dx: float = sin(_stream_t * 8.0 + j) * 6.0
		var alpha: float = (1.0 - phase) * 0.8
		draw_circle(
			Vector2(tip_local.x + dx, tip_local.y + dy),
			1.5,
			Color(Palette.WATER_HIGHLIGHT.r, Palette.WATER_HIGHLIGHT.g, Palette.WATER_HIGHLIGHT.b, alpha),
		)
