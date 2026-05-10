extends Control

## Transfer + pitch — close-up mini-game.
##
## Kettle on the left, fermenter bucket on the right, auto-siphon
## between them. Tap the siphon to start the transfer (animated wort
## level dropping in kettle, rising in fermenter). After transfer is
## complete, the yeast packet on the counter glows — tap to pitch.
## Outcomes honour the existing test contract via the same internal
## fields (_selected_pour, _selected_pitch, _options).

signal minigame_completed(outcome: Dictionary)

const TRANSFER_DURATION_SEC: float = 4.0

@onready var _stage_title: Label = %StageTitle
@onready var _pour_group: VBoxContainer = %PourGroup
@onready var _pitch_group: VBoxContainer = %PitchGroup
@onready var _options_group: VBoxContainer = %OptionsGroup
@onready var _confirm_button: Button = %ConfirmButton
@onready var _stage_view: Control = %StageView
@onready var _siphon_button: Button = %SiphonButton
@onready var _yeast_button: Button = %YeastButton
@onready var _funnel_button: Button = %FunnelButton

var _stage_meta: Dictionary = {}
var _pour_radios: Dictionary = {}
var _pitch_radios: Dictionary = {}
var _options: Dictionary = {}
var _selected_pour: String = "gentle"
var _selected_pitch: String = "sprinkle"

var _transfer_started: bool = false
var _transfer_t: float = 0.0
var _transfer_done: bool = false
var _yeast_pitched: bool = false
var _resolved: bool = false
var _t: float = 0.0

func _ready() -> void:
	set_process(true)
	_confirm_button.visible = false
	_render_pour_radios()
	_render_pitch_radios()
	_render_options()
	if _stage_view != null:
		_stage_view.draw.connect(_draw_stage)
		_stage_view.resized.connect(_stage_view.queue_redraw)
	_siphon_button.pressed.connect(_on_siphon_tapped)
	_yeast_button.pressed.connect(_on_yeast_tapped)
	_funnel_button.pressed.connect(_on_funnel_tapped)

func set_stage_meta(stage: Dictionary) -> void:
	_stage_meta = stage

func _process(delta: float) -> void:
	if _resolved:
		return
	_t += delta
	if _transfer_started and not _transfer_done:
		_transfer_t += delta
		if _transfer_t >= TRANSFER_DURATION_SEC:
			_transfer_done = true
	if _transfer_done and _yeast_pitched:
		_resolved = true
		_on_confirm_pressed()
		return
	_stage_view.queue_redraw()

func _on_siphon_tapped() -> void:
	if _resolved:
		return
	if not _transfer_started:
		_transfer_started = true

func _on_yeast_tapped() -> void:
	if _resolved or not _transfer_done:
		return
	_yeast_pitched = true
	# Default sprinkle method via this button (rehydrate would be a
	# different pre-step we can wire later).

func _on_funnel_tapped() -> void:
	# Tap the funnel BEFORE transferring to count as sanitized.
	if _transfer_started:
		return
	if _options.has("sanitize_funnel"):
		_options["sanitize_funnel"].button_pressed = true

# ---- Drawing ----

func _draw_stage() -> void:
	var sz: Vector2 = _stage_view.size
	if sz.x <= 0:
		return
	_stage_view.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.06, 0.06, 0.08, 1))
	_draw_counter(sz)
	_draw_kettle(sz)
	_draw_fermenter(sz)
	_draw_siphon(sz)
	_draw_yeast_packet(sz)
	_draw_funnel(sz)
	_position_hotspots(sz)

func _draw_counter(sz: Vector2) -> void:
	var top_y: float = sz.y * 0.62
	_stage_view.draw_rect(Rect2(0, top_y, sz.x, 8), Palette.WOOD_LIGHT)
	_stage_view.draw_rect(Rect2(0, top_y + 8, sz.x, sz.y - top_y - 8), Palette.WOOD_DARK)

