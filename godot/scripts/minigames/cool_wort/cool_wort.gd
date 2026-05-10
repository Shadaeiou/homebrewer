extends Control

## Cool the wort — real-time mini-game.
##
## Kettle is in a sink basin. Cold water faucet above. Three ice bags
## on the side. Spoon for stirring. Thermometer shows wort temp
## dropping from boiling (210°F) toward pitching (70°F).
##
## The internal state fields used by the existing sim tests
## (_selected_path, _path_radios, _option_toggles, _on_path_toggled,
## _on_confirm_pressed) are preserved, so test_cool_wort.* still pass
## by setting fields directly. In gameplay, those fields are driven
## by the player's interactions.

signal minigame_completed(outcome: Dictionary)

const PATH_ICE_BATH := "ice_bath"
const PATH_TOP_OFF := "top_off"

const STARTING_TEMP_F: float = 210.0
const TARGET_TEMP_F: float = 70.0
const FAUCET_COOLING_RATE: float = 1.4    # °F/sec while faucet running
const STIR_MULTIPLIER: float = 1.6
const ICE_DROP_F: float = 14.0            # instant drop per ice bag
const ICE_BAGS_AVAILABLE: int = 3

@onready var _stage_title: Label = %StageTitle
@onready var _path_group: VBoxContainer = %PathGroup
@onready var _options_group: VBoxContainer = %OptionsGroup
@onready var _readout: Label = %Readout
@onready var _confirm_button: Button = %ConfirmButton
@onready var _stage_view: Control = %StageView
@onready var _faucet_button: Button = %FaucetButton
@onready var _spoon_button: Button = %SpoonButton
@onready var _ice_button: Button = %IceButton

var _stage_meta: Dictionary = {}
var _selected_path: String = PATH_ICE_BATH
var _option_toggles: Dictionary = {}
var _path_radios: Dictionary = {}
var _temp_f: float = STARTING_TEMP_F
var _faucet_on: bool = false
var _stirring: bool = false
var _ice_used: int = 0
var _resolved: bool = false
var _t: float = 0.0
var _splash_t: float = 0.0
var _ice_anim: Array = []  # active ice-bag drop animations

func _ready() -> void:
	set_process(true)
	_confirm_button.visible = false
	_render_path_options()
	_render_options_for_path()
	# Pre-mark "monitor" as taken — just being in the close-up means
	# you can see the thermometer. "ice" and "stir" require the player
	# to actually use them.
	if _option_toggles.has("monitor"):
		_option_toggles["monitor"].button_pressed = true
	if _stage_view != null:
		_stage_view.draw.connect(_draw_stage)
		_stage_view.resized.connect(_stage_view.queue_redraw)
	_faucet_button.pressed.connect(_on_faucet_pressed)
	_spoon_button.button_down.connect(_on_spoon_down)
	_spoon_button.button_up.connect(_on_spoon_up)
	_ice_button.pressed.connect(_on_ice_pressed)

func set_stage_meta(stage: Dictionary) -> void:
	_stage_meta = stage

func _process(delta: float) -> void:
	if _resolved:
		return
	_t += delta
	# Cool wort over time when faucet is on.
	if _faucet_on and _temp_f > TARGET_TEMP_F:
		var rate: float = FAUCET_COOLING_RATE
		if _stirring:
			rate *= STIR_MULTIPLIER
		_temp_f = max(TARGET_TEMP_F, _temp_f - rate * delta)
	elif _stirring and _temp_f > TARGET_TEMP_F + 5.0:
		# Stirring without faucet: very slight passive cooling.
		_temp_f = max(TARGET_TEMP_F, _temp_f - 0.4 * delta)
	if _faucet_on:
		_splash_t += delta
	# Auto-resolve once at or below target.
	if _temp_f <= TARGET_TEMP_F:
		_resolve()
		return
	# Tick ice animations.
	var alive: Array = []
	for a in _ice_anim:
		a["t"] += delta
		if a["t"] < 0.8:
			alive.append(a)
	_ice_anim = alive
	_stage_view.queue_redraw()

func _on_faucet_pressed() -> void:
	if _resolved:
		return
	_faucet_on = not _faucet_on
	# Faucet running implies ice-bath path with cooling water.
	if _faucet_on and _option_toggles.has("ice"):
		_option_toggles["ice"].button_pressed = true

