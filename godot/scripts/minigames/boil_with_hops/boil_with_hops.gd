extends Control

## Boil + hops — real-time mini-game.
##
## Player is at the stove during a (compressed) 60-minute boil. Three
## hop bags on the counter glow at their drop windows: bittering at
## 60 min, flavor at 15 min, aroma at flame-out. Player taps each
## bag during its window to drop it in. Boil-over event mid-way:
## foam climbs, must tap the dial to lower heat. Flame-out at the
## end: must tap dial to OFF.
##
## Internal state fields (_heat, _boilover, _attention_toggle, etc.)
## are preserved so the existing outcome math + sim tests keep working.

signal minigame_completed(outcome: Dictionary)

const TOTAL_BOIL_SEC: float = 28.0  # 60 real-world minutes compressed
const HOP_WINDOW_SEC: float = 4.0   # tap window for each hop drop

# Hop drop times (seconds into the boil).
const T_HOP_BITTER: float = 2.0
const T_HOP_FLAVOR: float = 14.0
const T_HOP_AROMA: float = 25.5
const T_BOILOVER_START: float = 8.0
const T_BOILOVER_END: float = 12.0
const T_FLAMEOUT_PROMPT: float = 27.5

@onready var _stage_title: Label = %StageTitle
@onready var _attention_toggle: CheckBox = %AttentionToggle
@onready var _hops_toggle: CheckBox = %HopsToggle
@onready var _flameout_toggle: CheckBox = %FlameoutToggle
@onready var _confirm_button: Button = %ConfirmButton
@onready var _stage_view: Control = %StageView
@onready var _dial_button: Button = %DialButton
@onready var _hop1_button: Button = %Hop1Button
@onready var _hop2_button: Button = %Hop2Button
@onready var _hop3_button: Button = %Hop3Button

var _stage_meta: Dictionary = {}
var _heat: String = "HIGH"
# Defaults match the test contract — assume "ideal" until the player
# fails an interaction. The mini-game flips these to bad values when
# they miss a hop window, ignore a boil-over, etc.
var _boilover: String = "lower_heat"
var _t: float = 0.0
var _resolved: bool = false
var _hop_dropped: Array = [false, false, false]  # bitter/flavor/aroma
var _hop_dropped_in_window: Array = [false, false, false]
var _flame_out_tapped: bool = false  # Set true once player taps dial OFF after the flameout prompt.
var _foam_height: float = 0.0  # 0..1 visual foam level
var _bubble_phase: float = 0.0
var _boilover_engaged: bool = false  # Did player respond to boil-over event?

# Hop drop animation: per-hop, time since drop or null.
var _hop_drop_anim: Array = [null, null, null]

func _ready() -> void:
	set_process(true)
	# Hide the legacy radio groups; we drive _heat/_boilover via taps.
	if has_node("HiddenForLogic"):
		$HiddenForLogic.visible = false
	# Default toggles match the test contract — start "ideal" and the
	# mini-game's events flip them off if the player fumbles.
	_attention_toggle.button_pressed = true
	_hops_toggle.button_pressed = true
	_flameout_toggle.button_pressed = true
	_confirm_button.visible = false  # no manual confirm button — auto-resolves
	_dial_button.pressed.connect(_on_dial_tapped)
	_hop1_button.pressed.connect(func(): _drop_hop(0))
	_hop2_button.pressed.connect(func(): _drop_hop(1))
	_hop3_button.pressed.connect(func(): _drop_hop(2))
	_stage_view.draw.connect(_draw_stage)
	_stage_view.resized.connect(_stage_view.queue_redraw)

func set_stage_meta(stage: Dictionary) -> void:
	_stage_meta = stage
	if _stage_title != null:
		_stage_title.text = String(stage.get("title", "Boil with hops"))