func _draw_kettle(sz: Vector2) -> void:
	var cx: float = sz.x * 0.30
	var bot_y: float = sz.y * 0.62
	var top_half: float = 60.0
	var bot_half: float = 50.0
	var kettle_h: float = 100.0
	var rim_y: float = bot_y - kettle_h
	# Body.
	var wall_t: float = 5.0
	_stage_view.draw_colored_polygon(PackedVector2Array([
		Vector2(cx - top_half, rim_y),
		Vector2(cx - top_half + wall_t, rim_y),
		Vector2(cx - bot_half + wall_t, bot_y - wall_t),
		Vector2(cx + bot_half - wall_t, bot_y - wall_t),
		Vector2(cx + bot_half, bot_y),
		Vector2(cx - bot_half, bot_y),
	]), Palette.METAL_MID)
	# Inside.
	_stage_view.draw_colored_polygon(PackedVector2Array([
		Vector2(cx - top_half + wall_t, rim_y + 4),
		Vector2(cx + top_half - 3, rim_y + 4),
		Vector2(cx + bot_half - 3, bot_y - wall_t),
		Vector2(cx - bot_half + wall_t, bot_y - wall_t),
	]), Color(0.06, 0.06, 0.06, 1))
	# Wort level — drops as transfer progresses.
	var transfer_progress: float = clampf(_transfer_t / TRANSFER_DURATION_SEC, 0.0, 1.0)
	var wort_top_y: float = lerpf(rim_y + 12, bot_y - wall_t, transfer_progress)
	if wort_top_y < bot_y - wall_t:
		_stage_view.draw_colored_polygon(PackedVector2Array([
			Vector2(cx - (top_half - wall_t - 1), wort_top_y),
			Vector2(cx + (top_half - wall_t - 1), wort_top_y),
			Vector2(cx + (bot_half - wall_t - 1), bot_y - wall_t),
			Vector2(cx - (bot_half - wall_t - 1), bot_y - wall_t),
		]), Color(0.32, 0.18, 0.10, 1))
	# Rim.
	_stage_view.draw_colored_polygon(PackedVector2Array([
		Vector2(cx - top_half - 2, rim_y - 2),
		Vector2(cx + top_half + 2, rim_y - 2),
		Vector2(cx + top_half, rim_y + 4),
		Vector2(cx - top_half, rim_y + 4),
	]), Palette.METAL_LIGHT)

func _draw_fermenter(sz: Vector2) -> void:
	var cx: float = sz.x * 0.72
	var bot_y: float = sz.y * 0.85
	var top_half: float = 64.0
	var bot_half: float = 58.0
	var bucket_h: float = 130.0
	var rim_y: float = bot_y - bucket_h
	# Bucket body (white-ish food-grade plastic).
	_stage_view.draw_colored_polygon(PackedVector2Array([
		Vector2(cx - top_half, rim_y),
		Vector2(cx + top_half, rim_y),
		Vector2(cx + bot_half, bot_y),
		Vector2(cx - bot_half, bot_y),
	]), Color(0.85, 0.82, 0.76, 1))
	# Lit edge.
	_stage_view.draw_polyline(PackedVector2Array([
		Vector2(cx - top_half, rim_y),
		Vector2(cx - bot_half, bot_y),
	]), Color(0.95, 0.92, 0.88, 1), 2.0, true)
	# Wort level inside fermenter (rises as transfer progresses).
	var transfer_progress: float = clampf(_transfer_t / TRANSFER_DURATION_SEC, 0.0, 1.0)
	var wort_top_y: float = lerpf(bot_y - 10, rim_y + 10, transfer_progress)
	if transfer_progress > 0.0:
		var t: float = (wort_top_y - rim_y) / max(bucket_h, 0.01)
		var inside_half: float = lerpf(top_half - 4, bot_half - 4, t)
		_stage_view.draw_colored_polygon(PackedVector2Array([
			Vector2(cx - inside_half, wort_top_y),
			Vector2(cx + inside_half, wort_top_y),
			Vector2(cx + bot_half - 4, bot_y - 4),
			Vector2(cx - bot_half + 4, bot_y - 4),
		]), Color(0.32, 0.18, 0.10, 1))
	# Rim.
	_stage_view.draw_colored_polygon(PackedVector2Array([
		Vector2(cx - top_half - 4, rim_y - 4),
		Vector2(cx + top_half + 4, rim_y - 4),
		Vector2(cx + top_half, rim_y + 4),
		Vector2(cx - top_half, rim_y + 4),
	]), Color(0.65, 0.62, 0.58, 1))
	# Yeast cloud floating on top after pitching.
	if _yeast_pitched:
		var cloud_y: float = rim_y + 12
		var cloud_alpha: float = clampf((_t - (TRANSFER_DURATION_SEC + 0.5)) * 0.6, 0.0, 1.0)
		_stage_view.draw_circle(Vector2(cx - 14, cloud_y), 8, Color(0.92, 0.86, 0.72, 0.6 + cloud_alpha * 0.3))
		_stage_view.draw_circle(Vector2(cx, cloud_y - 2), 10, Color(0.92, 0.86, 0.72, 0.7 + cloud_alpha * 0.2))
		_stage_view.draw_circle(Vector2(cx + 12, cloud_y + 2), 7, Color(0.92, 0.86, 0.72, 0.6 + cloud_alpha * 0.3))

