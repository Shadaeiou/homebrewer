extends Node2D
class_name FillKettleWaterBody

## Renders water inside the kettle: animated wavy surface (envelope-tapered to
## the walls so it pins to the meniscus), two-tone gradient, a meniscus arc
## where the water meets each side wall, and a polyline crest highlight.
##
## All colors come from Palette; surface phase is local time-based.

@export var kettle_path: NodePath
@export var capacity_litres: float = 6.0
@export var litres_to_pixels: float = 28.0  # 6 L * 28 px = 168 px max rise

var fill_litres: float = 0.0
var pour_intensity: float = 0.0  # 0..1, drives surface agitation
var time_since_last_pour: float = 999.0

var _kettle: FillKettleVessel
var _phase: float = 0.0

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
	var idle_decay: float = clampf(1.0 - time_since_last_pour / 1.5, 0.0, 1.0)
	amplitude = maxf(amplitude * (0.4 + 0.6 * idle_decay), 0.6)
	# Geometric clamp so the wave can't punch below the cap layer.
	var fill_depth: float = _kettle.inner_bottom_y - surface
	amplitude = minf(amplitude, maxf(fill_depth * 0.4, 0.0))

	# Build surface points; envelope amplitude → 0 at walls so polygon never
	# self-intersects at the corners and the surface "pins" to the meniscus.
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

	# Closed polygon: top wave (left→right) → right wall (down) → bottom edge
	# (right→left) → left wall (up). Explicit corners so triangulation is happy.
	var poly := PackedVector2Array()
	for p in top_points:
		poly.append(p)
	var wall_steps := 5
	for i in range(1, wall_steps + 1):
		var t: float = float(i) / float(wall_steps)
		var y: float = lerpf(surface, _kettle.inner_bottom_y, t)
		poly.append(Vector2(_kettle.inner_right_x_at(y), y))
	poly.append(Vector2(_kettle.inner_left_x_at(_kettle.inner_bottom_y), _kettle.inner_bottom_y))
	for i in range(1, wall_steps + 1):
		var t: float = float(i) / float(wall_steps)
		var y: float = lerpf(_kettle.inner_bottom_y, surface, t)
		poly.append(Vector2(_kettle.inner_left_x_at(y), y))

	draw_colored_polygon(poly, Palette.WATER_DEEP)

	# Mid-tone band (lighter blue layered on top to fake a gradient)
	var cap_depth: float = minf(fill_depth * 0.45, 60.0)
	if cap_depth > amplitude + 4.0:
		var cap := PackedVector2Array()
		for p in top_points:
			cap.append(p)
		cap.append(Vector2(_kettle.inner_right_x_at(surface + cap_depth), surface + cap_depth))
		cap.append(Vector2(_kettle.inner_left_x_at(surface + cap_depth), surface + cap_depth))
		draw_colored_polygon(cap, Palette.WATER_MID)

	# Surface highlight band — narrow lighter strip just below the wave crest.
	# Drawn as a polyline so it can never self-intersect.
	var crest := PackedVector2Array()
	for p in top_points:
		crest.append(p + Vector2(0, 1.5))
	draw_polyline(crest, Palette.WATER_LIGHT, 2.0, true)

	# Top specular highlight — thinner, lighter, offset toward the light.
	var spec_offset: Vector2 = Lighting.highlight_offset(0.5)
	var spec := PackedVector2Array()
	for p in top_points:
		spec.append(p + spec_offset + Vector2(0, 0.5))
	draw_polyline(spec, Palette.WATER_HIGHLIGHT, 1.0, true)

	# Meniscus arcs at each wall.
	for side in [-1, 1]:
		var x_anchor: float = _kettle.inner_left_x_at(surface) if side == -1 else _kettle.inner_right_x_at(surface)
		var pts := PackedVector2Array()
		var arc_steps := 8
		for i in range(arc_steps + 1):
			var t: float = float(i) / float(arc_steps)
			var dx: float = lerpf(0.0, 6.0 * float(side), 1.0 - t)
			var dy: float = -3.0 * sin(t * PI)
			pts.append(Vector2(x_anchor - dx, surface + dy))
		draw_polyline(pts, Palette.WATER_MENISCUS, 2.0, true)