func _process(delta: float) -> void:
	if _resolved:
		return
	_t += delta
	_bubble_phase += delta * 6.0
	# Foam grows during boil-over event; depends on heat.
	var target_foam: float = 0.0
	if _t >= T_BOILOVER_START and _t < T_BOILOVER_END:
		# Boil-over event in progress: foam climbs unless heat is low.
		match _heat:
			"HIGH": target_foam = 1.0
			"MED":  target_foam = 0.55
			"LOW":  target_foam = 0.25
	else:
		target_foam = 0.30 if _heat == "HIGH" else (0.18 if _heat == "MED" else 0.08)
	_foam_height = lerpf(_foam_height, target_foam, clampf(delta * 1.5, 0.0, 1.0))

	# Tick hop drop animations.
	for i in range(3):
		if _hop_drop_anim[i] != null:
			_hop_drop_anim[i] += delta
			if _hop_drop_anim[i] > 1.0:
				_hop_drop_anim[i] = null

	# Just after the boil-over event ends, lock in the response.
	if _t >= T_BOILOVER_END and not _boilover_engaged:
		_boilover_engaged = true
		if _heat == "HIGH":
			# Player ignored the boil-over event — heat never came down.
			_boilover = "ignore"
			_attention_toggle.button_pressed = false

	# After total boil time, resolve.
	if _t >= TOTAL_BOIL_SEC:
		# Hops toggle = true ONLY if all three were dropped within window.
		var all_in_window: bool = (
			_hop_dropped_in_window[0] and
			_hop_dropped_in_window[1] and
			_hop_dropped_in_window[2]
		)
		if not all_in_window:
			_hops_toggle.button_pressed = false
		# Flameout: did player tap dial OFF after the prompt?
		if not _flame_out_tapped:
			_flameout_toggle.button_pressed = false
		_resolve()
		return
	_stage_view.queue_redraw()

func _on_dial_tapped() -> void:
	if _resolved:
		return
	# Cycle heat: HIGH → MED → LOW → OFF (special) → HIGH.
	# OFF only valid after T_FLAMEOUT_PROMPT.
	match _heat:
		"HIGH": _heat = "MED"
		"MED":  _heat = "LOW"
		"LOW":
			# Past flameout prompt? Then OFF locks in flame_out.
			if _t >= T_FLAMEOUT_PROMPT:
				_heat = "OFF"
				_flame_out_tapped = true
			else:
				_heat = "HIGH"
		"OFF":  _heat = "HIGH"
	# If during a boil-over event, lowering to MED/LOW counts as response.
	if _t >= T_BOILOVER_START and _t < T_BOILOVER_END:
		if _heat == "MED" or _heat == "LOW":
			_boilover = "lower_heat"
			_attention_toggle.button_pressed = true

func _drop_hop(idx: int) -> void:
	if _resolved or _hop_dropped[idx]:
		return
	_hop_dropped[idx] = true
	# Was the drop within the window?
	var window_centers: Array = [T_HOP_BITTER, T_HOP_FLAVOR, T_HOP_AROMA]
	var center: float = window_centers[idx]
	var in_window: bool = abs(_t - center) <= HOP_WINDOW_SEC * 0.5
	_hop_dropped_in_window[idx] = in_window
	_hop_drop_anim[idx] = 0.0  # start animation

# ---- Drawing ----

func _draw_stage() -> void:
	var sz: Vector2 = _stage_view.size
	if sz.x <= 0:
		return
	# Backdrop.
	_stage_view.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.06, 0.06, 0.08, 1))
	_draw_timer_bar(sz)
	_draw_kettle_with_boil(sz)
	_draw_dial(sz)
	_draw_hop_bags(sz)
	_position_hotspots(sz)

func _draw_timer_bar(sz: Vector2) -> void:
	var w: float = sz.x - 80
	var x: float = 40
	var y: float = 18
	_stage_view.draw_rect(Rect2(x, y, w, 6), Color(0.16, 0.14, 0.12, 1))
	var prog: float = clampf(_t / TOTAL_BOIL_SEC, 0.0, 1.0)
	_stage_view.draw_rect(Rect2(x, y, w * prog, 6), Palette.GRADE_A)
	# Hop windows highlighted on the bar.
	var window_centers: Array = [T_HOP_BITTER, T_HOP_FLAVOR, T_HOP_AROMA]
	for i in range(3):
		var center_t: float = window_centers[i]
		var win_x: float = x + w * (center_t / TOTAL_BOIL_SEC)
		var win_w: float = w * (HOP_WINDOW_SEC / TOTAL_BOIL_SEC)
		_stage_view.draw_rect(
			Rect2(win_x - win_w * 0.5, y - 2, win_w, 10),
			Color(Palette.BRASS_LIGHT.r, Palette.BRASS_LIGHT.g, Palette.BRASS_LIGHT.b, 0.3),
		)