func _draw_siphon(sz: Vector2) -> void:
	# Auto-siphon between kettle (left) and fermenter (right).
	var kettle_x: float = sz.x * 0.30
	var fermenter_x: float = sz.x * 0.72
	var kettle_top: float = sz.y * 0.62 - 100
	var fermenter_top: float = sz.y * 0.85 - 130
	# Tube as polyline arching above counter.
	var pts := PackedVector2Array()
	var p0 := Vector2(kettle_x + 30, kettle_top + 20)
	var p2 := Vector2(fermenter_x - 30, fermenter_top + 20)
	var p1 := Vector2((p0.x + p2.x) * 0.5, kettle_top - 30)
	for i in range(13):
		var t: float = float(i) / 12.0
		var a: Vector2 = p0.lerp(p1, t)
		var b: Vector2 = p1.lerp(p2, t)
		pts.append(a.lerp(b, t))
	# Tube color depends on whether transfer is active.
	var col: Color = Color(0.65, 0.62, 0.58, 1) if _transfer_started else Color(0.45, 0.42, 0.38, 0.7)
	_stage_view.draw_polyline(pts, col, 5.0, true)
	# Active flow visualization: dark wort visible inside the tube.
	if _transfer_started and not _transfer_done:
		_stage_view.draw_polyline(pts, Color(0.32, 0.18, 0.10, 0.85), 3.0, true)
	# If not started, pulse a "tap me" hint near the tube.
	if not _transfer_started:
		var hint_t: float = sin(_t * 4.0) * 0.5 + 0.5
		_stage_view.draw_circle(p1 + Vector2(0, -10), 6 + hint_t * 4, Color(Palette.BRASS_LIGHT.r, Palette.BRASS_LIGHT.g, Palette.BRASS_LIGHT.b, 0.5))

func _draw_yeast_packet(sz: Vector2) -> void:
	# Yeast packet sits on the counter between kettle and fermenter.
	var px: float = sz.x * 0.50
	var py: float = sz.y * 0.66
	var w: float = 36.0
	var h: float = 48.0
	var ready: bool = _transfer_done and not _yeast_pitched
	var col: Color = Color(0.85, 0.45, 0.25, 1)
	if _yeast_pitched:
		col = Color(0.42, 0.22, 0.12, 0.5)
	elif ready:
		# Glow when ready.
		var pulse: float = 0.5 + 0.5 * sin(_t * 6.0)
		col = Color(0.95, 0.55, 0.32, 0.8 + pulse * 0.2)
	# Packet body.
	_stage_view.draw_rect(Rect2(px - w * 0.5, py - h * 0.5, w, h), col)
	# Foil top.
	_stage_view.draw_rect(Rect2(px - w * 0.5, py - h * 0.5, w, 6), Color(0.92, 0.88, 0.72, col.a))
	# "YEAST" label band.
	_stage_view.draw_rect(Rect2(px - w * 0.5 + 4, py + 4, w - 8, 8), Color(0.18, 0.10, 0.05, col.a))

func _draw_funnel(sz: Vector2) -> void:
	# Funnel sits next to the fermenter — tap before transfer to count
	# as sanitized.
	var fx: float = sz.x * 0.60
	var fy: float = sz.y * 0.66
	var sanitized: bool = _options.has("sanitize_funnel") and _options["sanitize_funnel"].button_pressed
	var col: Color = Color(0.55, 0.65, 0.72, 1) if sanitized else Color(0.45, 0.50, 0.55, 1)
	# Funnel cone shape.
	_stage_view.draw_colored_polygon(PackedVector2Array([
		Vector2(fx - 16, fy - 16),
		Vector2(fx + 16, fy - 16),
		Vector2(fx + 4, fy + 8),
		Vector2(fx - 4, fy + 8),
	]), col)
	_stage_view.draw_rect(Rect2(fx - 4, fy + 8, 8, 14), col)

