# Homebrewer — Design

The canonical game design document. Internal only — not shipped to the player.

This is the **first pass**: Sections 0–3 plus Appendices A and B. Sections 4–9 (Time & Equipment Constraints, Economy, UX/UI, Technical Architecture, Save Schema, Mini-Game Build Plan) are the next pass. When a section locks, it stays locked unless the design explicitly revisits it. When implementation starts, this document is the spec; if the spec is wrong, fix the spec, then fix the code.

`CLAUDE.md` continues to define repo rules (commit to main, every player-visible commit bumps `changelog.json`, etc.). This document defines what the game **is**.

---

## How to read this

- **Section 0** — the elevator pitch and the five tenets that everything else respects.
- **Section 1** — the world, who's in it, the phone interface that ties social/customer/news/shopping together.
- **Section 2** — what one career looks like across decades of in-game time, and what prestige carries forward when you start over.
- **Section 3** — the brewing simulation. The outcome model, the equipment-as-properties model, the care system, skill axes, the risk profile, the discovery principle, the three v1 styles, the twelve v1 mini-games and their consequences.
- **Appendix A** — the first brewing day, narrated step by step with concrete failure modes for each step. The canonical worked example. If anything in Section 3 contradicts Appendix A, Appendix A wins; fix Section 3.
- **Appendix B** — the five days of the first brew's fermentation period, with the daily checklist + discovery UX shown moment by moment. Validates the daily rhythm.

---

## Section 0 — Vision

You started brewing because a friend invited you to a party and you wanted to bring something better than a six-pack of the same lager everyone else brings. You ripped a recipe out of a magazine, your friend's parents lent you thirty bucks for ingredients, and you set up your kettle on a kitchen stove. Years later — across thousands of in-game days — you're a world-renowned brewer with a brewery in three cities. You got there one batch at a time, paying attention.

**Homebrewer is a brewing simulation that is shockingly faithful to how real beer is made.** The mash temperature matters; the timing of hop additions matters; whether you sanitized the auto-siphon matters; whether you noticed your apartment got cold overnight matters. It is not a clicker; it is not an idle game; it is a craft simulation.

It is also a phone game. Sessions are 2–10 minutes. Time only passes when the app is open. Active brewing scenes are compressed (a 60-minute boil takes about 3 minutes of real time); fermentation periods are walked through as in-game days, one tap at a time. There is no real-world clock running while the app is closed. Everything happens at your pace.

### The five tenets

1. **Real homebrewing as the spec.** A real brewer should play this and recognize their craft. Style guidelines, process steps, equipment options, water chemistry — all faithful to the activity. Where realism conflicts with mobile-game cadence, mobile-game wins for *durations* but never for *rules*.

2. **Outcomes from your choices.** Every mini-game produces specific, traceable consequences. Pour LME without turning off the burner: you get burnt-extract twang in the finished beer. Skip sanitation: infection probability climbs. The grade at the end is the *summary* of what you did, not a roll of the dice.

3. **Equipment is a perception and control surface.** A kettle without volume markings means you're eyeballing. A stove with HIGH/MED/LOW means you can't dial in a precise temperature. A bucket fermenter without a thermotape means you can't see your fermentation temp without intrusion. Upgrades change what you can know and what you can control.

4. **The game discloses nothing it shouldn't.** Anomalies happen whether or not you check. The game does not pop up "⚠ Your fermenter is cold" in the morning summary. It says "It's cold this morning" — an ambient cue. The player who decides to go check finds out. The player who doesn't, doesn't.

5. **One save, one career, prestige to start over.** A career runs from apartment-brewer to world-renowned. When you finish (or want to start over), prestige resets the world but carries a small bag of accumulated knowledge with you. Multiple parallel saves are not supported; the friction of "should I start over" is by design.

---

## Section 1 — World, Lore, Phone Interface

### 1.1 Setting

Modern day. Your apartment. Your phone. A real-feeling town that has a few breweries you've heard of and a homebrew supply store you can order from online. This is the **first destination**.

Later, after enough success, you can prestige to a different destination — Portland, Munich, Tokyo, or another canonical brewing capital — with different culture, different palate expectations, and different style demand. v1 ships with the first destination only; subsequent destinations are content updates that extend the prestige loop indefinitely.

The town is never depicted as a map or a navigable space. The world exists through your phone. You don't drive to Marcus's house; you text him. You don't visit the brewing supply shop; you order from it. This is intentional and modern and keeps the scope tight.

### 1.2 Player Character

The player has no avatar at v1. No name is shown; NPCs simply text and refer to you in second person ("you"). No customization screen.

Why: the player is *who is holding the phone*. You're playing yourself trying to brew good beer. Adding an avatar adds a customization surface and a personality wedge between the player and the world. We don't need that.

### 1.3 NPCs at apartment scale

Five named NPCs are present from game start. Each has a personality, a style preference, and a narrative role.

| Name | Role | Style preference | Personality |
|---|---|---|---|
| **Marcus** | Best friend. Got you into this. Throws the parties. | Hop-forward (IPAs, pale ales) | Excitable, doesn't get brewing science, hypes you to others |
| **Mom** | Provides emotional and small financial support. | Easy-drinking (pale ales, cream ales) | Worries, asks if you're eating, occasionally orders from you |
| **Dad** | Doesn't text often. Birthday stout becomes the first big customer order. | Dark + malty (stouts, porters) | Quiet, encouraging |
| **Cara** | Younger sister. Doesn't really like beer but supports you. | None — drinks whatever's there | Sardonic, low-investment, occasional honesty bombs |
| **Tim** | Met at Marcus's party. Brewing-club guy. | Sophisticated, style-correct | Picky palate, knowledgeable, becomes your gateway to the brewing community |

NPCs are never seen — no portraits, no scenes. They exist entirely through text messages, social media activity, news/journal mentions, and email orders. This is consistent with the modern phone-driven world model.

Additional NPCs unlock as the player progresses (local bar owner, brewing club members, judges at competitions, eventually brewery employees). Each unlock comes with a clear narrative beat.

### 1.4 Phone Interface

The phone is the central UI surface. **Always accessible** from the dashboard via a phone icon at the bottom of the screen. Tapping opens an overlay shaped like a phone screen with apps:

- **Messages** — text threads with NPCs. Replies are choice-based (pick from 2–3 options). Each conversation can affect relationship meters; choices have small consequences.
- **Social** — your brewery's social-media account. Compose posts about brews (image generated procedurally from the brew's data — bottle render, style tag, color from SRM). Posts can hype upcoming releases and grow followers. Late game: collabs, viral moments, influencers.
- **News** — read-only feed. Trend signals ("Hazy IPAs trending"), competition announcements, supplier promotions, regulatory news. This is the source for opportunities.
- **Email** — formal correspondence. Bulk customer orders with deadlines, competition entry confirmations, supplier invoices, angel-investor offers in bankruptcy moments.
- **Forums** — recipe browsing, brewing-tip reading (Knowledge XP), recipe purchase. Drives recipe collection growth.
- **Shop** — the homebrew supply store. Ingredients, equipment, consumables. Some items unlock only after relevant News articles or Forum threads appear.
- **Calendar** — upcoming events: customer order deadlines, competitions, social commitments. Drives long-term planning.
- **Journal** — your brewing log. Every brew is recorded with its outcomes, ratings, and post-mortem reflections.

