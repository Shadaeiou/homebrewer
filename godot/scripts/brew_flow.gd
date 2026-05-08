extends Control

## Main brewing flow controller. Shows the stage list with the current stage
## highlighted; for stages with a real mini-game, "Start" hands off to that
## scene. For placeholder stages, "Continue" simulates an ideal outcome.
##
## Lives across mini-game navigation because BrewSession (autoload) holds
## the active brew state. When the player returns from fill_kettle, we
## detect the recorded outcome and update the UI to the next stage.

@onready var recipe_label: Label = %RecipeLabel
@onready var stage_list: VBoxContainer = %StageList
@onready var current_card: PanelContainer = %CurrentCard
@onready var current_label: Label = %CurrentLabel
@onready var current_description: Label = %CurrentDescription
@onready var primary_button: Button = %PrimaryButton
@onready var abandon_button: Button = %AbandonButton
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_grade: Label = %ResultGrade
@onready var result_summary: Label = %ResultSummary
@onready var result_back_button: Button = %ResultBackButton

func _ready() -> void:
	# Start a new brew the first time we land here. If we're returning from
	# a mini-game, BrewSession.active is already true and we just pick up.
	if not BrewSession.active:
		BrewSession.start(Recipes.default_recipe())

	recipe_label.text = "Recipe: %s · target %.1f L · ~%.1f%% ABV" % [
		BrewSession.recipe.get("name", ""),
		BrewSession.recipe.get("target_volume_l", 0.0),
		BrewSession.recipe.get("target_abv", 0.0),
	]

	BrewSession.stage_changed.connect(_on_stage_changed)
	BrewSession.brew_completed.connect(_on_brew_completed)

	primary_button.pressed.connect(_on_primary_pressed)
	abandon_button.pressed.connect(_on_abandon_pressed)
	result_back_button.pressed.connect(_on_result_back_pressed)

	_render_stage_list()
	_render_current()

	if BrewSession.is_complete():
		_show_result(BrewSession.final_grade, BrewSession.final_summary)

func _render_stage_list() -> void:
	for child in stage_list.get_children():
		child.queue_free()

	for i in range(BrewSession.STAGES.size()):
		var stage_def: Dictionary = BrewSession.STAGES[i]
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var marker := Label.new()
		marker.custom_minimum_size = Vector2(28, 0)
		marker.add_theme_font_size_override("font_size", 16)
		var done := i < BrewSession.stage_index
		var current := i == BrewSession.stage_index
		if done:
			marker.text = "✓"
			marker.modulate = Palette.GRADE_A
		elif current:
			marker.text = "▶"
			marker.modulate = Palette.ACCENT
		else:
			marker.text = "·"
			marker.modulate = Palette.TEXT_DIM
		row.add_child(marker)

		var name_label := Label.new()
		name_label.text = stage_def.get("label", "")
		name_label.add_theme_font_size_override("font_size", 14)
		if done:
			name_label.modulate = Palette.TEXT_SECONDARY
		elif current:
			name_label.add_theme_color_override("font_color", Palette.ACCENT)
			name_label.add_theme_font_size_override("font_size", 16)
		else:
			name_label.modulate = Palette.TEXT_DIM
		name_label.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(name_label)

		# Right column: stage outcome grade if completed
		if done:
			var sid: String = stage_def.get("id", "")
			var outcome_grade: String = BrewSession.outcomes.get(sid, {}).get("grade", "")
			if outcome_grade != "":
				var grade_label := Label.new()
				grade_label.text = outcome_grade
				grade_label.add_theme_font_size_override("font_size", 14)
				grade_label.modulate = _grade_color(outcome_grade)
				row.add_child(grade_label)

		stage_list.add_child(row)

func _render_current() -> void:
	if BrewSession.is_complete():
		current_card.visible = false
		return

	current_card.visible = true
	var stage_def: Dictionary = BrewSession.current_stage()
	current_label.text = "Stage %d / %d · %s" % [
		BrewSession.stage_index + 1,
		BrewSession.STAGES.size(),
		stage_def.get("label", ""),
	]
	current_description.text = stage_def.get("description", "")

	var minigame: String = stage_def.get("minigame", "")
	if minigame != "":
		primary_button.text = "Start"
	else:
		primary_button.text = "Continue (ideal outcome — placeholder)"

func _on_primary_pressed() -> void:
	var minigame: String = BrewSession.current_minigame_path()
	if minigame != "":
		get_tree().change_scene_to_file(minigame)
	else:
		BrewSession.record_ideal_outcome()

func _on_stage_changed(_idx: int) -> void:
	_render_stage_list()
	_render_current()

func _on_brew_completed(grade: String) -> void:
	_render_stage_list()
	_render_current()
	_show_result(grade, BrewSession.final_summary)

func _show_result(grade: String, summary: String) -> void:
	result_panel.visible = true
	result_grade.text = grade
	result_grade.modulate = _grade_color(grade)
	result_summary.text = summary

func _on_result_back_pressed() -> void:
	BrewSession.reset()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_abandon_pressed() -> void:
	BrewSession.reset()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _grade_color(grade: String) -> Color:
	match grade:
		"A+": return Palette.GRADE_S
		"A": return Palette.GRADE_A
		"B": return Palette.GRADE_B
		"C": return Palette.GRADE_C
		"D": return Palette.GRADE_D
		_: return Palette.GRADE_F