func _on_spoon_down() -> void:
	_stirring = true
	if _option_toggles.has("stir"):
		_option_toggles["stir"].button_pressed = true

func _on_spoon_up() -> void:
	_stirring = false

func _on_ice_pressed() -> void:
	if _resolved or _ice_used >= ICE_BAGS_AVAILABLE:
		return
	_ice_used += 1
	_temp_f = max(TARGET_TEMP_F, _temp_f - ICE_DROP_F)
	_ice_anim.append({"t": 0.0})
	if _option_toggles.has("ice"):
		_option_toggles["ice"].button_pressed = true

# ---- Drawing ----

func _draw_stage() -> void:
	var sz: Vector2 = _stage_view.size
	if sz.x <= 0:
		return
	_stage_view.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.06, 0.06, 0.08, 1))
	_draw_progress_bar(sz)
	_draw_thermometer(sz)
	_draw_basin_with_kettle(sz)
	_draw_faucet(sz)
	_draw_ice_shelf(sz)
	_draw_spoon(sz)
	_position_hotspots(sz)

func _draw_progress_bar(sz: Vector2) -> void:
	var w: float = sz.x - 80
	var x: float = 40
	var y: float = 18
	_stage_view.draw_rect(Rect2(x, y, w, 6), Color(0.16, 0.14, 0.12, 1))
	var prog: float = clampf(
		(STARTING_TEMP_F - _temp_f) / (STARTING_TEMP_F - TARGET_TEMP_F),
		0.0, 1.0,
	)
	_stage_view.draw_rect(Rect2(x, y, w * prog, 6), Palette.GRADE_A)

func _draw_thermometer(sz: Vector2) -> void:
	var x: float = sz.x - 64
	var y_top: float = sz.y * 0.18
	var y_bot: float = sz.y * 0.78
	var height: float = y_bot - y_top
	_stage_view.draw_rect(Rect2(x, y_top, 14, height), Color(0.18, 0.16, 0.14, 1))
	var range_min: float = 70.0
	var range_max: float = 220.0
	var fill_frac: float = clampf((_temp_f - range_min) / (range_max - range_min), 0.0, 1.0)
	var fill_y: float = y_bot - height * fill_frac
	var col: Color = Color(0.35, 0.55, 0.78, 1).lerp(Color(0.85, 0.32, 0.22, 1), fill_frac)
	_stage_view.draw_rect(Rect2(x + 2, fill_y, 10, y_bot - fill_y), col)
	_stage_view.draw_circle(Vector2(x + 7, y_bot + 6), 9, col)
	# Tick at 70°F (target).
	var t_target: float = (TARGET_TEMP_F - range_min) / (range_max - range_min)
	var ty: float = y_bot - height * t_target
	_stage_view.draw_line(Vector2(x - 8, ty), Vector2(x + 18, ty), Palette.GRADE_A, 2.0, true)
	_stage_view.draw_rect(Rect2(x, y_top, 14, height), Color(0, 0, 0, 0.6), false, 1.0)
	# Numeric readout above thermometer.
	_stage_view.draw_string(
		ThemeDB.fallback_font, Vector2(x - 16, y_top - 8),
		"%d°F" % int(round(_temp_f)),
		HORIZONTAL_ALIGNMENT_CENTER, 60, 16,
		Color(0.95, 0.91, 0.84, 1),
	)

