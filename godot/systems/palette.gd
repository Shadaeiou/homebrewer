extends Node

## Single source of truth for every color the game draws.
##
## Rules:
##   1. NO ad-hoc Color() literals in gameplay code. Reference these constants.
##   2. New colors get added here, not inlined.
##   3. Procedural rendering and UI both pull from this palette so generated
##      sprites and code-drawn shapes look like they're from the same world.
##
## Family naming:
##   BG_*       — backgrounds, walls, counters
##   METAL_*    — stainless / iron (kettles, equipment bodies)
##   BRASS_*    — brass / copper highlights, fittings
##   WOOD_*     — wood (paddles, handles, counters)
##   WATER_*    — clear water
##   WORT_*     — unfermented brew (golden-amber)
##   BEER_*     — finished beer (deep amber/copper)
##   FOAM_*     — beer / boil foam
##   FLAME_*    — fire colors
##   STEAM_*    — steam / vapor
##   GRADE_*    — score/feedback colors (A green, F red, etc.)
##   TEXT_*     — typography
##   GLASS_*    — bottle/jar glass

# Backgrounds (warm, slightly desaturated to recede)
const BG_DEEP := Color("#1A130E")
const BG_MID := Color("#241A12")
const BG_WARM := Color("#2D2118")
const BG_COUNTER := Color("#3D2B1F")

# Metal — three core shades + a hot specular highlight
const METAL_DARK := Color("#2E3134")
const METAL_MID := Color("#56595D")
const METAL_LIGHT := Color("#8C9094")
const METAL_SHINE := Color("#C8CBCE")
const METAL_OUTLINE := Color("#0E1012")

# Brass / copper accents (faucets, fittings, badges)
const BRASS_DARK := Color("#5A4318")
const BRASS_MID := Color("#8B6F2E")
const BRASS_LIGHT := Color("#C09A40")
const BRASS_SHINE := Color("#E8C76A")

# Wood (paddles, racks, counters)
const WOOD_DARK := Color("#3F2614")
const WOOD_MID := Color("#6B4528")
const WOOD_LIGHT := Color("#9B6B3D")
const WOOD_GRAIN := Color("#5A3A1F")

# Water — five steps so we can fake gradients without shader work
const WATER_DEEP := Color("#1F4A78")
const WATER_MID := Color("#3A7DB5")
const WATER_LIGHT := Color("#74B0D9")
const WATER_HIGHLIGHT := Color("#E0F0FA")
const WATER_MENISCUS := Color("#B5DCF0")

# Wort (during mash and boil)
const WORT_DEEP := Color("#5A3A14")
const WORT_MID := Color("#A86C2A")
const WORT_LIGHT := Color("#D6A04A")
const WORT_HIGHLIGHT := Color("#F0D080")

# Finished beer
const BEER_DEEP := Color("#3D1F08")
const BEER_MID := Color("#7B3F14")
const BEER_LIGHT := Color("#C76A2A")
const BEER_HEAD := Color("#F0E0B8")

# Foam (boil/krausen)
const FOAM_DARK := Color("#D4C696")
const FOAM_MID := Color("#E8DDB0")
const FOAM_LIGHT := Color("#F8F0D6")

# Fire
const FLAME_DEEP := Color("#6B1A0A")
const FLAME_MID := Color("#D6451E")
const FLAME_HOT := Color("#F08A2C")
const FLAME_TIP := Color("#F5C739")

# Steam / vapor
const STEAM_LOW := Color("#D8D0C0", 0.18)
const STEAM_MID := Color("#E8E0CF", 0.30)
const STEAM_HIGH := Color("#F4ECDB", 0.55)

# Grade colors for results
const GRADE_S := Color("#74E0F0")  # A+ — cyan, "perfect"
const GRADE_A := Color("#8FE85F")
const GRADE_B := Color("#E8DC55")
const GRADE_C := Color("#F0A838")
const GRADE_D := Color("#E86E2C")
const GRADE_F := Color("#D63E2C")

# UI / Text
const TEXT_PRIMARY := Color("#F2E8D5")
const TEXT_SECONDARY := Color("#B8A98C")
const TEXT_DIM := Color("#8A7E66")
const ACCENT := Color("#F0C540")  # Homebrewer brand gold (titles, badges)
const ACCENT_DIM := Color("#A88828")
const DIVIDER := Color("#3D2B1F")

# Glass (bottles, hydrometers)
const GLASS_DEEP := Color("#1F2820", 0.35)
const GLASS_MID := Color("#3A4A40", 0.30)
const GLASS_HIGHLIGHT := Color("#C8E0D4", 0.55)