func _draw_kettle_with_boil(sz: Vector2) -> void:
	var cx: float = sz.x * 0.5
	var burner_y: float = sz.y * 0.62
	var top_half: float = 100.0
	var bot_half: float = 84.0
	var kettle_h: float = 150.0
	var rim_y: float = burner_y - kettle_h
	# Burner glow.
	if _heat != "OFF":
		var heat_intensity: float = {"HIGH": 1.0, "MED": 0.65, "LOW": 0.35, "OFF": 0.0}[_heat]
		_stage_view.draw_circle(
			Vector2(cx, burner_y + 8), 50,
			Color(0.95, 0.55, 0.18, heat_intensity * 0.7),
		)
	# Drop shadow.
	_stage_view.draw_colored_polygon(PackedVector2Array([
		Vector2(cx - bot_half + 8, burner_y + 2),
		Vector2(cx + bot_half + 12, burner_y + 2),
		Vector2(cx + bot_half + 18, burner_y + 12),
		Vector2(cx - bot_half + 14, burner_y + 12),
	]), Color(0, 0, 0, 0.55))
	# Outer body silhouette.
	_stage_view.draw_polyline(PackedVector2Array([
		Vector2(cx - top_half, rim_y),
		Vector2(cx + top_half, rim_y),
		Vector2(cx + bot_half, burner_y),
		Vector2(cx - bot_half, burner_y),
		Vector2(cx - top_half, rim_y),
	]), Color(Palette.METAL_OUTLINE.r, Palette.METAL_OUTLINE.g, Palette.METAL_OUTLINE.b, 0.6), 1.5, true)
	# Cutaway left wall.
	var wall_t: float = 6.0
	_stage_view.draw_colored_polygon(PackedVector2Array([
		Vector2(cx - top_half, rim_y),
		Vector2(cx - top_half + wall_t, rim_y),
		Vector2(cx - bot_half + wall_t, burner_y - wall_t),
		Vector2(cx + bot_half - wall_t, burner_y - wall_t),
		Vector2(cx + bot_half, burner_y),
		Vector2(cx - bot_half, burner_y),
	]), Palette.METAL_MID)
	# Inside dark.
	_stage_view.draw_colored_polygon(PackedVector2Array([
		Vector2(cx - top_half + wall_t, rim_y + 8),
		Vector2(cx + top_half - 3, rim_y + 8),
		Vector2(cx + bot_half - 3, burner_y - wall_t),
		Vector2(cx - bot_half + wall_t, burner_y - wall_t),
	]), Color(0.06, 0.06, 0.06, 1))
	# Wort: brown when boiling.
	var inside_top: float = rim_y + 12
	var inside_bot: float = burner_y - wall_t
	# Foam height (visible above the wort) climbs during boil-over.
	var wort_top_y: float = inside_top + 30 - _foam_height * 30
	var wort_color: Color = Color(0.32, 0.18, 0.10, 1)
	# Wort polygon.
	var wort_top_pts: Array = []
	var samples: int = 18
	for i in range(samples + 1):
		var f: float = float(i) / float(samples)
		var sx: float = cx + lerpf(-(top_half - wall_t - 2), top_half - wall_t - 2, f)
		var phase: float = f * PI * 4.0
		var amp: float = 1.5 + _foam_height * 4.0
		var sy: float = wort_top_y + sin(_bubble_phase * 0.8 + phase) * amp
		wort_top_pts.append(Vector2(sx, sy))
	var poly := PackedVector2Array()
	for i in range(wort_top_pts.size() - 1, -1, -1):
		poly.append(wort_top_pts[i])
	poly.append(Vector2(cx - (bot_half - wall_t - 2), inside_bot))
	poly.append(Vector2(cx + (bot_half - wall_t - 2), inside_bot))
	_stage_view.draw_colored_polygon(poly, wort_color)
	_stage_view.draw_polyline(PackedVector2Array(wort_top_pts), Color(0.55, 0.32, 0.18, 1), 1.5, true)
	# Bubbles.
	if _heat != "OFF" and _t > 1.5:
		_draw_bubbles(cx, wort_top_y, top_half - wall_t - 4)
	# Foam — visible band above wort during boil-over.
	if _foam_height > 0.15:
		var foam_top_y: float = wort_top_y - _foam_height * 28.0
		var foam_pts := PackedVector2Array()
		for p in wort_top_pts:
			foam_pts.append(Vector2(p.x, foam_top_y))
		var foam_poly := PackedVector2Array()
		for p in foam_pts:
			foam_poly.append(p)
		for i in range(wort_top_pts.size() - 1, -1, -1):
			foam_poly.append(wort_top_pts[i])
		_stage_view.draw_colored_polygon(foam_poly, Color(0.92, 0.86, 0.72, 0.8))
		# Boil-over warning.
		if _foam_height > 0.7:
			_stage_view.draw_string(
				ThemeDB.fallback_font, Vector2(cx - 70, rim_y - 10),
				"BOIL OVER!",
				HORIZONTAL_ALIGNMENT_CENTER, 140,
				16, Color(0.95, 0.32, 0.22, 1),
			)
	# Hop drop animations: each animates a bag falling into kettle.
	for i in range(3):
		if _hop_drop_anim[i] != null:
			var t: float = _hop_drop_anim[i]
			var hop_x: float = cx + (i - 1) * 20
			var hop_y: float = lerpf(rim_y - 60.0, wort_top_y, t)
			_stage_view.draw_circle(Vector2(hop_x, hop_y), 6, Color(0.42, 0.62, 0.32, 1 - t * 0.5))
	# Rim.
	_stage_view.draw_colored_polygon(PackedVector2Array([
		Vector2(cx - top_half - 2, rim_y - 2),
		Vector2(cx + top_half + 2, rim_y - 2),
		Vector2(cx + top_half, rim_y + 6),
		Vector2(cx - top_half, rim_y + 6),
	]), Palette.METAL_LIGHT)