func _draw_basin_with_kettle(sz: Vector2) -> void:
	# Sink basin spans the centered lower-half of the screen.
	var basin_cx: float = sz.x * 0.45
	var basin_top: float = sz.y * 0.50
	var basin_w: float = 280.0
	var basin_h: float = 140.0
	var basin_rect := Rect2(basin_cx - basin_w * 0.5, basin_top, basin_w, basin_h)
	# Stainless rim.
	_stage_view.draw_rect(basin_rect, Palette.METAL_MID)
	# Recessed bowl.
	var bowl := basin_rect.grow(-8.0)
	_stage_view.draw_rect(bowl, Color(0.10, 0.09, 0.08, 1))
	_stage_view.draw_rect(bowl, Color(0, 0, 0, 0.65), false, 1.0)
	# Cold water in basin (visible when faucet on).
	if _faucet_on:
		var water_h: float = 54.0
		var water_rect := Rect2(bowl.position + Vector2(0, bowl.size.y - water_h),
			Vector2(bowl.size.x, water_h))
		_stage_view.draw_rect(water_rect, Color(0.32, 0.50, 0.72, 0.85))
		# Surface ripple.
		var samples: int = 16
		var top_pts := PackedVector2Array()
		for i in range(samples + 1):
			var f: float = float(i) / float(samples)
			var sx: float = water_rect.position.x + water_rect.size.x * f
			var phase: float = f * PI * 4.0
			var sy: float = water_rect.position.y + sin(_splash_t * 6.0 + phase) * 1.5
			top_pts.append(Vector2(sx, sy))
		_stage_view.draw_polyline(top_pts, Color(0.55, 0.78, 0.92, 1), 1.5, true)
	# Kettle inside the basin.
	var kettle_cx: float = basin_cx
	var kettle_bot: float = basin_rect.position.y + basin_rect.size.y - 12
	var top_half: float = 70.0
	var bot_half: float = 60.0
	var kettle_h: float = 110.0
	var rim_y: float = kettle_bot - kettle_h
	# Body (cross-section).
	var wall_t: float = 6.0
	_stage_view.draw_colored_polygon(PackedVector2Array([
		Vector2(kettle_cx - top_half, rim_y),
		Vector2(kettle_cx - top_half + wall_t, rim_y),
		Vector2(kettle_cx - bot_half + wall_t, kettle_bot - wall_t),
		Vector2(kettle_cx + bot_half - wall_t, kettle_bot - wall_t),
		Vector2(kettle_cx + bot_half, kettle_bot),
		Vector2(kettle_cx - bot_half, kettle_bot),
	]), Palette.METAL_MID)
	# Inside.
	_stage_view.draw_colored_polygon(PackedVector2Array([
		Vector2(kettle_cx - top_half + wall_t, rim_y + 6),
		Vector2(kettle_cx + top_half - 3, rim_y + 6),
		Vector2(kettle_cx + bot_half - 3, kettle_bot - wall_t),
		Vector2(kettle_cx - bot_half + wall_t, kettle_bot - wall_t),
	]), Color(0.06, 0.06, 0.06, 1))
	# Wort inside — color shifts with temperature (hot=brighter, cool=darker).
	var heat: float = clampf((_temp_f - TARGET_TEMP_F) / (STARTING_TEMP_F - TARGET_TEMP_F), 0.0, 1.0)
	var wort: Color = Color(0.32, 0.18, 0.10, 1).lerp(Color(0.42, 0.24, 0.14, 1), heat)
	var wort_top_y: float = rim_y + 14
	# Stirring causes swirl in the wort surface.
	var stir_amp: float = 4.0 if _stirring else 1.0
	var samples: int = 18
	var top_pts: Array = []
	for i in range(samples + 1):
		var f: float = float(i) / float(samples)
		var sx: float = kettle_cx + lerpf(-(top_half - wall_t - 2), top_half - wall_t - 2, f)
		var phase: float = f * PI * (4.0 if _stirring else 2.0)
		var sy: float = wort_top_y + sin(_t * (8.0 if _stirring else 2.0) + phase) * stir_amp
		top_pts.append(Vector2(sx, sy))
	var poly := PackedVector2Array()
	for i in range(top_pts.size() - 1, -1, -1):
		poly.append(top_pts[i])
	poly.append(Vector2(kettle_cx - (bot_half - wall_t - 2), kettle_bot - wall_t))
	poly.append(Vector2(kettle_cx + (bot_half - wall_t - 2), kettle_bot - wall_t))
	_stage_view.draw_colored_polygon(poly, wort)
	# Steam if hot.
	if _temp_f > 100.0:
		for i in range(3):
			var phase: float = fmod(_t * 0.6 + i * 0.33, 1.0)
			var alpha: float = (1.0 - phase) * 0.4 * heat
			_stage_view.draw_circle(
				Vector2(kettle_cx + (i - 1) * 8.0 + sin(_t + i) * 4, wort_top_y - phase * 50.0),
				4.0 + phase * 5.0,
				Color(0.85, 0.88, 0.92, alpha),
			)
	# Rim band.
	_stage_view.draw_colored_polygon(PackedVector2Array([
		Vector2(kettle_cx - top_half - 2, rim_y - 2),
		Vector2(kettle_cx + top_half + 2, rim_y - 2),
		Vector2(kettle_cx + top_half, rim_y + 6),
		Vector2(kettle_cx - top_half, rim_y + 6),
	]), Palette.METAL_LIGHT)
	# Ice cube animations.
	for a in _ice_anim:
		var t: float = a["t"]
		var x: float = kettle_cx + sin(t * 6.0) * 3
		var y: float = lerpf(basin_rect.position.y - 30.0, wort_top_y, t / 0.8)
		_stage_view.draw_rect(Rect2(x - 6, y - 4, 12, 8), Color(0.92, 0.96, 0.98, 1.0 - t * 0.7))

