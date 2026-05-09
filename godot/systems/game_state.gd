extends Node

## GameState — the fat state autoload per DESIGN.md 7.1.
##
## Holds the entire persistent player tree as a Dictionary that maps 1:1
## to Section 8.1's twelve entity groups. SaveService is the only thing
## that reads/writes this to disk.
##
## Cross-references inside the tree are by ID — equipment_used: [uuid]
## resolves against equipment.owned[uuid]. No dangling pointers.
##
## Eleven of the twelve entity groups live here; the brewing journal
## (entity #8) is its own JSONL file held by SaveService.

signal day_advanced(new_day: int)        ## Re-emitted from TimeService after we sync our cached day.
signal state_loaded                       ## Fires after SaveService loads us from disk (or initializes us fresh).

const SAVE_FORMAT_VERSION := 1

var data: Dictionary = {}                 ## The whole tree. Initialized via reset_to_new_career().

func _ready() -> void:
	TimeService.day_advanced.connect(_on_day_advanced)

func reset_to_new_career(destination_id: String = "home_town") -> void:
	## Initial-state factory for a brand-new career. SaveService calls this when
	## no save file exists. Numbers are placeholders to be tuned in playtest.
	data = {
		"player_meta": {
			"save_format_version": SAVE_FORMAT_VERSION,
			"prestige_count": 0,
			"current_destination_id": destination_id,
			"settings": {
				"audio_master": 1.0,
				"audio_sfx": 1.0,
				"audio_music": 1.0,
				"haptic_enabled": true,
				"reduce_motion": false,
			},
		},
		"cash": {
			"balance": 30,                # Per Appendix A: $30 startup capital
			"outstanding_loans": [],
			"customer_advances": [],
			"recurring_bills": [],
		},
		"skills": _initial_skills(),
		"equipment": {
			"owned": {},                  # Filled by the first-brew bootstrap (TBD)
		},
		"inventory": {
			"ingredients": {},
			"bottles": {"available": 24, "in_use": 0},  # Per 4.2: starter kit
			"consumables": {},
		},
		"recipe_knowledge": {
			"known": {},
			"invented": [],
			"pinned_for_prestige": "",
		},
		"brews_in_flight": [],
		"npcs": {},
		"calendar": {
			"open_commitments": [],
			"closed_commitments": [],
		},
		"phone_world": {
			"forum": {"threads_seen": [], "threads_posted": [], "threads_mentioned_in": []},
			"news": {"articles_seen": [], "current_trends": []},
			"social": {"follower_count": 0, "posts": []},
			"shop": {"last_browsed_items": [], "items_unlocked": []},
			"regional_water_profile_id": "default",
		},
		"rng_state": {
			"world_anomaly_seed": randi(),
			"next_brew_seed": randi(),
		},
	}
	# Sync the day clock — fresh career starts at day 0.
	TimeService.day_clock = 0
	state_loaded.emit()

func adopt(loaded_data: Dictionary) -> void:
	## Called by SaveService.load() with the deserialized tree. Replaces our
	## current state. Caller is responsible for migration before adopt.
	data = loaded_data
	# Sync the day clock from the save's record. The save format doesn't store
	# day_clock directly today — it's implicit in brew/calendar state — so we
	# default to 0. When a v2 save format adds it, change here.
	TimeService.day_clock = 0
	state_loaded.emit()

func _initial_skills() -> Dictionary:
	# Six axes per 3.4. All start at level 0; water_chem stays unlocked=false
	# until the player owns a pH meter (per 3.4 + 8.6).
	return {
		"sanitation":   {"level": 0, "xp": 0, "xp_to_next": 100, "unlocked": true},
		"temp_control": {"level": 0, "xp": 0, "xp_to_next": 100, "unlocked": true},
		"timing":       {"level": 0, "xp": 0, "xp_to_next": 100, "unlocked": true},
		"process":      {"level": 0, "xp": 0, "xp_to_next": 100, "unlocked": true},
		"palate":       {"level": 0, "xp": 0, "xp_to_next": 100, "unlocked": true},
		"water_chem":   {"level": 0, "xp": 0, "xp_to_next": 100, "unlocked": false},
	}

func _on_day_advanced(new_day: int) -> void:
	day_advanced.emit(new_day)