func _draw_bubbles(cx: float, surface_y: float, half_w: float) -> void:
	var n: int = {"HIGH": 8, "MED": 5, "LOW": 2, "OFF": 0}[_heat]
	for i in range(n):
		var phase: float = fmod(_bubble_phase * 0.4 + i * 0.18, 1.0)
		var bx: float = cx + sin(i * 11.7 + _bubble_phase * 0.3) * half_w * 0.75
		var by: float = surface_y - phase * 5.0 + 2.0
		var r: float = 1.5 + sin(_bubble_phase + i) * 0.5
		var alpha: float = (1.0 - phase) * 0.85
		_stage_view.draw_circle(Vector2(bx, by), r, Color(1, 1, 1, alpha))

func _draw_dial(sz: Vector2) -> void:
	# Dial positioned to the right of the kettle.
	var cx: float = sz.x * 0.85
	var cy: float = sz.y * 0.62
	var r: float = 28.0
	_stage_view.draw_circle(Vector2(cx + 1, cy + 2), r, Color(0, 0, 0, 0.55))
	_stage_view.draw_circle(Vector2(cx, cy), r, Palette.METAL_DARK)
	_stage_view.draw_circle(Vector2(cx, cy), r - 3, Palette.METAL_MID)
	# Pointer angle by heat setting.
	var angle_by_heat: Dictionary = {
		"OFF": -PI / 2.0, "HIGH": PI, "MED": PI / 2.0, "LOW": 0.0,
	}
	var ang: float = angle_by_heat[_heat]
	var tip: Vector2 = Vector2(cx, cy) + Vector2(cos(ang), sin(ang)) * (r - 6)
	_stage_view.draw_line(Vector2(cx, cy), tip, Palette.BRASS_LIGHT, 3.0, true)
	_stage_view.draw_circle(Vector2(cx, cy), 4, Palette.BRASS_DARK)
	# Heat label below.
	_stage_view.draw_string(
		ThemeDB.fallback_font, Vector2(cx - 30, cy + r + 18),
		_heat,
		HORIZONTAL_ALIGNMENT_CENTER, 60, 14,
		Color(0.85, 0.78, 0.70, 1),
	)