func _draw_faucet(sz: Vector2) -> void:
	# Faucet hangs above the basin.
	var basin_cx: float = sz.x * 0.45
	var spout_y: float = sz.y * 0.42
	var riser_top: float = sz.y * 0.18
	# Riser.
	_stage_view.draw_rect(Rect2(basin_cx - 4, riser_top, 8, spout_y - riser_top - 14), Palette.BRASS_MID)
	# Arch.
	var arch_pts := PackedVector2Array()
	var p0 := Vector2(basin_cx, spout_y - 14)
	var p1 := Vector2(basin_cx + 18, spout_y - 30)
	var p2 := Vector2(basin_cx, spout_y)
	for i in range(13):
		var t: float = float(i) / 12.0
		var a: Vector2 = p0.lerp(p1, t)
		var b: Vector2 = p1.lerp(p2, t)
		arch_pts.append(a.lerp(b, t))
	_stage_view.draw_polyline(arch_pts, Palette.BRASS_DARK, 8.0, true)
	_stage_view.draw_polyline(arch_pts, Palette.BRASS_MID, 5.0, true)
	# Spout tip.
	_stage_view.draw_rect(Rect2(basin_cx - 5, spout_y - 4, 10, 8), Palette.BRASS_DARK)
	# Stream when on.
	if _faucet_on:
		var basin_top: float = sz.y * 0.50
		var stream_top: Vector2 = Vector2(basin_cx, spout_y + 4)
		var stream_bot: Vector2 = Vector2(basin_cx, basin_top + 12)
		_stage_view.draw_rect(
			Rect2(stream_top.x - 3, stream_top.y, 6, stream_bot.y - stream_top.y),
			Palette.WATER_MID,
		)

func _draw_ice_shelf(sz: Vector2) -> void:
	# Three ice bags stacked on a side shelf.
	var shelf_x: float = sz.x - 110
	var shelf_y: float = sz.y * 0.55
	for i in range(ICE_BAGS_AVAILABLE):
		var bag_y: float = shelf_y + i * 28
		var used: bool = i < _ice_used
		var col: Color = Color(0.85, 0.92, 0.96, 0.9) if not used else Color(0.32, 0.40, 0.48, 0.5)
		_stage_view.draw_rect(Rect2(shelf_x, bag_y, 36, 24), col)
		# Label hint.
		_stage_view.draw_rect(Rect2(shelf_x + 10, bag_y + 8, 16, 8), Color(0.65, 0.75, 0.82, col.a))

func _draw_spoon(sz: Vector2) -> void:
	# Spoon with handle visible at the top of the basin.
	var sx: float = sz.x * 0.20
	var sy: float = sz.y * 0.55
	var handle_color: Color = Color(0.55, 0.42, 0.28, 1)
	if _stirring:
		handle_color = Color(0.78, 0.55, 0.32, 1)
	# Handle (vertical).
	_stage_view.draw_rect(Rect2(sx - 4, sy - 80, 8, 80), handle_color)
	# Spoon bowl at the bottom.
	_stage_view.draw_circle(Vector2(sx, sy + 4), 10, Color(0.62, 0.48, 0.32, 1))
	_stage_view.draw_circle(Vector2(sx + 1, sy + 5), 6, Color(0.42, 0.32, 0.22, 1))

func _position_hotspots(sz: Vector2) -> void:
	# Faucet button: covers the spout area.
	var basin_cx: float = sz.x * 0.45
	_faucet_button.position = Vector2(basin_cx - 30, sz.y * 0.32)
	_faucet_button.size = Vector2(60, 60)
	# Ice button: stack of ice bags.
	_ice_button.position = Vector2(sz.x - 116, sz.y * 0.50)
	_ice_button.size = Vector2(48, 100)
	# Spoon button: on the spoon.
	var sx: float = sz.x * 0.20
	var sy: float = sz.y * 0.55
	_spoon_button.position = Vector2(sx - 24, sy - 90)
	_spoon_button.size = Vector2(48, 110)

