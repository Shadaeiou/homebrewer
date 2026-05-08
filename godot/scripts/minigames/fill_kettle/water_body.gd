extends Node2D
class_name FillKettleWaterBody

## Renders the water sitting inside the kettle, with an animated wavy surface
## and a meniscus where the surface meets the kettle walls.
##
## `fill_litres` is the player-visible amount; `litres_to_pixels` converts to
## the rendered surface height. The kettle determines the inner geometry.

@export var kettle_path: NodePath
@export var capacity_litres: float = 6.0
@export var litres_to_pixels: float = 28.0  # 6 L * 28 px = 168 px max rise

var fill_litres: float = 0.0
var pour_intensity: float = 0.0  # 0..1, drives surface agitation
var time_since_last_pour: float = 999.0

var _kettle: FillKettleVessel
var _phase: float = 0.0

const WATER_DEEP := Color(0.20, 0.50, 0.78, 0.82)
const WATER_SHALLOW := Color(0.55, 0.80, 0.95, 0.78)
const WATER_HIGHLIGHT := Color(0.92, 0.97, 1.00, 0.55)
const MENISCUS := Color(0.82, 0.92, 1.00, 0.85)

func _ready() -> void:
	_kettle = get_node(kettle_path)

func _process(delta: float) -> void:
	_phase += delta * (3.5 + pour_intensity * 4.0)
	time_since_last_pour += delta
	queue_redraw()

func surface_y() -> float:
	var rise: float = fill_litres * litres_to_pixels
	return _kettle.inner_bottom_y - rise

func _draw() -> void:
	if _kettle == null or fill_litres <= 0.0:
		return

	var surface: float = surface_y()
	if surface > _kettle.inner_bottom_y:
		surface = _kettle.inner_bottom_y

	var samples := 24
	var amplitude: float = 1.5 + pour_intensity * 3.5
	# Decay agitation over ~1.5s after pouring stops.
	var idle_decay: float = clampf(1.0 - time_since_last_pour / 1.5, 0.0, 1.0)
	amplitude = maxf(amplitude * (0.4 + 0.6 * idle_decay), 0.6)
	# Clamp amplitude to never exceed 40% of available fill depth — otherwise
	# a wave crest can dip below the cap polygon's bottom or below the right-
	# wall start, which makes the surface poly self-intersect.
	var fill_depth: float = _kettle.inner_bottom_y - surface
	amplitude = minf(amplitude, maxf(fill_depth * 0.4, 0.0))

	# Build surface points sampled across the inner width at `surface`.
	# Wave amplitude tapers to zero at the walls (sin envelope) so the surface
	# is pinned to the meniscus and the polygon never folds at the corners.
	var top_points := PackedVector2Array()
	for i in range(samples + 1):
		var t: float = float(i) / float(samples)
		var y: float = surface
		var left: float = _kettle.inner_left_x_at(y)
		var right: float = _kettle.inner_right_x_at(y)
		var x: float = lerpf(left, right, t)
		var envelope: float = sin(t * PI)
		var wave: float = (
			sin(_phase + t * 6.0) * amplitude
			+ sin(_phase * 1.7 + t * 11.0) * amplitude * 0.4
		) * envelope
		top_points.append(Vector2(x, y + wave))

	# Closed polygon: top wave (left→right) + right wall (top→bottom, including
	# bottom-right corner) + bottom (right→left) + left wall (bottom→top).
	# Explicit corners at inner_bottom_y so Godot's triangulator never sees a
	# wonky closing diagonal.
	var poly := PackedVector2Array()
	for p in top_points:
		poly.append(p)
	# Right wall: from a hair below surface down to inner_bottom corner
	var wall_steps := 5
	for i in range(1, wall_steps + 1):
		var t: float = float(i) / float(wall_steps)
		var y: float = lerpf(surface, _kettle.inner_bottom_y, t)
		poly.append(Vector2(_kettle.inner_right_x_at(y), y))
	# Bottom edge — explicitly close at the inner-bottom-left corner
	poly.append(Vector2(_kettle.inner_left_x_at(_kettle.inner_bottom_y), _kettle.inner_bottom_y))
	# Left wall: from inner_bottom up to surface
	for i in range(1, wall_steps + 1):
		var t: float = float(i) / float(wall_steps)
		var y: float = lerpf(_kettle.inner_bottom_y, surface, t)
		poly.append(Vector2(_kettle.inner_left_x_at(y), y))

	draw_colored_polygon(poly, WATER_DEEP)

	# Lighter cap layer to fake a gradient (top portion of fill volume).
	# Skip when there's barely any water — the cap polygon collapses.
	var cap_depth: float = minf((_kettle.inner_bottom_y - surface) * 0.45, 60.0)
	if cap_depth > amplitude + 4.0:
		var cap := PackedVector2Array()
		for p in top_points:
			cap.append(p)
		cap.append(Vector2(_kettle.inner_right_x_at(surface + cap_depth), surface + cap_depth))
		cap.append(Vector2(_kettle.inner_left_x_at(surface + cap_depth), surface + cap_depth))
		draw_colored_polygon(cap, WATER_SHALLOW)

	# Surface highlight: a polyline along the wave crest. Drawn as a thick
	# bright line rather than a closed polygon so it can never self-intersect
	# even when the wave amplitude grows during a heavy pour.
	var crest := PackedVector2Array()
	for p in top_points:
		crest.append(p + Vector2(0, 1.5))
	draw_polyline(crest, WATER_HIGHLIGHT, 2.0)

	# Meniscus: small lifted curve where water meets each wall
	for side in [-1, 1]:
		var x_anchor: float = _kettle.inner_left_x_at(surface) if side == -1 else _kettle.inner_right_x_at(surface)
		var pts := PackedVector2Array()
		var arc_steps := 8
		for i in range(arc_steps + 1):
			var t: float = float(i) / float(arc_steps)
			var dx: float = lerpf(0.0, 6.0 * float(side), 1.0 - t)
			var dy: float = -3.0 * sin(t * PI)
			pts.append(Vector2(x_anchor - dx, surface + dy))
		draw_polyline(pts, MENISCUS, 2.0)