func _draw_hop_bags(sz: Vector2) -> void:
	# Three hop bags on the bottom shelf. Glow when in window.
	var window_centers: Array = [T_HOP_BITTER, T_HOP_FLAVOR, T_HOP_AROMA]
	var labels: Array = ["60'", "15'", "0'"]
	var bag_y: float = sz.y - 80
	for i in range(3):
		var bag_x: float = sz.x * 0.20 + i * (sz.x * 0.20)
		var center_t: float = window_centers[i]
		var in_window: bool = abs(_t - center_t) <= HOP_WINDOW_SEC * 0.5
		var dropped: bool = _hop_dropped[i]
		var bag_color: Color = Color(0.26, 0.32, 0.20, 1)
		if dropped:
			bag_color = Color(0.18, 0.22, 0.14, 0.5)
		elif in_window:
			# Pulse highlight.
			var pulse: float = 0.5 + 0.5 * sin(_t * 8.0)
			bag_color = Color(0.55, 0.78, 0.42, 0.6 + pulse * 0.4)
		# Bag body.
		_stage_view.draw_rect(
			Rect2(bag_x - 22, bag_y - 28, 44, 36),
			bag_color,
		)
		# Tie at top.
		_stage_view.draw_rect(
			Rect2(bag_x - 8, bag_y - 36, 16, 8),
			Color(0.62, 0.55, 0.28, bag_color.a),
		)
		# Label.
		_stage_view.draw_string(
			ThemeDB.fallback_font, Vector2(bag_x - 16, bag_y + 22),
			labels[i],
			HORIZONTAL_ALIGNMENT_CENTER, 32, 12,
			Color(0.85, 0.78, 0.70, 1),
		)

func _position_hotspots(sz: Vector2) -> void:
	# Dial.
	_dial_button.position = Vector2(sz.x * 0.85 - 36, sz.y * 0.62 - 36)
	_dial_button.size = Vector2(72, 72)
	# Hop bags.
	for i in range(3):
		var bag_x: float = sz.x * 0.20 + i * (sz.x * 0.20)
		var bag_y: float = sz.y - 80
		var btn: Button = [_hop1_button, _hop2_button, _hop3_button][i]
		btn.position = Vector2(bag_x - 30, bag_y - 40)
		btn.size = Vector2(60, 70)

# ---- Outcome (existing math, preserved for tests) ----

func _resolve() -> void:
	_resolved = true
	_on_confirm_pressed()

func _on_confirm_pressed() -> void:
	var ibu_factor: float = 1.0
	if _heat == "LOW":
		ibu_factor *= 0.85
	if not _attention_toggle.button_pressed:
		ibu_factor *= 0.94
	if not _hops_toggle.button_pressed:
		ibu_factor *= 0.85
	var volume_loss: float = 0.0
	var risk: Dictionary = {}
	match _boilover:
		"ignore":
			volume_loss += 0.65
			risk["boil_over"] = 5.0
		"skim":
			volume_loss += 0.20
			risk["boil_over"] = 1.5
		"blow":
			volume_loss += 0.40
			risk["boil_over"] = 2.5
		"lower_heat":
			pass
	if not _flameout_toggle.button_pressed:
		ibu_factor *= 1.08
		volume_loss += 0.30
		risk["recipe_drift"] = float(risk.get("recipe_drift", 0.0)) + 1.0
	var taken: int = 0
	if _attention_toggle.button_pressed:
		taken += 1
	if _flameout_toggle.button_pressed:
		taken += 1
	var care: float = CareFactor.from_breadth(taken, 2)
	var skills: Dictionary = GameState.data.get("skills", {})
	var notes: Array = [_journal_summary(ibu_factor, volume_loss)]
	var outcome := {
		"actual": {
			"heat":              _heat,
			"watched_for_break": _attention_toggle.button_pressed,
			"hops_on_schedule":  _hops_toggle.button_pressed,
			"boilover_response": _boilover,
			"prompt_flameout":   _flameout_toggle.button_pressed,
			"ibu_factor":        ibu_factor,
			"volume_loss_gal":   volume_loss,
		},
		"care_factor": care,
		"risk_deltas": risk,
		"xp_gained": {"timing": 8, "temp_control": 5, "process": 3},
		"journal_notes": notes,
		"skill_snapshot": SkillXP.snapshot(skills),
	}
	minigame_completed.emit(outcome)

func _journal_summary(ibu_factor: float, volume_loss: float) -> String:
	var bits: Array = []
	bits.append("Burner %s." % _heat)
	bits.append("IBU factor %.2f." % ibu_factor)
	if volume_loss > 0.05:
		bits.append("Volume loss ~%.2f gal." % volume_loss)
	if _boilover == "ignore":
		bits.append("Boil-over went unmanaged.")
	if not _flameout_toggle.button_pressed:
		bits.append("Forgot flameout — let it over-boil.")
	return " ".join(bits)