# ---- Existing test-contract helpers (preserved) ----

func _render_path_options() -> void:
	for child in _path_group.get_children():
		child.queue_free()
	_path_radios.clear()
	_add_path(PATH_ICE_BATH, "Ice bath", true)
	_add_path(PATH_TOP_OFF, "Top-off cooling", false)

func _add_path(id: String, label: String, default: bool) -> void:
	var box := CheckBox.new()
	box.text = label
	box.button_pressed = default
	box.toggled.connect(func(pressed): _on_path_toggled(id, box, pressed))
	_path_group.add_child(box)
	_path_radios[id] = box

func _on_path_toggled(id: String, btn: CheckBox, pressed: bool) -> void:
	if not pressed:
		btn.button_pressed = true
		return
	for sib_id in _path_radios:
		if sib_id != id:
			_path_radios[sib_id].set_pressed_no_signal(false)
	_selected_path = id
	_render_options_for_path()

func _render_options_for_path() -> void:
	for child in _options_group.get_children():
		child.queue_free()
	_option_toggles.clear()
	if _selected_path == PATH_ICE_BATH:
		_add_option("ice", "Buy ice ($2)", true)
		_add_option("stir", "Stir occasionally", true)
		_add_option("monitor", "Monitor temp with thermometer", true)
	else:
		_add_option("boil_topoff", "Boil top-off water first", true)
		_add_option("bottled_topoff", "Use bottled water", _has_bottled_water())

func _add_option(id: String, label: String, owned: bool) -> void:
	var box := CheckBox.new()
	box.text = label
	if not owned:
		box.disabled = true
	_options_group.add_child(box)
	_option_toggles[id] = box

func _has_bottled_water() -> bool:
	var ing: Dictionary = GameState.data.get("inventory", {}).get("ingredients", {})
	return ing.has("water_spring") or ing.has("water_bottled")

func _resolve() -> void:
	_resolved = true
	_on_confirm_pressed()

func _on_confirm_pressed() -> void:
	var available: int = 0
	for id in _option_toggles:
		if not _option_toggles[id].disabled:
			available += 1
	var taken_ids: Array = []
	for id in _option_toggles:
		var box: CheckBox = _option_toggles[id]
		if box.button_pressed and not box.disabled:
			taken_ids.append(id)
	var care: float = CareFactor.from_breadth(taken_ids.size(), max(1, available))
	var final_temp: float = _projected_final_temp(care)
	var risk: Dictionary = {}
	if _selected_path == PATH_ICE_BATH:
		var missed_protection: int = 3 - taken_ids.size()
		if missed_protection > 0:
			risk["infection"] = float(missed_protection) * 0.7
	else:
		var protection_taken: bool = taken_ids.has("boil_topoff") or taken_ids.has("bottled_topoff")
		if not protection_taken:
			risk["infection"] = 2.5
		if final_temp >= 78.0:
			risk["off_flavor_temp"] = 1.0
	var skills: Dictionary = GameState.data.get("skills", {})
	var notes: Array = [_journal_summary(taken_ids, final_temp)]
	var outcome := {
		"actual": {
			"path": _selected_path,
			"actions_taken": taken_ids,
			"final_temp_f": final_temp,
		},
		"care_factor": care,
		"risk_deltas": risk,
		"xp_gained": {
			"temp_control": 8 if _selected_path == PATH_ICE_BATH else 4,
			"sanitation": 3 if _selected_path == PATH_ICE_BATH else 2,
		},
		"journal_notes": notes,
		"skill_snapshot": SkillXP.snapshot(skills),
	}
	minigame_completed.emit(outcome)

func _projected_final_temp(care: float) -> float:
	var base: float = 70.0 if _selected_path == PATH_ICE_BATH else 80.0
	var slop: float = (1.0 - care) * 6.0
	return base + slop

func _journal_summary(taken: Array, final_temp: float) -> String:
	var path_label: String = "ice bath" if _selected_path == PATH_ICE_BATH else "top-off cooling"
	if taken.is_empty():
		return "Cooled via %s with no extra care. Final temp ~%d°F." % [path_label, int(round(final_temp))]
	return "Cooled via %s (%s). Final temp ~%d°F." % [path_label, ", ".join(taken), int(round(final_temp))]
