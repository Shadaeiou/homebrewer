extends Node

## Recipe presets. Phase-1 single recipe — Basic Pale Ale. More land here
## later as recipe variety becomes player-progression.
##
## A recipe is a Dictionary so it serializes trivially (save/load later) and
## doesn't drag a class hierarchy along. Field shape stays consistent:
##   id              short stable identifier
##   name            display name
##   style           e.g. "American Pale Ale"
##   target_volume_l litres of finished beer
##   target_og       expected original gravity (1.040–1.080 typical)
##   target_fg       expected final gravity
##   target_ibu      bitterness target
##   target_srm      color target (Standard Reference Method)
##   target_abv      expected ABV
##   mash_temp_c     ideal mash temperature
##   mash_minutes    ideal mash duration
##   boil_minutes    boil duration
##   hop_additions   [{minutes_remaining, grams, alpha_pct, role}]
##   yeast_attenuation expected fermentation efficiency (0.0–1.0)
##   pitch_temp_c    target temp when yeast goes in
##   ferment_temp_c  ideal fermentation temperature
##   ferment_days    fermentation duration
##   condition_days  bottle conditioning duration

const PALE_ALE := {
	"id": "pale_ale_basic",
	"name": "Basic Pale Ale",
	"style": "American Pale Ale",
	"target_volume_l": 4.0,
	"target_og": 1.050,
	"target_fg": 1.012,
	"target_ibu": 35.0,
	"target_srm": 8.0,
	"target_abv": 5.0,
	"mash_temp_c": 65.0,
	"mash_minutes": 60.0,
	"boil_minutes": 60.0,
	"hop_additions": [
		{"minutes_remaining": 60, "grams": 14, "alpha_pct": 6.0, "role": "bittering"},
		{"minutes_remaining": 15, "grams": 14, "alpha_pct": 6.0, "role": "flavor"},
		{"minutes_remaining": 5, "grams": 14, "alpha_pct": 6.0, "role": "aroma"},
	],
	"yeast_attenuation": 0.75,
	"pitch_temp_c": 20.0,
	"ferment_temp_c": 19.0,
	"ferment_days": 10.0,
	"condition_days": 14.0,
}

func default_recipe() -> Dictionary:
	return PALE_ALE.duplicate(true)