func _position_hotspots(sz: Vector2) -> void:
	# Siphon button: covers tube area mid-air.
	_siphon_button.position = Vector2(sz.x * 0.50 - 50, sz.y * 0.30)
	_siphon_button.size = Vector2(100, 80)
	# Yeast packet button.
	_yeast_button.position = Vector2(sz.x * 0.50 - 24, sz.y * 0.66 - 30)
	_yeast_button.size = Vector2(48, 60)
	# Funnel button.
	_funnel_button.position = Vector2(sz.x * 0.60 - 22, sz.y * 0.66 - 22)
	_funnel_button.size = Vector2(44, 56)

# ---- Existing test-contract helpers (preserved) ----

func _render_pour_radios() -> void:
	for child in _pour_group.get_children():
		child.queue_free()
	_pour_radios.clear()
	_add_radio(_pour_group, _pour_radios, "gentle", "Pour gently", true,
		func(id): _selected_pour = id)
	_add_radio(_pour_group, _pour_radios, "fast", "Pour fast", false,
		func(id): _selected_pour = id)

func _render_pitch_radios() -> void:
	for child in _pitch_group.get_children():
		child.queue_free()
	_pitch_radios.clear()
	_add_radio(_pitch_group, _pitch_radios, "sprinkle", "Sprinkle dry yeast", true,
		func(id): _selected_pitch = id)
	_add_radio(_pitch_group, _pitch_radios, "rehydrate", "Rehydrate first", false,
		func(id): _selected_pitch = id)

func _add_radio(parent: VBoxContainer, group: Dictionary, id: String, label: String, default: bool, on_select: Callable) -> void:
	var box := CheckBox.new()
	box.text = label
	box.button_pressed = default
	box.toggled.connect(func(pressed):
		if not pressed:
			box.button_pressed = true
			return
		for sib_id in group:
			if sib_id != id:
				group[sib_id].set_pressed_no_signal(false)
		on_select.call(id)
	)
	parent.add_child(box)
	group[id] = box

func _render_options() -> void:
	for child in _options_group.get_children():
		child.queue_free()
	_options.clear()
	_add_option("even_sprinkle", "Even sprinkle")
	_add_option("stir_once", "Stir once before pitch")
	_add_option("sanitize_funnel", "Sanitize the funnel")

func _add_option(id: String, label: String) -> void:
	var box := CheckBox.new()
	box.text = label
	_options_group.add_child(box)
	_options[id] = box

func _on_confirm_pressed() -> void:
	var taken: Array = []
	for id in _options:
		if _options[id].button_pressed:
			taken.append(id)
	var care: float = CareFactor.from_breadth(taken.size(), _options.size())
	var risk: Dictionary = {}
	if _selected_pour == "fast":
		risk["oxidation"] = 2.0
	if _selected_pitch == "sprinkle" and not taken.has("even_sprinkle"):
		risk["infection"] = 1.0
	if not taken.has("sanitize_funnel"):
		risk["infection"] = float(risk.get("infection", 0.0)) + 0.5
	var skills: Dictionary = GameState.data.get("skills", {})
	var notes: Array = [_journal_summary(taken)]
	var outcome := {
		"actual": {
			"pour_quality": _selected_pour,
			"pitch_method": _selected_pitch,
			"actions_taken": taken,
		},
		"care_factor": care,
		"risk_deltas": risk,
		"xp_gained": {
			"sanitation": 6 if taken.has("sanitize_funnel") else 3,
			"process":    8 if _selected_pitch == "rehydrate" else 5,
		},
		"journal_notes": notes,
		"skill_snapshot": SkillXP.snapshot(skills),
	}
	minigame_completed.emit(outcome)

func _journal_summary(taken: Array) -> String:
	var pour_label := "smooth" if _selected_pour == "gentle" else "splashy"
	var pitch_label := "sprinkled dry yeast" if _selected_pitch == "sprinkle" else "rehydrated yeast first"
	var extras := ""
	if not taken.is_empty():
		extras = " (also: %s)" % ", ".join(taken)
	return "Transferred with a %s pour, %s%s." % [pour_label, pitch_label, extras]