The phone is never *modal* in a way that blocks brewing actions. You can pull it up between sub-actions of a mini-game without losing state. (Implementation note: the phone is a `CanvasLayer` overlay above gameplay scenes; gameplay pauses while it's open.)

### 1.5 The brewery journal

Every brew you complete is logged with:
- Recipe used
- Date brewed / bottled / tasted
- Equipment used
- Ingredients used (quantities)
- Outcomes (actual OG, IBU, ABV, FG, color, perceived tasting notes)
- Hidden risk-axis values, *revealed* on the post-mortem
- Final grade
- Tasting notes (what NPCs said, what competitions said)

The journal is browsable. It's the player's history and self-evaluation tool. It also surfaces *what you missed* during the brew — the cold spot you didn't notice on Day 3 of fermentation shows up in the post-mortem along with its consequence ("attenuation 3% lower than recipe target — that cold snap on day 3 stalled the yeast briefly").

This is a teaching mechanism. The journal makes you better.

---

## Section 2 — Player Journey

### 2.1 Save model

**One save per device.** No save list, no parallel breweries, no "do you want to start over" anxiety. The single save IS the player's career.

A "Hard Reset (delete career)" button exists in settings, double-confirmed, for users who genuinely want a clean slate. Multiple parallel careers are achieved by using multiple Google accounts on a device; we don't build parallel-save UX.

When the player chooses to **prestige** (their career has reached a natural endpoint and they want to start over), the world resets but a small portable inventory of accumulated knowledge moves with them.

### 2.2 Progression tiers within a destination

Within one destination (e.g., the home town in v1), progression goes:

- **Apartment kitchen.** Stove, kettle, plastic bucket fermenter, ~24 bottles. Friends-and-family customer base. Low-stakes brewing, learn the basics.
- **Garage / backyard.** Larger kettle, possibly multiple fermenters, more bottles or first kegs, dedicated brewing space (no longer competing with kitchen). Larger customer base, first bulk orders from local bars, first competitions.
- **Pro brewery.** Real stainless equipment, multiple parallel batches, full control over water chemistry, employees (eventually), distribution. Wholesale orders, competition entries, regional renown.

Movement between tiers is voluntary and reversible. You upgrade by accumulating cash and choosing to invest. You can downsize voluntarily (sell equipment, move back to garage scale) if you over-extended. Forced downsize happens via bankruptcy; see 2.6.

### 2.3 Destinations (prestige carry)

After reaching a sufficient win condition in your current destination (see 2.5), you can prestige. The next destination is a new location with:

- Different culture (Munich enforces Reinheitsgebot adherence — barley, water, hops, yeast only; Tokyo demands obsessive sanitation; Portland trends shift faster than anywhere else)
- Different palate expectations (the local market favors different styles)
- Different starting NPCs (you have to build relationships from scratch; old ones text occasionally as long-distance friends)
- Different competitions and unlock paths
- Possibly different style menu (Munich unlocks lagers; Tokyo unlocks rice-based brewing; etc.)

The brewing fundamentals don't change. Your *mastery* carries. The *world* doesn't.

v1 ships with one destination. Subsequent destinations are content updates that extend the prestige loop indefinitely.

### 2.4 What carries forward on prestige

| Carries forward | Does NOT carry forward |
|---|---|
| Skill levels (with a small reset penalty — say, drop 20% to keep early-game challenge) | Cash |
| Recipe knowledge (you remember styles you've mastered, but need to re-brew them once to "prove" it again) | Current equipment |
| One pinned recipe of your choice | In-progress brews (ferment, condition) |
| Achievement / brewery journal of past breweries (read-only memorial) | Customer relationships |
| Modest cash bonus ("you sold the brewery") | Recipe collection |
| One mid-tier piece of equipment chosen at prestige time | Skill-gated unlock state (you have to re-unlock things) |

The penalty is real enough that prestige feels meaningful. The carry-forward is generous enough that re-running the early game isn't a slog. We tune the percentages by feel.

### 2.5 Win state

**A career has no fixed end.** Players choose when to prestige. Suggested triggers:

- Won a Tier-1 major competition (regional)
- Brewery valuation crosses some threshold
- Brewed a beer of every v1 style at A-or-better grade
- Reached a "World Tour" achievement that names you world-renowned

The game can suggest prestige when these are met ("You've reached the natural end of this brewery's story. Want to start a new chapter elsewhere?"), but doesn't force it. A player who wants to keep optimizing in their home town indefinitely is welcome to.

When destinations beyond Tier 2 ship, "world-renowned" becomes "you've prestiged through three or more destinations and won majors in each."

### 2.6 Failure / bankruptcy

Money can run out. The game's response scales with where you are:

- **Apartment scale, broke.** A friend (Marcus) bails you out with a small loan + faith. No equipment lost. Mild story moment via texts. Realistic max loan: $50–100.
- **Garage scale, broke.** A customer (Mom, Marcus, the local bar owner) offers an advance against a bulk order. You owe a delivery by a deadline, scaled to the advance. Adds pressure but no equipment loss.
- **Pro brewery, broke.** An angel investor steps in, but takes a real cost. The player chooses:
  - **Equity:** lower payouts on every future sale until the loan is paid back (with interest)
  - **Forced downsize:** sell your fanciest equipment, possibly move back to garage scale.

**Voluntary downsize anytime.** You can sell equipment and relocate (apartment ↔ garage). Carries a small "moving cost" hit (5–10% of equipment value). Useful when you've over-invested or trends have turned against your gear.

This makes downsize a tool, not just a punishment. The downsize-then-rebuild story arc is intentionally available — pro brewer who made bad decisions retreats to apartment to consolidate, then rebuilds smarter.

### 2.7 Trends (apartment vs. pro)

- **Apartment scale.** NPCs have stable preferences. Marcus likes IPAs; Mom likes pale ales; Dad likes stouts. They drink what they like. A rare event might shift a preference (Cara starts liking sours after seeing a TikTok), but mostly you're brewing for known palates.
- **Garage scale.** Local bar owners, brewing clubs, and your social-media followers introduce a softer trend signal. Some weeks pale ales sell better than IPAs; some weeks the inverse. You're learning to read demand.
- **Pro brewery.** Trends are explicit. Each in-game month, a style trends in the news. Aligned brews sell at a multiplier; off-trend brews sell at a discount. **Trend research** is a thing you spend money on (read industry publications, attend trade shows) to forecast trends earlier than the market.

The trends system pressures you into either (a) adapting your brew schedule to chase trends, (b) becoming so excellent at one specific style that off-trend doesn't matter, or (c) investing in research to anticipate. Three valid play styles.

---

## Section 3 — Brewing Mechanics

### 3.1 The Outcome Model

Every brewing interaction produces a numeric `actual` value (volume poured, mash temp held, time of hop drop, etc.) computed from a `target` plus a `drift`:

```
actual = target + drift

drift = base_drift / (skill_factor × equipment_precision × care_factor) × randn(1.0)
```

Where:
- `base_drift` is a per-interaction tuning constant (e.g., for "fill kettle to 2.5 gal," base_drift = 0.5 gal)
- `skill_factor` ∈ [0.4, 1.0] — relevant skill axis. 0.4 at zero skill, 1.0 at mastery.
- `equipment_precision` ∈ [0.3, 1.0] — derived from equipment properties at this interaction. Unmarked kettle = 0.4; marked kettle = 0.8; in-line flow meter = 1.0.
- `care_factor` ∈ [0.6, 1.0] — emergent from sub-actions taken. See 3.3.
- `randn(1.0)` is a Gaussian random with mean 0 and stddev 1, providing realism (real brewing is always slightly variable).

Multiplicative factors mean: a scrupulous novice with cheap gear (0.4 × 0.5 × 1.0 = 0.20) is *worse* than a lazy expert with great gear (1.0 × 1.0 × 0.6 = 0.60). The same expert being scrupulous (1.0 × 1.0 × 1.0 = 1.0) is essentially perfect.

This is correct. The model captures: tools, skill, and attention substitute for each other to a degree. Mastery + good gear + care converges on perfection.

#### Worked example: filling the kettle to 2.5 gallons

| Player config | skill | equipment | care | drift stddev | Result |
|---|---|---|---|---|---|
| First-time brewer, no markings, lazy | 0.4 | 0.4 (eyeball) | 0.6 | 0.5 / 0.096 = 5.2× base = ±2.6 gal | Wildly off, possibly catastrophic |
| First-time brewer, measuring pitcher, scrupulous | 0.4 | 0.85 (1L pitcher) | 1.0 | 0.5 / 0.34 = 1.5× base = ±0.75 gal | Imprecise but acceptable |
| First-time brewer, bottled spring water jug, lazy | 0.4 | 0.95 (jug w/ printed marks) | 0.6 | 0.5 / 0.23 = 2.2× base = ±1.1 gal | Surprisingly bad — jug helps, but lazy negates it |
| Experienced brewer, no markings, lazy | 1.0 | 0.4 | 0.6 | 0.5 / 0.24 = 2.1× base = ±1.05 gal | Old hand still misses without tools |
| Experienced brewer, measuring pitcher, scrupulous | 1.0 | 0.85 | 1.0 | 0.5 / 0.85 = 0.59× base = ±0.30 gal | Tight |
| Experienced brewer, in-line flow meter, scrupulous | 1.0 | 1.0 | 1.0 | 0.5 / 1.0 = 0.5× base = ±0.25 gal | Effectively perfect |

The numbers are illustrative — final tuning is a balance pass, not a design pass.

#### How drift propagates

Volume drift on the kettle fill propagates: dilute wort → lower OG than recipe target → lower ABV → recipe drift in the final beer. The drift compounds across stages. Bad volume + bad mash + bad pitch can absolutely produce an F-grade beer; one stage's drift on its own usually produces a B or C.

### 3.2 Equipment as Property Bags

Equipment is **never** "tier 1" or "tier 2." Each piece is a typed dictionary of properties, and "upgrades" are specific property flips.

#### Example: the boil kettle

```
Apartment Stockpot (starting kettle):
    volume_capacity_gal: 5
    volume_markings: NONE
    has_thermometer: false
    has_spigot: false
    material: ALUMINUM
    precision_for_volume: 0.4
    precision_for_temp: 0.0  # can't read temp at all
    sanitation_decay_per_use: HIGH
    starting_state: USED  # was your stockpot before; you've cooked pasta in it

Marked Brew Kettle (mid-game):
    volume_capacity_gal: 10
    volume_markings: PRECISE  # liter + gallon etches inside
    has_thermometer: true     # inline probe
    has_spigot: true          # for cleaner transfers
    material: STAINLESS
    precision_for_volume: 0.95
    precision_for_temp: 0.85
    sanitation_decay_per_use: LOW
    starting_state: CLEAN
```

These properties feed into the outcome formulas. `has_thermometer: true` unlocks "watch temp" as an action. `volume_markings: PRECISE` raises `equipment_precision` for volume-related interactions to 0.95.

#### Other equipment property sketches (full schema in Section 4 / Appendix C, future)

- **Stove:** `heat_levels: ENUM(HIGH, MED, LOW)` (apartment) → `heat_levels: ABSOLUTE_C` (electric) → `heat_levels: PROGRAMMABLE` (HERMS-RIMS).
- **Thermometer:** `type: ANALOG_BIMETAL` (slow, ±5°F) → `DIGITAL_PROBE` (fast, ±1°F) → `LAB_GRADE` (instant, ±0.1°F).
- **Hydrometer:** `precision: ±0.005` (cheap) → `precision: ±0.001` (precision) → `Refractometer: needs_temp_correction: false, oxidation_per_use: 0` (eliminates the SG-reading tradeoff).
- **Fermenter:** `transparent: false` (bucket) → `transparent: true` (glass carboy) → `has_temp_port: true` (conical w/ probe). `thermotape_installed: true` flips on after $5 sticker purchase.
- **Capper:** `type: WING` (squeeze, gesture) → `type: BENCH` (lever, more reliable).

A purchase doesn't *replace* the old equipment unless the player chooses; some equipment can coexist (multiple fermenters of different types). Equipment-replacement decisions are explicit: "do you want to sell the old kettle?"

### 3.3 The Care System

Care is **not** a dial. There is no "set your care level for this brew" toggle.

Each interaction has an inventory of sub-actions, some required, some optional. The player takes the actions they choose. The system observes the breadth and computes a `care_factor`.

#### Example: cleaning the bucket fermenter

| Sub-action | Time cost | Consumable | Required? |
|---|---|---|---|
| Rinse with water | 30s | none | required (otherwise: state stays DIRTY, no care factor improvement) |
| Soap-wash with sponge | 90s | dish soap (cheap) | optional |
| Sanitizer soak (Star San) | 60s | Star San | optional, requires Star San owned |
| Drip-dry on rack | 30s | none | optional |

| Actions taken | Care factor | Resulting state |
|---|---|---|
| Skip (don't tap "clean") | 0.0 | STAYS_DIRTY |
| Just rinse | 0.6 | SERVICEABLE |
| Rinse + soap | 0.85 | CLEAN |
| Rinse + soap + sanitizer + drip-dry | 1.0 | SANITIZED |

Care factor and resulting state both feed downstream:
- Care factor → outcome formula for THIS cleaning interaction (you can't really "drift" on cleaning; care goes to risk_profile.infection)
- Resulting state → fermenter's persistent state (decays with use, gates the next brew's starting infection_risk)

#### Why be lazy?

Trade-offs:
- **Time** — scrupulous care takes more in-game minutes (and real-time clicks) per stage
- **Consumables** — each scrupulous action consumes Star San / paper towels / etc.
- **Attention budget** — doing every step every time is exhausting in a long session

Lazy is correct sometimes (low-stakes pale ale for friends). Wrong other times (competition entry). Strategic.

### 3.4 Skill Axes

Six axes. All grow from real-stakes reps only — no practice mode, no XP from drills.

| Skill | Affects | XP source |
|---|---|---|
| **Sanitation** | Infection risk reductions; care factor on cleaning interactions | Successful cleans, sanitized brews without infection events |
| **Temperature Control** | Mash temp hold accuracy; ferment temp anomaly response; cool-stage timing | Mash steps within target, anomaly mitigations |
| **Timing** | Hop drop accuracy; boil duration accuracy; bottling priming sugar steep | Hop additions on schedule, boil duration ±N min |
| **Process** | General execution quality (transfers, pitches, captures); reduces splash/oxidation | Transfers without spillage, pitches with even distribution |
| **Palate** | Tasting accuracy in finished beer; ability to detect off-flavors | Pour-and-taste interactions; comparing tasting notes to actual brew data |
| **Water Chemistry** | Water-treatment effectiveness; recipe-faithfulness for chemistry-sensitive styles | Late unlock — gated by Sanitation reaching mid-tier and at least one all-grain brew completed |

Skill levels grow on a curve: early levels are fast (XP_to_next = 100), late levels are slow (XP_to_next = 10000+). The curve makes early progress feel responsive and late mastery feel earned.

Skill caps achievable outcomes. **At zero skill, A+ outcomes are unachievable even with perfect play.** Your first beer cannot be a competition winner. As skill grows, the achievable ceiling rises. Pro-tier brewing demands mid-to-high skill across multiple axes.

### 3.5 The Risk Profile

Every brew carries a hidden `RiskProfile` that fills up during active stages. Players cannot see exact risk numbers (early game) — they see *qualitative warnings* and learn to read them. With the right equipment + skill, the numbers become legible.

#### Six axes

| Axis | Accrued by | Manifests as |
|---|---|---|
| **Infection** | Skipped/poor sanitation; equipment too long unwashed; bare-hands transfers; no blow-off tube on aggressive ferment; oxygen exposure post-pitch | Sourness, off-flavors, gushing bottles; full ruin (rare) |
| **Oxidation** | Splashy transfers; repeated SG readings; no O2-absorbing caps; slow bottling | Cardboard / sherry off-flavors, faster staling |
| **Off-flavor: temperature** | Boil too hot/cold; fermentation too warm or cool; temp swings; autolysis (left on yeast too long) | Esters, fusel alcohols, diacetyl, sulfur |
| **Boil-over** | Inattention during boil; no heat control | Volume loss → lower OG/IBU; stovetop mess (lore) |
| **Recipe drift** | Missed mash temp; missed boil time; missed hop schedule; wrong pitch temp | OG/IBU/SRM landing wide of recipe target |
| **Measurement uncertainty** | No hydrometer = guessing OG; no thermometer = guessing temp | "Mystery box" beer — you don't know what you made until tasting; wide grade variance |

#### Reveal model

- **During the brew:** the player perceives risks indirectly via skill-gated cues. Low Process skill: "the wort smells weird" (could be a lot of things). High Process skill: "that's a touch of DMS — your boil was gentle."
- **At tasting (Pour & Taste mini-game):** Palate skill gates how many of the actual flavors the player can identify. Low Palate: "tastes like beer." High Palate: "smells of cardboard and slight sourness; the head doesn't hold."
- **In the journal, post-mortem:** all risk axes are revealed numerically + narratively. "Oxidation: 6/10. Cause: splashy transfer at bottling. Effect: cardboard finish in 4 weeks." Teaches the player what they did and didn't do.

### 3.6 Recipe as Target

A recipe is a Dictionary of brewing targets and process parameters:

```
Apartment Pale Ale:
    name: "Apartment Pale Ale"
    style: "American Pale Ale"
    method: EXTRACT
    batch_size_gal: 5
    boil_volume_gal: 2.5
    boil_minutes: 60
    target_og: 1.045
    target_fg: 1.012
    target_ibu: 30
    target_srm: 8
    target_abv: 4.5
    fermentables: [
        { item: "Light Malt Extract (LME)", weight_lb: 6 }
    ]
    hop_schedule: [
        { item: "Cascade", weight_oz: 1.0,  minutes_remaining: 60 },
        { item: "Cascade", weight_oz: 0.5,  minutes_remaining: 15 },
        { item: "Cascade", weight_oz: 0.5,  minutes_remaining: 0  }
    ]
    yeast: { item: "US-05 dry ale", attenuation: 0.75, pitch_temp_c: 20 }
    fermentation_temp_c: 19
    fermentation_days: 5    # this style + fresh dry yeast = fast; later styles take longer
    condition_days: 14
    priming_sugar_oz: 5
```

The recipe is the **truth**. The brewing simulation computes drift between actual outcomes and these targets. Grading is a function of cumulative drift across all axes.

Players can *invent* recipes (late-game unlock), in which case the player's invention IS the target — drift is measured against what they intended.

### 3.7 The Discovery Principle (the daily UX)

The game discloses no problems automatically.

- **Morning summary** is ambient context only. "It's cold this morning." "Loud upstairs neighbors kept you up last night." "The fridge is making a weird noise." It does NOT say "your fermenter is cold."
- **Daily checklist** is a uniform action list — "Check fermenter," "Clean kettle," "Phone (X new)" — never a pre-disclosed warning.
- **Discovery happens via checking.** Tapping "Check fermenter" opens a perception panel listing the methods available given current equipment. Each method has a cost (time, intrusion → infection/oxidation risk, real-time-tap effort).
- **Equipment unlocks free perception.** Stick-on thermotape is the canonical first upgrade — $5, makes fermenter temp readable from outside without intrusion. Glass carboy makes krausen state visible. A brewing thermometer with a permanent grommet probe makes fermenter temp readable always-on.
- **Skill makes vague checks more legible.** Apartment-novice "feels cool" eventually becomes "feels mid-60s" with enough Process skill — your fingers learn temperature.
- **Anomalies happen on schedule** regardless of whether the player checks. Cold spot is real if the world generates it; the player either notices and acts, or doesn't notice and pays the price at tasting.
- **Journal post-mortem reveals everything missed.** Teaching mechanism — the player learns what they should have caught.

### 3.8 v1 Styles

Three styles. Each meaningfully different in technique. Each demands the player learn something the others didn't.

#### American Pale Ale (the starter)

- **Method:** Extract (LME). All-grain optional later.
- **Hops:** Cascade, single variety, 3 additions. Standard schedule.
- **Yeast:** US-05 dry ale (forgiving, fast, clean).
- **Mash:** N/A (extract).
- **Ferment:** ~5 days at 19°C.
- **Condition:** ~14 days.
- **Lessons taught:** the brewing flow, hop scheduling, basic sanitation, basic temperature management.

#### West Coast IPA (the second)

- **Method:** Extract initially, all-grain unlocks late.
- **Hops:** Multiple varieties, complex schedule (60, 20, 15, 10, 5, 0, dry hop). Pushes hop timing as a real mechanic.
- **Yeast:** US-05 or similar clean ale yeast.
- **Mash:** Lower temp for drier finish (if all-grain).
- **Ferment:** ~7 days at 19°C, then dry hop, then 3 more days.
- **Condition:** ~14 days.
- **Lessons taught:** hop scheduling at higher complexity, dry-hopping (a new fermentation-stage interaction), recipe formulation.

#### Dry Stout (the third)

- **Method:** All-grain (or partial mash).
- **Hops:** East Kent Goldings, simpler schedule. Hops support, don't lead.
- **Yeast:** Irish ale yeast (different attenuation, different flavor profile, sensitive to temp).
- **Mash:** Lower temp (153°F) for dry finish; specialty malts (roasted barley, chocolate malt) handled with care.
- **Ferment:** ~10 days at 18°C.
- **Condition:** ~14 days, may benefit from longer.
- **Lessons taught:** dark malt handling, all-grain mashing, multi-malt grain bills, yeast strain choice mattering.

These three styles cover three distinct lessons. v1 ships with no others. Lagers (cold conditioning takes weeks of in-game time, requires temp control beyond apartment scale), sours (months in real-feeling timelines), Belgians (yeast complexity), and others are post-v1 unlocks aligned with destination prestige.

### 3.9 v1 Mini-Game Catalog

Twelve mini-games covering the apartment-scale brewing arc end-to-end. Three shapes, distinguished by what the player is *doing*:

- **Skill challenges** — your hands' precision matters in real-time (gesture quality, timing precision).
- **Decisions with consequences** — you choose a value/option and the world responds.
- **Job execution** — you take or skip a series of optional sub-actions; the breadth determines the care factor.

#### The catalog (with consequences)

| # | Mini-game | Stage | Shape | Consequence axes |
|---|---|---|---|---|
| 1 | **Fill kettle** | Prep | Decision (volume target) | volume, OG drift, possibly stuck-ferment risk |
| 2 | **Mash temp hold** (all-grain only; skipped on extract) | Mash | Skill (dial tuning) | recipe drift (body, FG), efficiency |
| 3 | **Boil + hops** | Boil | Mixed (skill timing + decision heat) | IBU, recipe drift, boil-over, volume loss |
| 4 | **Cool wort** | Cool | Decision (path) + skill (rate management) | infection, off-flavor temp |
| 5 | **Transfer to fermenter** | Cool | Skill (gesture) | oxidation |
| 6 | **Pitch yeast** | Pitch | Skill (gesture distribution) | infection (slow start), recipe drift |
| 7 | **SG reading** (gated by hydrometer) | Ferment | Decision (when/how often) + recognition | oxidation per use vs. measurement_uncertainty resolution |
| 8 | **Bottle fill** | Bottle | Job execution (per bottle) | oxidation, carbonation drift |
| 9 | **Cap bottles** | Bottle | Skill (gesture) | leak risk, oxidation |
| 10 | **Clean equipment** | Anytime | Job execution | infection (resets cleanliness state) |
| 11 | **Sanitize equipment** | Anytime | Job execution (timed) | infection |
| 12 | **Pour & taste** | Tasting | Skill (pour) + recognition (flavors) | Palate XP, journal completeness |

#### Three additional discovery-only interactions (not "mini-games" per se)

| # | Interaction | When | Type |
|---|---|---|---|
| 13 | **Check fermenter** | Daily during fermentation | Discovery panel — pick perception method given equipment |
| 14 | **Crush grain** (all-grain) | Prep | Decision (coarse / medium / fine) |
| 15 | **Address fermenter anomaly** | When discovered via #13 | Decision (mitigation method given equipment) |

These are listed separately because their UX shape is distinct from a brewing-day mini-game scene. They appear in the daily checklist; they pop up as small-panel decisions rather than full scenes.

#### Mini-game scaffolding (universal)

Every mini-game scene conforms to a shared input/output shape:

- **Inputs:** the active brew's BrewState, the equipment in use (with full property bag), the player's relevant skill levels.
- **Process:** mini-game execution, real-time elapsed.
- **Outputs:** an `Outcome` dict containing:
  - `actual` measurements (volume actually poured, temp actually held, etc.)
  - `care_factor` (computed from sub-action breadth)
  - `risk_deltas` (per-axis additions to RiskProfile)
  - `xp_gained` (per-skill XP earned by participation, more for high-quality execution)
  - `journal_notes` (1–3 lines describing what happened, used in the journal post-mortem)

Once we build the first 3–4 mini-game scenes, the rest are templated against this shape.

#### Catalog → consequence chains for the first three mini-games

(The full consequence detail for all 12 lives in Section 9 — Mini-Game Build Plan, future. Here are the first three to demonstrate the level of specificity we're committing to.)

##### Mini-game #1 — Fill Kettle (apartment, basic kettle, no hydrometer)

**Sub-actions (player picks):**
- Source water: Tap (free) / Bottled spring (consumes spring water) — required choice.
- Method: Pour straight (fast, high drift) / Pour through funnel (medium drift) / Measure with 1L pitcher (low drift, slow).
- Verify (optional): Visual check final level / Re-measure with pitcher.

**care_factor mapping:**
- 1 sub-action (just pour straight): 0.6
- 2 sub-actions: 0.85
- 3+ sub-actions: 1.0

**Outcome computation:**
```
target = recipe.boil_volume_gal  # 2.5
equipment_precision = source.precision_for_volume × method.precision_for_volume
skill = player.skills.process
care = care_factor

drift_stddev = base_drift / (skill_factor × equipment_precision × care)
actual_volume = target + drift_stddev × randn()
```

**Downstream effects:**
- Sets `brew.actual_water_volume`. All subsequent OG calculations use this.
- Larger-than-target volume → dilute wort → lower OG → lower ABV
- Smaller-than-target volume → concentrated wort → higher OG → potentially harsh beer or stuck ferment

**Failure modes the player can experience:**
- Eyeballed tap water with no skill → off by ±1 gallon → recipe-drift risk +major
- Used spring-water jug with markings + lazy → still pretty good (jug carries you)
- Used measuring pitcher 10 times scrupulously → tight, even at zero skill

##### Mini-game #4 — Pour LME (Step 4 of brewing day; sub-component of "Heat & Mix Wort")

This is the canonical example from Appendix A — see Step 4 in the walkthrough. The mini-game is shape-wise a *decision-and-sequence* interaction: turn off burner FIRST, then add LME WHILE STIRRING.

**Sub-actions:**
- Toggle burner OFF (binary)
- Drag spoon → kettle (start stirring)
- Drag LME → kettle slowly (controlled pour gesture)

**Order matters.** The system observes the order and timing.

**Outcome computation:** modifies several variables of the brew:
- `risk_profile.scorch` — 0 if burner was off and LME was added with stirring. Otherwise scales with seconds-of-direct-LME-on-hot-burner.
- `lme_dissolution` — 0.6 to 1.0 based on stirring quality. Affects OG (undissolved LME doesn't contribute to gravity).

**Failure modes:**
- LME dropped without burner off → SCORCH event. `risk_profile.scorch += high`. Visible: dark patch in kettle. Off-flavor in finished beer.
- LME dropped without stirring → puddle on bottom, slow dissolution → `lme_dissolution = 0.7`. Lower OG.
- LME poured slowly while stirring with burner off → ideal. `lme_dissolution = 1.0`. No scorch.

##### Mini-game #5 — Bring to Boil (Step 6 of brewing day)

**Sub-actions:**
- Set burner heat (HIGH/MED/LOW)
- Watch for hot break (visual cue → tap to acknowledge → starts the 60-min timer)
- Optionally adjust heat as needed (more taps during the boil)
- Avoid leaving the screen mid-boil — leaving pauses the boil but anything in-flight may have consequences

**This is mostly a recognition + dial interaction.** Not really a "skill challenge" because the precise timing of the tap doesn't reward sub-second precision; it's about *whether you noticed.*

**Outcome computation:**
- `boil_recognition_offset` — seconds early/late from actual rolling boil. With 0 Boil Recognition skill, your perception window is wide (±60s); with mastery, narrow (±5s).
- `IBU_actual = recipe.target_ibu × hop_utilization_factor`, where `hop_utilization_factor` depends on whether the boil was a true rolling boil for the full schedule.

**Failure modes:**
- Called the boil 30s early → IBU under-target by ~6%
- Called the boil 60s late → IBU under-target by ~10% (but more importantly, all hop-addition timers run late)
- Watched and called accurately → on-target

The full consequence chains for the other nine mini-games will be specified in Section 9.

---

# Appendix A — First-brew walkthrough (brewing day)

This appendix narrates the player's first-ever brewing day, end to end, with concrete consequences mapped to every step. **If this walkthrough and the abstract design conflict, the walkthrough wins.**

## Cold open

App launches. Animated scene of a dark kitchen with steam from a kettle fades to a still — the player's apartment kitchen, a side-view illustration. Dashboard.

A muted text-message buzz. Phone icon at the bottom-right pulses.

Tap the phone icon → Messages app, single thread, **Marcus**.

> **Marcus** (Saturday morning):
> "yo party next saturday at my place"
> "you said you might try brewing right? would be sick if you brought beer"
> "no pressure but"
> "Mom & Dad said they'd chip in $30 if you do it btw, called it your 'startup capital' lol"
>
> [image attachment: a torn page from BREW MAGAZINE]

Tap the image → full-screen recipe card.

> **Apartment Pale Ale** *("Bulletproof first batch. Forgiving. Tasty.")*
>
> Ingredients (5 gal): 6 lb LME · 1 oz Cascade @ 60min · 0.5 oz Cascade @ 15min · 0.5 oz Cascade @ flameout · 1 packet US-05 · 5 gal water · 5 oz priming sugar
>
> Targets: OG 1.045 · FG 1.012 · ABV 4.5% · IBU 30
>
> *Boil 2.5 gallons. Add LME late. Top off with cold water in the fermenter.*

Bottom of recipe: **Start brewing** (greyed out — no ingredients) and **Shop**. Wallet: **$30**.

## Shopping

Tap **Shop** → Homebrew Supply app. Recipe pre-checked as a shopping list:

| Item | Cost | Required? |
|---|---|---|
| Light Malt Extract — 6 lb tin | $18 | ✓ |
| Cascade hops — 2 oz | $4 | ✓ |
| US-05 dry ale yeast | $4 | ✓ |
| Priming sugar — 5 oz | $1 | ✓ (later, but cheap, buy now) |
| Bottled spring water — 5 gal jug | $4 | optional (you have a tap) |
| Star San sanitizer — 8 oz | $8 | optional (you have dish soap) |

Total if everything: $39. Wallet: $30. **The first real choice the game asks.**

The game does not say which to skip. Most first-time players will buy everything required ($27) plus the cheapest optional ($4 spring water), totaling $31 — they're $1 short, the game prompts "Skip something?", they remove the priming sugar (or the sanitizer, etc.). Or they skip the spring water and use tap (free) — saves $4, can afford sanitizer.

Each choice carries forward as a real consequence:
- **Skip spring water → use tap.** Apartment uses regional water preset; the chemistry differs from spring water (typically more minerals, slight chlorine). For a first-brew pale ale, mostly fine but adds small recipe-drift to perceived flavor.
- **Skip sanitizer → use dish soap.** Soap *cleans* but doesn't *sanitize*. Infection_risk floor is elevated for this brew.

Items appear in the kitchen — LME tin on counter, hops in fridge, yeast packet on counter, sanitizer (or not) in cleaning cupboard. Bottles already there from the player's previous life.

**Start brewing** is now ungreyed.

## Equipment present at start (no purchase needed)

| Item | Properties |
|---|---|
| Stove | `heat_levels: ENUM(HIGH, MED, LOW)`, `max_btu: 11000`, `has_target_temp: false` |
| Stockpot ("Boil Kettle") | `volume_capacity_gal: 5`, `volume_markings: NONE`, `has_thermometer: false`, `material: ALUMINUM`, `precision_for_volume: 0.4` |
| Plastic bucket fermenter | `volume_capacity_gal: 6.5`, `transparent: false`, `has_temp_probe: false`, `airlock_grommet: true` |
| Long plastic spoon | basic stir tool |
| Bi-metal stick thermometer | `precision: ±5°F`, `response_time: SLOW` |
| Wing capper | `type: WING`, requires squeeze gesture |
| 24 empty 12oz bottles | already saved from before |
| 1L measuring pitcher | `precision: 0.85` (for volumes), 1L per pour |
| Funnel | for transfers |
| Sponge + dish soap | basic cleaning, NOT sanitizer |

Notable absences: hydrometer, dedicated brewing thermometer, auto-siphon, bottling wand, wort chiller, refractometer, brewing scale, pH meter, thermotape, brew belt. All future purchases.

## Brewing — step by step

Tap **Start brewing**. Scene loads: kitchen with stove on the right, kettle on the cooktop, fermenter on the counter, recipe step-list panel on the side (collapsible).

### Step 1 — Sanitize fermenter & tools

Sub-actions available (player picks any/all):

| Action | Time | Consumable | Effect |
|---|---|---|---|
| Skip cleaning | 0 | none | Bucket stays in current state (USED from prior life) — high infection_risk_baseline |
| Rinse with water | 30s | none | State → SERVICEABLE |
| Soap-wash with sponge | 90s | dish soap | State → CLEAN |
| Sanitize with Star San (if owned) | 60s | Star San | State → SANITIZED, infection_risk_baseline near zero |
| Drip-dry on rack | 30s | none | Removes residual moisture (no consequence if Star San — it's no-rinse — but soap residue would be bad) |

Player who has Star San can do all 5 → care_factor 1.0, state SANITIZED.
Player who skipped sanitizer → max care_factor 0.85, state CLEAN — passable but not optimal.

Writes to: `fermenter.state`, `fermenter.sanitized_at`, `risk_profile.infection_baseline`.

### Step 2 — Add water to boil kettle

Target: 2.5 gallons (recipe specifies partial boil; top-off in fermenter later).

**Source choice:**
- Tap (free, regional water preset)
- Bottled spring water (if owned, drag jug → kettle)

**Method choice (if tap):**
- Pour straight from faucet (eyeballing — large drift)
- Pour through funnel (less mess, similar drift)
- Measure with 1L pitcher (~10 pours — slow but accurate)

If using the spring-water jug: the jug has printed markings, so pouring 2.5 gal is exact-known. Easy.

Drift (per Section 3.1 formula):
```
target = 2.5 gal
base_drift = 0.5 gal (large for novice eyeball)
skill_factor = 0.4 (no Process skill yet)
equipment_precision = 0.4 (no kettle markings) for eyeball,
                      0.95 (jug visible) for spring water,
                      0.85 (measuring pitcher) for tap+pitcher
care_factor = depends on actions taken
```

The drift propagates: too much water → wort more dilute → lower OG → lower ABV → recipe drift downstream.

Writes: `brew.actual_water_volume_gal`, `brew.water_source_id`, `brew.water_chemistry`.

### Step 3 — Heat the water

Target: ~150°F before adding LME (so LME dissolves cleanly without scorching).

Stove dial: HIGH / MED / LOW. Player drags it.

- **HIGH** — fast (~5 in-game min to 150°F). Easy to overshoot with the slow analog thermometer.
- **MED** — moderate (~10 min). Easier to catch.
- **LOW** — barely rises. Time-wasteful.

Player can tap the thermometer to "check temp" — analog needle shows a vague reading with ±5°F precision.

Sub-actions:
- Set burner to HIGH and walk away (lazy)
- Set burner, monitor, dial down before overshoot (normal)
- Pre-heat slowly on MED, monitor closely (scrupulous)

Overshoot itself isn't catastrophic. The next step is what makes it dangerous.

Writes: `brew.water_temp_at_lme_addition_c`.

### Step 4 — Turn off burner, then add LME

The canonical example. Recipe text says: *"Turn off burner, then slowly pour LME while stirring continuously."*

**Player has affordances available:**
- Stove dial (drag to OFF or any setting)
- LME tin (drag to kettle)
- Spoon (drag to kettle to start stirring)

**The CORRECT sequence:** dial → OFF, then drag spoon → kettle (start stirring), then drag LME → kettle (slowly while spoon stirs).

**Outcome by player action:**

| Action sequence | Result |
|---|---|
| Drag LME without turning off burner | LME drops to bottom (denser than water). Bottom of kettle on hot burner. **SCORCH** — caramelization → burnt-extract twang in finished beer. `risk_profile.scorch += high`. |
| Pour LME without stirring | Even with burner off: LME puddle on bottom hardens. Some sugars never dissolve. `lme_dissolution = 0.6`. OG below recipe target. |
| Pour LME too fast | Bolus doesn't disperse fast enough. Partial scorch (if burner was on briefly), partial undissolved. Mid-bad outcome. |
| Pour LME slowly while stirring with burner OFF (correct) | Even dispersion, full dissolution, no scorch. `lme_dissolution = 1.0`, `risk_profile.scorch = 0`. |
| Stir AFTER pour, BEFORE turning off burner | Damage already done. |

The mini-game watches for *order* of actions and *timing*. Outcomes computed from actuals, not from a single boolean "did you do this step?"

The player learns: order matters. Real homebrewing has the same lesson.

### Step 5 — Bring to boil

Burner back ON, dial to HIGH. Wait for boil. **Hot break** event fires when foam appears and settles — visual cue. Recognizing the hot break is when the 60-min timer "really" starts (real homebrewers know this).

Skill: `Boil Recognition` (sub-axis of Timing). Zero skill: ±60s window. Mastery: ±5s.

Outcomes:
- Called early — IBU drift down ~6%
- Called late — IBU drift down ~10%, all hop-addition timers run late
- Called accurately — on-target

### Step 6 — Boil 60 minutes

Real time: ~3 minutes (in-game time accelerates aggressively when no events pending; slows on event approach).

**Events during the boil:**

- **t=0 (boil start):** drop 1 oz Cascade. Drag bag → kettle. If you dropped early/late: partial bittering loss.
- **t=15–30 min:** **boil-over warning.** Foam climbs. Sub-actions: lower heat (most effective), blow on it (small effect), skim (tiny effect, risky — heat exposure risk to player character is lore only), do nothing → boil over. Boil-over loses 0.3–0.8 gal of wort + dirties stovetop. OG and IBU recalc lower.
- **t=45 min:** drop 0.5 oz Cascade (mid-boil for flavor).
- **t=55 min:** drop 0.5 oz Cascade (late for aroma).
- **t=60 min:** flameout prompt. Burner OFF. Forgetting for 30s = mild evaporation. Forgetting for 5+ in-game min = significant over-boil, IBU drift up, volume loss notable.

This is structurally a series of micro-interactions over a ~3-minute real-time scene. Time-acceleration decides pacing (events approach → time slows; gap → time rips).

### Step 7 — Cool the wort

Recipe says partial-boil + top-off, so two paths:

**Path A: Ice bath**
- Drag kettle to sink. Fill sink with ice (consumes ice from inventory; if none, "buy ice" option).
- Stir occasionally to circulate.
- 25–40 in-game min. Each min past 15 → small `infection_risk` increment.
- Monitor temp via bi-metal thermometer; target ~70°F before pitching.

**Path B: Top-off cooling (recipe-suggested shortcut)**
- Skip ice bath. Pour 2.5 gal hot wort into fermenter, then 2.5 gal cold water on top. Final ~80°F.
- Faster, free, less infection window — but the cold water itself is a sanitation gamble (sanitary? boiled and cooled? straight from tap?).

Player chooses. Each carries trade-offs.

### Step 8 — Transfer to fermenter (if Path A)

If Path A: now transfer.

- **Pour from kettle to fermenter (free, oxidation risk).** Drag kettle to fermenter, tilt-pour. Smooth pour = minimal `oxidation`. Splashy = oxidation increases.
- **Auto-siphon (later upgrade).** Eliminates oxidation.

Apartment-scale player almost always pours. Their gesture quality determines splash level.

### Step 9 — Top off with cold water

If not already done in Path B: add cold water to fermenter to bring final volume to 5 gal target.

Same volume-decision dynamics as Step 2 — your tap or your remaining bottled water.

### Step 10 — Pitch yeast

**Option 1: Sprinkle dry yeast directly on top.**
- Drag packet → fermenter, tap to sprinkle.
- Lazy: dump in one spot → clumps → slow start, infection wins more often.
- Normal: even sprinkle → good start.

**Option 2: Rehydrate first.**
- Pour into sanitized cup of warm water, wait 15 in-game min, swirl, then add to fermenter.
- Vigorous start, less stress.
- Adds 15 in-game min. Modest improvement.

Recipe doesn't insist on rehydration. Most homebrewers skip it. Optional care move.

### Step 11 — Seal & airlock

Drag lid → fermenter. Drag airlock → grommet. Fill airlock with sanitizer (if owned) or just water.

Brewing day ends. Fermenter goes to "the closet" (in fiction). Dashboard shows fermenter with active brew indicator.

---

# Appendix B — Fermentation day-by-day walkthrough

The first brew's fermentation period, 5 in-game days, day by day. Demonstrates the daily checklist, the discovery model, and the morning summary cadence.

## Day 0 — evening of brewing day

Brewing-day scene fades. Dashboard. **Evening, Day 0.**

Fermenter shows "Active fermentation just started. Krausen forming."

**Daily checklist (auto-derived):**
```
─── DAY 0 (evening) ───
Brewing
  ☐ Check fermenter (Pale Ale, just sealed)

Maintenance
  ☐ Clean kettle (DIRTY from boil)
  ☐ Clean stovetop (DIRTY from boil-over, if applicable)

Optional
  📱 Phone (1 new — Marcus, Mom)
─────────────
[Get some rest →]
```

Player taps Phone:
- Marcus: *"holy shit you actually did it??? when can i drink it"* — reply or ignore
- Mom: *"so proud of you honey ❤️"*

Player taps Check Fermenter → discovery panel:
```
Apartment Pale Ale · Day 0/5

What you can see without intrusion:
  • Airlock: bubbling slowly, just starting

Methods:
  [Touch the bucket] — free, vague
  [Hold thermometer in airlock] — small intrusion cost
  [Pop the lid] — significant intrusion cost
  [Done — that's enough]
```

Brand new fermentation; no real action. Player taps Done.

Player taps Clean Kettle → cleaning mini-game (~30s real). Kettle: DIRTY → CLEAN. Sanitation XP +3.

(Stove may also be dirty if a boil-over happened; same drill, optional.)

Player taps **Get some rest**. Kitchen lights dim, fade.

**Real time: ~2 minutes.**

## Day 1 — first morning of fermentation

**Morning summary card (briefly):**
```
─── DAY 1 ───
Apartment Pale Ale fermenting (day 1 of 5).
1 new text. Some forum activity overnight.
```

Dashboard. Daily checklist:
```
Brewing
  ☐ Check fermenter (Pale Ale)
Optional
  📱 Phone (1 new)
  📚 Forum activity
[Get some rest →]
```

Player taps Phone → Marcus: *"morning! is it ready yet?"* Player replies, *"it has to ferment for like a week dude."* Marcus: *"oh."* Single beat.

Forum (new app icon now lit because player has an active brew): two threads, a beginner Q&A and a recipe share. Reads one. Knowledge XP +5.

Tap Check Fermenter:
```
Apartment Pale Ale · Day 1/5

What you can see without intrusion:
  • Airlock: vigorous bubbling — about every 4 seconds

Methods:
  [Touch the bucket] — free, vague
  [Hold thermometer in airlock] — small intrusion cost
  [Pop the lid] — significant intrusion cost
  [Done — that's enough]
```

Player picks Touch:
> "The bucket feels noticeably warm. Fermentation is generating heat."

This is consistent with healthy primary fermentation — yeast generates heat. Nothing to do.

Player taps Done, then Get some rest.

**Real time: ~90 seconds.**

## Day 2 — anomaly day (player-discoverable)

**Morning summary:**
```
─── DAY 2 ───
It's cold this morning — the radiator's been off.
Apartment Pale Ale fermenting (day 2 of 5).
News: Cascade hops shortage hits PNW brewers.
```

Note: the summary does NOT say "your fermenter is cold." It says "the radiator is off" — ambient.

Dashboard. Daily checklist (uniform; no anomaly flag):
```
Brewing
  ☐ Check fermenter (Pale Ale)
Maintenance (none if all clean)
Optional
  📱 News
[Get some rest →]
```

If the player skips Check Fermenter → cold-spot anomaly proceeds undiscovered, fermentation slows, attenuation drift accumulates. Player won't know until tasting.

Most players, prompted by "it's cold this morning," tap Check Fermenter:

```
Apartment Pale Ale · Day 2/5

What you can see without intrusion:
  • Airlock: bubbling slowly (every ~12s — slower than yesterday)

Methods:
  [Touch the bucket] — free, vague
  [Hold thermometer in airlock] — small intrusion cost
  [Pop the lid] — significant intrusion cost
  [Done — that's enough]
```

Player picks Touch:
> "The bucket feels noticeably cool. Cooler than yesterday."

Now the player knows. Action panel:

```
What would you like to do?
  [Wrap fermenter in a towel] — free, drag towel from cupboard
  [Move to a warmer spot] — free, drag fermenter sprite
  [Buy brew belt ($25)] — locked, can't afford
  [Do nothing — accept it] — risk_profile.temp_low += high
  [Done]
```

Player picks Wrap. Drag towel from cupboard sprite onto the fermenter sprite. Quick wrap mini-game (drag-gesture). Status updates over the next in-game hours: "Temp recovering."

Player taps News, reads the Cascade hops article (flavor only), closes phone.

Get some rest.

**Real time: ~2–3 minutes.** Heaviest day so far.

## Day 3 — social day

**Morning summary:**
```
─── DAY 3 ───
Quiet morning.
Apartment Pale Ale fermenting (day 3 of 5).
Tim wants to chat. Mom messaged.
```

Daily checklist:
```
Brewing
  ☐ Check fermenter
Optional
  📱 Phone (2 new)
  📚 Forum (you were @-mentioned)
[Get some rest →]
```

Phone:
- **Tim** (first contact since the party): *"yo I'm hosting a homebrew tasting at my place in 2 weeks. you should come and try other people's stuff. low key, no pressure."* Reply: *"I'm in."* → adds Calendar event 14 days out.
- **Mom:** *"Just checking in. Did Marcus pay you for the beer?"* Reply, then: *"Good. Dad's birthday is in 3 weeks — would you make him a stout?"* Player can accept (Calendar event 21 days out, future order commitment) or decline.

Forum: you were @-mentioned on a thread you replied to. Drama-free community moment.

Tap Check Fermenter → airlock slower (~20s/bubble), normal for this stage. Touch bucket → "feels normal again, comfortably warm." Recovery from yesterday's cold spot was successful.

Get some rest.

**Real time: ~2 minutes.** Driven by social, not brewing.

## Day 4 — decision day

**Morning summary:**
```
─── DAY 4 ───
Apartment Pale Ale fermenting (day 4 of 5).
The airlock has nearly stopped bubbling overnight.
```

Note: this IS a brew-status disclosure — but it's an *observation* the player would have made by glancing at the fermenter passively, not a hidden risk. Surface-level, ambient. The player knows the airlock pattern from Day 0 onward.

Daily checklist:
```
Brewing
  ❗ Decide: bottle today, wait one day, or wait three?
  ☐ Check fermenter
Maintenance
  ☐ Clean stovetop (still dirty if not done)
[Get some rest →]
```

Note the **❗** flag — this is a *decision*, not a problem. Decisions get the ❗; anomalies get the ⚠ (only after the player discovers them).

Tap the decision:

```
Apartment Pale Ale · Day 4/5

The airlock has nearly stopped. Without a hydrometer, you can't verify FG.
Recipe says ready in 5–7 days.

Options:
  [Bottle today]  — early. Risk: trapped sugars → over-carbonation in storage → gushers/bombs.
  [Wait 1 more day]  — safe. Recipe says 5–7, day 5 is in the window.
  [Wait 3 more days]  — overcautious. Slight oxidation risk accumulating in storage.

Skill hint (locked at low Process skill): "—"
Skill hint (with mid Process skill): "Slowing airlock + 4+ days post-pitch usually means done, but bottling early on extract has burned more brewers than waiting too long."
```

Player picks **Wait 1 more day**.

Tap Clean Stovetop → quick mini-game (~30s real). Sanitation XP +5.

Get some rest.

**Real time: ~2 minutes.**

## Day 5 — bottling day

**Morning summary:**
```
─── DAY 5 ───
Apartment Pale Ale fermenting (day 5 of 5).
The airlock is essentially still.
```

Daily checklist:
```
Brewing
  ▶ Start bottling — your beer is ready.
[Continue]   [Wait another day]
```

The "Get some rest" button is replaced by the bottling-day entry. The day's checklist IS the bottling sequence.

(The full bottling sequence — sanitize bottles, mix priming sugar, transfer, fill, cap — is the second multi-step active scene of the brew. Detailed walk-through deferred to Section 9 / Mini-Game Build Plan.)

After bottling: fermenter is empty, ready for the next brew. Bottles go into a "conditioning rack" on the dashboard with a 14-day countdown.

## What the rhythm feels like

Per-day real-time engagement: **~90 seconds** (quiet day) to **~3 minutes** (anomaly or decision day). Five-day fermentation total: **8–12 real minutes**, spread across however many sessions the player plays.

Variety per day from a content pool — texts, forum activity, news articles, ambient cues, fermenter discoveries, optional cleanings, optional reading-for-XP, occasional calendar additions.

The fermentation period is **never empty**: there's always at least "Check fermenter" on the checklist. But it's also **not demanding** — empty days are explicitly OK; the checkbox count can be 1.

By Day 5 the player has experienced:
- A real choice (when to bottle)
- An anomaly to discover and handle (cold fermenter)
- Three named NPCs (Marcus, Mom, Tim) with continuing presence
- Two future commitments (Tim's tasting, Mom's stout order)
- Two skill XP nudges
- The feeling of "my beer is *actively becoming* something while I do other things"

That last one is the design's secret sauce. The player isn't waiting; they're keeping company with their beer.

---

# What's next (sections 4–9)

The remaining sections, queued for the next pass:

- **Section 4 — Time, Equipment Constraints, Cleanliness, Anomaly Generation.** The time-acceleration model formalized; equipment as a scheduling constraint (one fermenter = one active ferment); cleanliness state machine; anomaly generation rules.
- **Section 5 — Economy & Progression.** Ingredient pricing, equipment cost curves, customer payouts, competition prizes, the bankruptcy thresholds, the trends-system mechanics.
- **Section 6 — UX/UI.** Dashboard layout, brewery view, phone overlay, time control, handbook, recipe view, mini-game scene templates.
- **Section 7 — Technical Architecture.** Autoload inventory, scene graph, time service, content-pool generator, calendar service, save service.
- **Section 8 — Save Schema.** What persists, table layout (or JSON shape), migration story, prestige reset semantics.
- **Section 9 — Mini-Game Build Plan.** All 12 v1 mini-games specified at Section-3.9 level of detail (sub-actions, drift formulas, downstream effects). Build order. v2+ mini-games queued.
