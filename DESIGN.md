# Homebrewer — Design

The canonical game design document. Internal only — not shipped to the player.

This is being assembled in passes. Sections 0–3 + Appendices A and B were the first pass. Section 4 (Time, Concurrency, Conditioning, Commitments) and Section 8 (Save Schema Outline) are being filled in piece by piece as design conversations resolve. Sections 5–7 (Economy, UX/UI, Technical Architecture) and Section 9 (Mini-Game Build Plan) are queued, plus the full pass on Section 8. When a section locks, it stays locked unless the design explicitly revisits it. When implementation starts, this document is the spec; if the spec is wrong, fix the spec, then fix the code.

`CLAUDE.md` continues to define repo rules (commit to main, every player-visible commit bumps `changelog.json`, etc.). This document defines what the game **is**.

---

## How to read this

- **Section 0** — the elevator pitch and the five tenets that everything else respects.
- **Section 1** — the world, who's in it, the phone interface that ties social/customer/news/shopping together.
- **Section 2** — what one career looks like across decades of in-game time, and what prestige carries forward when you start over.
- **Section 3** — the brewing simulation. The outcome model, the equipment-as-properties model, the care system, skill axes, the risk profile, the discovery principle, the three v1 styles, the twelve v1 mini-games and their consequences.
- **Section 4** — time and concurrency. Two clocks (scene + day), how parallel brews coexist, why conditioning is passive and how the keg unlock breaks the apartment-tier wait, and how time-bound commitments (orders, social events, competitions) work via the Calendar. Drives most save-state and scheduling decisions downstream.
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

Movement between tiers is voluntary and reversible. You upgrade by accumulating cash and choosing to invest. You can downsize voluntarily (sell equipment, move back to garage scale) if you over-extended. Forced downsize happens via bankruptcy; see 2.7.

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
| Skill **levels** (penalty: drop 20% of current levels per axis, rounded down, floor 0 — a maxed level-30 skill becomes level 24, a level-7 skill becomes level 5; "20%" is tuning, locked in for save-schema purposes but expected to move during playtest) | Cash |
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

### 2.6 Economy is load-bearing from day one

Money is **not flavor**. From the player's first $30 onward, the economy is a real pressure system that constrains and shapes decisions at every tier. The reasons are concrete:

- **The $30 starter is intentionally insufficient** to buy everything on the recipe (Appendix A's shopping list totals $39). The player MUST trade off — skip sanitizer (real infection-risk floor), skip spring water (real water-chemistry drift), or skip a small consumable that hurts later.
- **Every brew costs ingredients that were paid for.** No infinite cycle; cash flow is tracked.
- **Every customer payment is real cash that affects future spending.** Mom's stout order isn't a story beat — it's revenue that pays for the next brew's ingredients.
- **Every equipment purchase displaces other purchases.** The $5 thermotape vs. saving for a $25 brew belt is a real choice, not flavor.
- **The player can genuinely run out of money** at any tier. Bankruptcy mechanics (2.7) are real gameplay events with real terms, not soft narrative bailouts.

This is in contrast to a "tutorial → real" curve where apartment is cosmetic and only later tiers bite. The decision is that **apartment-scale economy is already real**, just at smaller numbers. The trade-offs are smaller in absolute dollars but proportionally just as load-bearing on the player's choices. A first brew where the player chose tap-over-spring-water to afford sanitizer carries that consequence into the finished beer; a player who can't afford ingredients for brew #2 has to actually do something about it (sell bottles to Marcus, accept Mom's loan with terms, take an early customer advance).

This decision shapes downstream design:

- **Save schema (Section 8 / item #10) must persist:** cash balance, outstanding loans (including informal ones like Marcus's bailouts) with terms, customer advances and their delivery deadlines, recurring expenses (rent at higher tiers), bottle/ingredient inventories.
- **Section 5 (Economy) is built on this premise** — pricing curves, customer payouts, competition prizes, and trend multipliers all assume the player feels them.
- **Calendar is partially driven by economy** — customer-order deadlines, loan repayment deadlines, and trend windows are all calendar entries (item #9 territory).

The other end of the spectrum (cosmetic-throughout, where the player can never genuinely lose to economics) is explicitly rejected — it would undermine Tenet 2 (outcomes from your choices) at the resource level.

### 2.7 Failure / bankruptcy

Money can run out. The game's response scales with where you are, but every tier's response is a **real gameplay event with terms**, not a soft narrative bailout (per 2.6):

- **Apartment scale, broke.** Marcus offers a small loan with real terms — typically $40–80 in cash with strings: you owe him a 6-pack of your next batch (consuming 6 bottles from your inventory), first dibs at the next party, and a soft promise of "I get to brag about you to my friends." Loan is finite per scale (one outstanding Marcus loan at a time; he won't lend again until repaid). If the player exhausts Marcus's patience (multiple unpaid loans, missed party deliveries), Marcus stops lending until a relationship-repair beat lands. Mom may also offer a small advance — pay-in-advance for a bottle order with an explicit delivery deadline. The bailouts are real cash that costs real future bottles or future brews; no equipment is ever lost at apartment scale, but the player can absolutely feel stuck if they mismanage.
- **Garage scale, broke.** A customer (local bar owner, brewing-club member, returning friends/family) offers an advance against a bulk order. Real deadline, scaled to the advance. Missed delivery = relationship hit + possibly cash penalty. Adds genuine pressure; no equipment loss yet, but reputation matters at this tier and missed orders propagate.
- **Pro brewery, broke.** An angel investor steps in, but takes a real cost. The player chooses:
  - **Equity:** lower payouts on every future sale until the loan is paid back (with interest)
  - **Forced downsize:** sell your fanciest equipment, possibly move back to garage scale.

**Voluntary downsize anytime.** You can sell equipment and relocate (apartment ↔ garage). Carries a small "moving cost" hit (5–10% of equipment value). Useful when you've over-invested or trends have turned against your gear.

This makes downsize a tool, not just a punishment. The downsize-then-rebuild story arc is intentionally available — pro brewer who made bad decisions retreats to apartment to consolidate, then rebuilds smarter.

### 2.8 Trends (apartment vs. pro)

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

#### Care is breadth, not order

Care is a continuous factor (0.6–1.0) emerging from the *breadth* of optional sub-actions taken — "did you also Star San? did you also drip-dry?" It does not police the *order* of actions. Order-mattering interactions (e.g., the LME pour: burner OFF → start stirring → pour LME) are a separate interaction shape called **procedure**, defined in 3.9. Procedure produces discrete events with sometimes-catastrophic outcomes; care produces a continuous drift modifier. The two coexist within a mini-game (the LME pour is procedure for the action order, with care still derivable from optional sub-actions like rehearsing your stir grip), but the architecture treats them as different mechanisms.

### 3.4 Skill Axes

Six axes. All grow from real-stakes reps only — no practice mode, no XP from drills.

| Skill | Affects | XP source |
|---|---|---|
| **Sanitation** | Infection risk reductions; care factor on cleaning interactions | Successful cleans, sanitized brews without infection events |
| **Temperature Control** | Mash temp hold accuracy; ferment temp anomaly response; cool-stage timing | Mash steps within target, anomaly mitigations |
| **Timing** | Hop drop accuracy; boil duration accuracy; bottling priming sugar steep | Hop additions on schedule, boil duration ±N min |
| **Process** | General execution quality (transfers, pitches, captures); reduces splash/oxidation | Transfers without spillage, pitches with even distribution |
| **Palate** | Reading **other brewers' beers** primarily — flavor identification, body, recipe inference at high tiers; reading carb level + flavor on conditioning testers (only Palate-gated read; no equipment substitute on bottle-conditioned beer); reading your own finished brew (the journal post-mortem still teaches the truth, but Palate lets you read it in the glass first) | Comparison tastings at NPC events (Tim's tasting club, brewing-club meetings, competitions you judge); journal-confirmation loop on your own brews (you sense → journal confirms → +XP whether you guessed right or wrong); forum threads on flavor vocabulary (small but reliable); modest base rate from tasting your own finished beer |
| **Water Chemistry** | Water-treatment effectiveness; recipe-faithfulness for chemistry-sensitive styles | **Equipment-gated.** Invisible until the player owns a pH meter or water-test kit (typically the WC IPA / Dry Stout era when all-grain begins). Once unlocked, XP from successful pH-target hits during mash, water-treatment additions matching style profile, and journal callouts confirming chemistry choices. See note on the equipment-perception pattern below. |

Skill levels grow on a curve: early levels are fast (XP_to_next = 100), late levels are slow (XP_to_next = 10000+). The curve makes early progress feel responsive and late mastery feel earned.

Skill caps achievable outcomes. **At zero skill, A+ outcomes are unachievable even with perfect play.** Your first beer cannot be a competition winner. As skill grows, the achievable ceiling rises. Pro-tier brewing demands mid-to-high skill across multiple axes.

#### How the skill cap works mechanically

The drift model in 3.1 is statistical — a lucky tight Gaussian roll could in theory put a zero-skill brew on target. The grade ceiling is therefore a **separate function on top of drift**, not a property of drift. Per skill axis:

| Skill level | Max grade contributed |
|---|---|
| 0 | C |
| 5 | B |
| 10 | A- |
| 15 | A |
| 20+ | A+ |

The brew's overall grade ceiling = `min` across the **relevant** skill axes for that recipe. Recipe operations determine which axes are relevant: extract APA invokes {Sanitation, Temp Control, Timing, Process}; all-grain Stout adds Water Chemistry — but only when the player owns and uses a pH meter (per the equipment-perception note above; without the equipment, water chemistry is invisible and doesn't cap). The brew's final grade = `min(drift_derived_grade, brew_grade_ceiling)`.

Two implications worth pinning:

- **Palate is not a brew-grade skill.** Palate caps perception (reading other brewers' beer; identifying flavors in your own at tasting), not the brew you make. A beer made by a tin-tongued brewer who happens to be a wizard at sanitation, timing, temp, and process can absolutely score A+; they just can't taste why.
- **Maxed skills flatline at A+ by design.** Once your relevant axes are all level 20+, casual brews are reliably A+. Endgame challenge moves to competition rubrics (which can score finer gradations within the A range — likely a v2+ extension on top of consumer grade), trend-fitting at pro tier, exotic styles that test fresh axes, recipe invention, and tight-deadline / constrained brews. Mastery doesn't run out of things to do; it just stops being measured by consumer-grade.

The prestige penalty (2.4) drops levels by 20% rounded down, floor 0. A pre-prestige max-out (level 30) drops to level 24 — still in the level-20+ plateau, still capped at A+. The "world-renowned brewer with starter gear still makes good beer" effect is real, mediated through drift (3.1's `equipment_precision` does the work) — apartment-tier equipment loosens the actual brew toward A/A-, while the skill ceiling stays at A+.

#### Skill snapshots per interaction (no retroactive propagation)

Each mini-game interaction snapshots the relevant skill level at the moment it executes, and that snapshot drives the outcome. XP earned by the interaction is awarded *after* the outcome is computed, so an interaction never benefits from the XP it just produced. In-flight brews therefore do not retroactively benefit from skill growth that happens during their fermentation/conditioning window.

Worked example for an Apartment Pale Ale:

- **Day 0** — kettle fill executes with Process level 7. Drift uses 7. +5 Process XP after.
- **Day 0** — boil executes with Timing level 6. Drift uses 6. +8 Timing XP after.
- **Day 5** — bottling fill executes with Process level 8 (you've leveled). Drift uses 8.
- **Day 19** — final tasting executes with Palate level 4. Reveal uses 4. +12 Palate XP after.
- **Day 19** — same evening, you start prep on the next brew. Process level is whatever it is *now*. The Day-0 brew's Day-0 Process value is unaffected.

Three implications worth pinning:

- **Journal honesty.** Each interaction's snapshot skill level is part of its journal record. The post-mortem can faithfully show "your Process was 7 when you did this kettle-fill" — useful teaching, no retconning.
- **Long brews don't benefit from their own ferment-window XP.** A Stout that ferments 10 days and conditions 14 days does not retroactively pull in skill XP earned during those 24 days. Realistic — palate growth on Day 22 doesn't make the wort you boiled on Day 0 better.
- **Tasting and conditioning testers snapshot Palate at the moment they execute.** Your Day-19 final tasting reads with Day-19-start Palate, not Day-19-end-of-tasting Palate. The XP from that tasting lands after, benefiting future tastings of *other* beers.

#### Two skills are worth calling out

**Palate is the social skill.** Unlike the other five — which earn XP primarily from your own brewing reps — Palate's main loop is *evaluating other people's beer*. Your own beer's truth lives in the journal post-mortem; Palate is what lets you read commercial references, tasting-club submissions, competition entries you're judging, the IPA Marcus brought back from the brewery he visited.

The reading scales hard with level:
- **Low Palate:** "tastes like beer."
- **Mid Palate:** "American pale ale, fairly hoppy, clean yeast — US-05 territory."
- **High Palate:** effectively reverse-engineers the recipe from a glass — style, OG range, hop varieties in the dry hop, yeast profile, fermentation temp tells, even whether it was extract or all-grain.

This is the skill that bridges tasting other brewers' work and inventing your own recipes (the late-game recipe-invention unlock). It also gates judging credibly at competitions — a low-Palate player can technically enter a judging slot, but their feedback to entrants is shallow and the in-fiction community notices.

**Water Chemistry is the canonical equipment-perception skill.** Per Tenet 3, equipment unlocks perception. Water chemistry is the cleanest example of that pattern: until the player owns a pH meter or water-test kit, water chemistry is invisible. The simulation still computes it — your tap water has whatever profile the regional preset gives it; brews drift accordingly — but the player can't see it, the journal doesn't mention it, and there is no Water Chemistry skill track yet.

The moment a pH meter ships, the dimension lights up: mash-prep mini-games gain a "check pH" sub-action, the journal starts calling out chemistry effects ("mash pH was 5.8 — high for this style; contributed to the harsh finish"), and Water Chemistry XP starts accruing from informed choices. Players retroactively understand "*oh, that's why my IPA was harsh*" the first time a pH meter shows them what was happening invisibly all along.

This pattern — equipment as the perception unlock that lights up an entire subsystem — repeats at smaller scale elsewhere: thermotape unlocks fermenter temp from outside, hydrometer unlocks SG, refractometer unlocks SG without the oxidation cost. Water Chemistry is just the biggest, latest, and most consequential version of the same idea.

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
- **At tasting (Pour & Taste mini-game):** Palate skill gates how many of the actual flavors the player can identify in the finished beer. Low Palate: "tastes like beer." High Palate: "smells of cardboard and slight sourness; the head doesn't hold." (Palate's primary load-bearing read is on *other people's* beer per 3.4; this in-the-moment read of your own brew is a smaller secondary use.)
- **In the journal, post-mortem:** all risk axes are revealed numerically + narratively. "Oxidation: 6/10. Cause: splashy transfer at bottling. Effect: cardboard finish in 4 weeks." Teaches the player what they did and didn't do.

**The journal does not violate Tenet 4.** Tenet 4 ("the game discloses nothing it shouldn't") governs *in-the-moment* perception during play — what the player can see while a brew is happening, while they have agency to act on it. Anomalies stay ambient until the player chooses to look; flavors stay vague until skill or equipment makes them legible. The journal post-mortem is a **post-hoc teacher**, not an in-the-moment disclosure: its full numeric/narrative reveal happens *after* the brew is graded and the player has no further actions to take on it. That's intentional — it's the design's main feedback channel for getting better between brews. The two reveal modes layer cleanly: discover what you can in real time (skill- and equipment-gated), then the journal fills in the gaps so next time you can catch it earlier.

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

The recipe is the **truth** for the player's own self-evaluation. The brewing simulation computes drift between actual outcomes and these targets. Self-evaluation grading (the journal post-mortem grade — "did you make what you intended?") is a function of cumulative drift across all axes against the recipe.

#### Two grading channels: self vs. external

Self-evaluation is not the only grade a brew receives. **External evaluation** — by customers, NPCs, and competition judges — uses the **canonical style profile** for the brew's tagged style (BJCP-style guidelines), not the player's recipe. Two channels:

- **Self-grade** (journal post-mortem). Drift between actual and the player's recipe targets. Tells the player "did I succeed at making my recipe?" Useful for the player's own learning loop.
- **External grade** (customer ratings, NPC tasting feedback, competition scoring). Drift between actual and the canonical style profile. Tells the world "is this a good example of the style?"

The two grades are independent. A player's tightly-executed recipe might self-grade A+ but external-grade B if the recipe drifts from style guidelines (e.g., over-hopped for an APA → "not really a pale ale anymore"). Conversely, a sloppy execution might self-grade C but external-grade B+ if the drift accidentally pushed the brew closer to its style profile than the recipe itself was.

#### Player-invented recipes (late-game unlock)

Players can *invent* recipes once a late-game unlock fires. Invented recipes:

- Become a normal recipe in the player's recipe collection.
- Carry a **required `target_style` tag** — the player declares what style this is supposed to be. The tag is mandatory; recipes can't be untagged.
- Are graded on both channels: self-grade against the player's targets (as above); external-grade against the `target_style`'s canonical profile.

This closes the obvious exploit (invent a "recipe" with trivial targets, hit them, score A+). The player's invention only governs self-grade; external graders use the style profile, which is immutable. If the invented recipe's targets drift from the style it claims to be, the self-grade and external-grade diverge — interesting and informative, not gameable.

**Experimental brews without a target style.** A player can brew without declaring a style ("I'm just experimenting"). These exist outside the grading economy: no competition entry, no external grade, NPC casual feedback is "weird, but in a fun way" rather than style-judged. Self-grade still works (you set targets; we grade against them) but the brew is segregated from the rest of the scoring world.

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

Twelve mini-games covering the apartment-scale brewing arc end-to-end. Four shapes, distinguished by what the player is *doing*:

- **Skill challenges** — your hands' precision matters in real-time (gesture quality, timing precision).
- **Decisions with consequences** — you choose a value/option and the world responds.
- **Job execution** — you take or skip a series of optional sub-actions; the *breadth* determines the care factor (per 3.3). Continuous, no catastrophic single-step failures.
- **Procedure** — discrete actions that must happen in the right *order*. Wrong order produces a specific, often catastrophic event (e.g., LME poured before burner OFF → SCORCH). Distinct from job execution: procedure cares about sequence, not breadth, and failures are discrete events rather than a continuous drift modifier. The canonical example is the LME pour (Mini-game #4 below). A single mini-game can compose shapes (the LME pour is procedure for the order, plus a skill component on the actual pour gesture).

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

#### Single-touch platform constraint

The game is a phone game on a single-touch screen. Mini-games cannot require two simultaneous drags. When a mini-game's fiction calls for "two things happening at once" (the LME pour requires stirring while pouring), the design pattern is **drag-to-start-autonomous-action**: the player drags the first object to set it in motion (it then animates autonomously and visibly), then proceeds to the second object. The autonomous animation gives the player visual feedback that the first action is "still going" without requiring continuous touch. Skill is graded only on the gesture the player is actively making — the autonomous action is fictional infrastructure, not a precision check.

The LME pour (Mini-game #4 below) is the canonical example of this pattern.

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

This is the canonical **procedure** mini-game (per the four-shape definition above) and the canonical example from Appendix A — see Step 4 in the walkthrough. The order is the load-bearing thing: turn off burner FIRST, then add LME WHILE STIRRING. A skill component rides on top of the procedure (the actual pour gesture quality), but procedure dominates: getting the order wrong produces a discrete catastrophic event (SCORCH) regardless of how skillful the pour was.

**Sub-actions (in expected order):**
1. **Toggle burner OFF** (binary tap on the dial).
2. **Drag spoon → kettle.** This is a single drag that releases. On release, the spoon enters an autonomous stirring animation (visible loop, communicates "still going") — see the single-touch constraint above. No further touch is needed to keep the spoon stirring; it stirs for as long as this scene runs or until the player drags it back out.
3. **Drag LME → kettle slowly.** This is a single sustained drag with a controlled-pour gesture (steadiness, speed, arc smoothness). Skill on the pour gesture is computed from THIS drag specifically, not from the spoon's autonomous loop.

**Order matters.** The system observes the order of (1)→(2)→(3) and the timing between them. The autonomous stirring means the player is never asked to multi-touch; their finger is on the LME drag while the spoon stirs by itself.

**Outcome computation:** modifies several variables of the brew:
- `risk_profile.scorch` — 0 if burner was off (step 1 done) and the spoon was already stirring (step 2 done before step 3). Otherwise scales with seconds-of-direct-LME-on-hot-burner.
- `lme_dissolution` — 0.6 to 1.0 based on the LME drag's gesture quality (smooth + slow = full dissolution; jerky or fast = partial). Affects OG (undissolved LME doesn't contribute to gravity).

**Failure modes:**
- LME dropped without burner off → SCORCH event. `risk_profile.scorch += high`. Visible: dark patch in kettle. Off-flavor in finished beer.
- LME dropped without spoon already stirring → puddle on bottom, slow dissolution → `lme_dissolution = 0.7`. Lower OG.
- LME poured slowly with smooth gesture, burner off, spoon already in autonomous stir → ideal. `lme_dissolution = 1.0`. No scorch.

##### Mini-game #5 — Bring to Boil (Step 6 of brewing day)

**Sub-actions:**
- Set burner heat (HIGH/MED/LOW)
- Watch for hot break (visual cue → tap to acknowledge → starts the 60-min timer)
- Optionally adjust heat as needed (more taps during the boil)
- Pay attention during the boil — eyes off the foam climb or off a hop addition's window has consequences. (Closing the app pauses the scene cleanly; see Section 4.1. The risk is in-scene inattention, not real-life breaks.)

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

## Section 4 — Time, Concurrency, Conditioning

This section formalizes how time advances, how multiple brews coexist, and why conditioning is structurally different from fermentation. Equipment-as-scheduling-constraint detail, the cleanliness state machine, and anomaly-generation rules are queued for a later pass within Section 4.

### 4.1 Two clocks

The game runs on **two independent clocks** that never overlap.

**Scene clock.** Active inside mini-game scenes only — brewing-day stages (mash, boil, transfer, etc.) and bottling. Real-time at scene-defined pace, with event-driven acceleration: time accelerates aggressively between events and slows as events approach. A 60-min boil renders the quiet middle in seconds and the hop-addition windows in real-time.

Closing the app **pauses the scene cleanly.** The brew freezes. No real-world clock ticks. Returning resumes exactly where the player left off. Consistent with Tenet 5 and Section 0's "everything happens at your pace."

In-scene inattention — eyes off the foam climb, missing a hop drop's actual window — *does* have consequences. The discipline is "during play," not "between plays."

**Day clock.** Advances one in-game day per "Get some rest" tap on the dashboard. The day clock is **global** — every active fermenter, every conditioning batch, every calendar deadline, every social/news/forum content pool ticks together. There is no per-brew day clock.

The two clocks never overlap: while a scene is active, the day clock is paused. While the dashboard is open and rest hasn't been tapped, the scene clock is paused.

### 4.2 Concurrency and slot occupancy

A brew progresses through three slot states:

| State | Occupies |
|---|---|
| Brewing day (mash through cool) | Active scene (no fermenter yet) |
| Pitched, fermenting | One fermenter |
| Bottled, conditioning | One conditioning rack slot (does NOT occupy a fermenter) |

The key consequence: **once you bottle, the fermenter is free.** You can start the next brew the same in-game day. The bottled batch progresses passively in the rack while the next batch ferments.

**Equipment as a scheduling constraint.** How many fermenters you own = how many parallel fermentations you can run. At apartment scale this is one. At garage scale, multiple. At pro scale, many in parallel. The conditioning rack at apartment scale is implicitly 1–2 batches' worth of bottles (24–48 12oz bottles); upgrading bottle storage / kegging changes this.

**Brewing-day requires a free fermenter at start.** The player can't begin a brewing-day scene unless at least one fermenter is free at the moment they tap **Start brewing** — even though the fermenter isn't physically used until pitch time several scene-steps later. The "at-start" rule trades a bit of realism (an expert juggler could in theory queue up a brew to pitch the moment another finishes) for a much simpler UX: no committing to a brewing day with no destination, no failure state of "your wort is cool but there's nowhere to put it." Real experienced homebrewers plan this way too.

#### Bottles as a tracked inventory

Bottles are a real consumable, not handwaved. The starter kit ships with **24 12oz bottles**; a 5-gallon batch fills exactly that. Bottles in the conditioning rack or storage closet are *in use*; bottles already drunk/sold/returned are *available*. Bottling consumes available bottles; bottles return to availability as conditioned beer is drunk, sold, or given away. Running low surfaces a soft cue ("you're low on bottles") in the morning summary; hitting zero hard-blocks the next bottling until the player frees some up.

Recovery options are realistic:
- **Drink some down.** The beer is yours; you can pour and drink without scoring weight beyond Palate XP (treat as an informal Pour & Taste). Returns one bottle per pour.
- **NPC asks for beer.** Marcus, Mom, etc. occasionally request bottles — story moments that consume bottles for relationship gains; the NPC returns empties over the following in-game week or two.
- **Customer sales / gifts.** Bulk bottles out of inventory; empties may or may not return depending on the customer (locals return; bar accounts don't).
- **Buy more.** The shop carries a case of 24 empty bottles for ~$12 (final pricing in Section 5).

The keg upgrade in 4.4 collapses this whole subsystem; the bottle-inventory pressure is therefore an apartment-scale-and-early-garage-scale concern by design.

#### Daily checklist fan-out

The day clock is global (4.1), but the checklist is per-brew. Each **active fermenter** contributes its own line ("Check fermenter — Pale Ale, day 3/5"); conditioning batches don't add lines (per 4.3, the rack is the passive surface). At apartment scale this is at most one entry. At garage scale with three fermenters, three entries — correct, because three parallel brews IS more daily work, and that's a chosen consequence of scaling up. Anomalies are per-brew (a cold spot affects whichever fermenter is in the cold spot, not all of them; an infection scare on one batch doesn't taint the others).

When no fermenter is active (between brews), the brewing section of the checklist quiets entirely; the day's content shifts to phone, forum, news, social, and shop browsing — the canonical onboarding window from 4.5 happens organically here as well as during the first conditioning period.

(Detailed per-equipment scheduling rules — kettle / spoon / capper cleanliness gating, how soiled equipment delays the next brewing day — are filled in alongside the equipment property-bag formalization later in Section 4.)

### 4.3 Conditioning is passive

Fermentation **earns** its day-by-day rhythm: airlock patterns to read, anomalies to potentially catch, a "when to bottle" decision. Each day has potential signal. Conditioning doesn't. After Day 2 — priming sugar dissolved, no leaks visible, sediment dropping — nothing changes inside a sealed bottle until carbonation completes. A daily-check UI would be lying about there being something to do.

Conditioning is therefore a **passive progress bar**, not a daily-rhythm system. The dashboard shows the brew with a "Ready in N days" indicator and the conditioning rack visible. The day clock advances the bar with every "Get some rest" tap; no daily checklist entry, no nag.

The rack is **passively informative.** If a bottle gushes, leaks, or breaks, the player sees it on the rack — sediment puddle, missing bottle, hairline crack. No checklist prompt; the player notices in passing or doesn't. (Tenet 4: ambient cue, no auto-disclosure.)

Two optional player interactions during conditioning:

- **Open a tester bottle** (any time). Costs 1 bottle from the batch. Calls Palate skill. Returns:
  - **Carb level** — under / about / over. Reading is fuzzy at low Palate ("flat-ish, will need more time"); precise at high Palate ("about 4 days out from where you want it").
  - **Flavor-so-far** — limited at low Palate ("tastes like beer"); more legible higher up.
  - New brewers will misjudge. A tester at day 7 of a 14-day condition often reads "still flat-ish" even when the bottle would be drinkable at 10. Tasting too early and concluding "needs another two weeks" is a common first-brewer mistake; so is sampling once and never again, missing the fact that priming was heavy and the bottles are over-carbing toward gushers.
- **Skip to ready** — fast-forwards the day clock until the recipe's `condition_days` target lands. No risk roll attached. Quietly subordinate to other things happening in the world: if any other active brew has a daily event pending, the skip stops there; otherwise it rips.

Conditioning anomalies — gushers, bottle bombs, leaks, oxidation, under-carb — are **baked in at bottling time** (priming sugar quantity, sanitation state, capper quality, fill level, oxidation during transfer). They are *not* generated as daily rolls. The dice were rolled when the bottles were sealed; the conditioning period is just where the result becomes legible. This is faithful to real homebrewing: a bottle is either going to gush or not based on what went into it.

### 4.4 Conditioning at garage scale and beyond

Bottle conditioning is slow because it's slow in real life. **Keg + CO2 force-carbonation is the conditioning-killer.** When the player unlocks a corny keg (and a CO2 tank to drive it) at garage tier, three problems collapse at once:

1. **Conditioning** compresses from ~14 days to ~24–48 hours of force-carb.
2. The **bottle-inventory bottleneck** (4.2) evaporates — kegs hold the beer, bottles stay free for the batches that still want them.
3. The **bottle-fill and cap mini-games** are skipped on kegged batches; bottling day collapses to a single transfer + force-carb action.

This is a tangible "I leveled up my brewery" beat — the player feels their release cadence accelerate from monthly to weekly *and* their post-fermentation labor drop from ~5 minutes per batch to under a minute. Conditioning is intentionally slow at apartment scale to make this upgrade feel powerful. Don't fix conditioning; let the keg fix it.

### 4.5 The first-brew implication

The player's *first* brew is the only time conditioning is the dominant activity in the game world. There is no second brew running in parallel; the fermenter has been emptied and the next brew hasn't been planned yet. ~14 days of dashboard with one passive bar would be dead air.

The first conditioning period is therefore the **canonical onboarding window for non-brewing systems:**
- Forum reading and Knowledge XP intro
- Shop browsing — planning brew #2's ingredient list, eyeing first equipment upgrades
- Calendar gets populated with Tim's tasting and Mom's stout-order
- More NPC chatter (Marcus's party comes and goes; Tim's brewing-club follow-up; first hint of broader community)
- News and trend signals begin appearing

The player isn't waiting on beer — they're meeting their world. By the time those bottles are ready, the player has a planned next-brew, a calendar with deadlines, an active forum thread or two, and is ready to brew again. The 14 dead days become 14 onboarding days.

From brew #2 onward, the issue evaporates. The player's natural cadence is brew → ferment → bottle → start next brew → ferment while bottles condition. Conditioning days are always shared with active fermentation or active brewing-day prep, and the global day clock means a single "Get some rest" tap advances both batches.

### 4.6 Real-time engagement per brew, apartment scale

| Phase | Real-time engagement |
|---|---|
| Brewing day (active scene) | ~10 minutes |
| Fermentation (5–10 daily taps × ~90s) | 8–15 minutes |
| Bottling day (active scene) | ~5 minutes |
| Conditioning (passive bar; 0–2 optional tester probes) | ~1–2 minutes |
| Tasting (active scene) | ~2 minutes |
| **Total per brew** | **~25–35 minutes**, distributed across ~20–25 in-game days, played across however many real-life sessions the player chooses. |

### 4.7 Commitments and the Calendar

Commitments are time-bound contracts the player accepts: a friend's tasting in 14 days, an order due in 21 days, a competition entry deadline in 30. They live in the Calendar app (1.4), produce countdown surfaces, and **have specified consequences for being missed** — they are not flavor.

#### Five commitment types

| Type | Example | Cash | Reputation | Recoverable? |
|---|---|---|---|---|
| **Social** | Tim's tasting; a Marcus party invite | None | Mild relationship hit if you skip; mild friction if you show empty-handed; relationship gain + Palate XP if you show with beer | Easy |
| **Friend order** | Mom's stout; Marcus's batch for parties | Cash on delivery | Relationship hit if missed; cash forgone | Easy |
| **Customer advance** (garage tier) | Bar owner pre-pays for a keg | Advance taken upfront; clawback on miss | Relationship hit + reputation ding | Moderate |
| **Bar account / wholesale** (pro tier) | Standing order, monthly delivery | Hard contract; clawback + possible penalty | Reputation hit + account may close | Hard |
| **Competition entry** | Regional homebrew comp deadline | Entry fee paid upfront; non-refundable | None (just disappointing if forfeit) | N/A — deadlines are deadlines |

#### Renegotiation

Most commitments can be modified proactively: the player taps the calendar entry, opens a message thread with the counterparty, and asks for an extension or apologizes preemptively. Different NPCs grant different latitude:

- **Mom**: very forgiving; grants extensions readily, often with a soft remark ("oh honey, take your time")
- **Marcus**: forgiving; may negotiate small concessions ("alright but you owe me first dibs on the next IPA")
- **Tim**: friendly; reschedules if asked
- **Local bar owner**: businesslike; short extension possible with a goodwill cost (slightly lower payout, or a free sampler for the bar)
- **Competition entries**: zero — deadlines are deadlines, no extensions, no exceptions

Proactive communication universally softens the consequence vs. silent miss: a 2-day-late delivery with a heads-up text the day before is forgiven; the same delay in silence isn't.

#### Pre-flight info at acceptance

When the player accepts a commitment, the calendar surfaces an info line:

> *"Earliest possible delivery for a Dry Stout given your current equipment: 24 days. You committed to 21."*

This is **information, not a block**. The player can still accept commitments they cannot fulfill on time — that's a real choice. The Day-3 Mom's-stout-in-21-days beat in Appendix B is the canonical example: it's a stout (10 ferment + 14 condition = 24 days minimum) with a 21-day deadline. The player either:

- Accepts and plans to renegotiate later (proactive comms → mild dip)
- Accepts, brews, delivers 3 days late silently (bigger dip, but no permanent loss at apartment scale because it's Mom)
- Declines politely (no commitment, no consequence — just no birthday stout for Dad and a small relationship-warmth missed beat)

This is intentional teaching: real homebrewers learn to say no to deadlines they can't hit. The game lets the player learn the same lesson via real, recoverable consequences at apartment scale before garage-tier commitments make those consequences harder to recover from.

#### Calendar surfacing

- **Calendar app** shows all open commitments with countdowns ("Mom's stout — 18 days").
- **Morning summary** at T-3 days mentions the upcoming commitment as ambient context ("Dad's birthday is Saturday").
- **Daily checklist** at T-1 day promotes the commitment to a line item with the ❗ flag from 3.7's discovery model — a *decision*, not a problem.
- **On the deadline day**, the commitment shows as a top-level dashboard prompt; failing to act on it that day = silent miss.

#### Save schema implications

Each open commitment persists as a record: type, counterparty, deadline, payment-state (paid-up / advance-taken / nothing-paid-yet), required deliverable (style + minimum-quality?), and renegotiation history (any extensions previously granted). On miss, the consequence record fires (cash adjustment, relationship adjustment, reputation adjustment) and the commitment closes. Section 8 folds this in.

---

## Section 8 — Save Schema Outline

This is the **outline level** — what entities the save needs to persist, the prestige boundary, save cadence, and constraints on the persistence-tech choice. The full schema (field types, table layouts or JSON shape, migration story) is the next pass; this stub locks in the shape so the tech decision (Godot resources vs. JSON vs. SQLite) follows from the schema, not the other way around.

### 8.1 Twelve entity groups

The save persists twelve groups of state. The groups are derived from decisions in 1–4 + 8–9; whatever Sections 5–7 land later will refine but should not contradict the shape below.

1. **Player meta.** Save format version (for migrations), prestige count, current destination ID, settings (audio, visual, control preferences).
2. **Cash & finance** (per 2.6). Cash balance; outstanding loans (Marcus's apartment-tier bailouts with their explicit terms — bottle owed, party promised, etc.); customer advances (counterparty, amount, delivery deadline, deliverable spec); recurring bills at higher tiers (rent, distribution fees).
3. **Skills** (per 3.4). Six axes each with: current level, current XP, XP-to-next-level, unlocked-flag (Water Chemistry's flag flips when a pH meter is acquired). Per-axis history of when interactions snapshotted them is part of the brews-in-flight record (not duplicated here).
4. **Equipment** (per 3.2). List of owned equipment items, each with: type ID, full property bag, current cleanliness state, decay counter, date acquired (used by the journal-as-memorial across prestige).
5. **Inventory** (per 4.2 + Appendix A). Ingredient quantities (LME, hops by variety with freshness, yeast packets by strain, priming sugar, water chemistry additions); bottle counts (available / in-use); consumables (Star San, ice, towels, etc.).
6. **Recipe knowledge** (per 2.4 + 3.6). Map of recipe IDs → unlocked + brewed-count + best-grade; player-invented recipes (full recipe definitions); the one pinned recipe that carries forward on prestige.
7. **Brews in flight** (per 4.2 + 4.3 + 3.9). Active BrewState records: ID, recipe snapshot, equipment-used snapshots, current stage (brewing-day / fermenting / conditioning), per-stage outcomes from completed mini-games, **per-interaction skill snapshots (per #6)**, day-clock entry/exit timestamps per stage, accumulated risk profile, days elapsed in current stage, anomaly state attached to the brew.
8. **Brewing journal** (per 1.5). Completed brew archive — every BrewState frozen with final grade + tasting notes + post-mortem narrative + NPC/competition feedback received. Past-breweries memorial section (read-only, persists across prestige per 2.4).
9. **NPCs & relationships** (per 1.3 + 2.7). Per NPC: relationship meter, outstanding promises ("owes Marcus 6 bottles"), preference data. Conversation history is *summarized* state (last interaction, last branching choice taken, key flags) rather than full transcript. Post-prestige, home-destination NPCs may persist as long-distance contacts that text occasionally per 2.3.
10. **Calendar / commitments** (per 4.7). Open commitments by type (5 categories from 4.7); past-commitment history kept for the journal/relationship record.
11. **Phone & world state** (per 1.4). Forum threads read / unread / @-mentions; news articles surfaced and read; social account followers + posts; current trends (style + multiplier + window); regional water profile and other destination context; shop browsing cookies (last viewed items, etc.).
12. **Anomaly / event RNG state.** World-day anomaly seeds so generated anomalies are deterministic per save (the cold-spot day from Appendix B Day 2 is generated against a saved seed, not re-rolled on reload); per-brew RNG state for in-flight drift rolls.

### 8.2 The prestige boundary

Each persistent field is tagged either `persists_across_prestige` or `per_career`. The split mirrors 2.4's table:

**`persists_across_prestige`:**
- Skill levels (with the 20%-of-levels-rounded-down penalty per 2.4)
- Recipe knowledge (which styles are mastered — but re-brewed once to "prove" it again)
- The one pinned recipe selected at prestige time
- Past breweries journal/memorial (read-only)
- Modest cash bonus ("you sold the brewery") — initial cash for the new career
- One mid-tier piece of equipment chosen at prestige time
- Prestige count

**`per_career` (resets on prestige):**
- Cash balance (replaced by the bonus above)
- Equipment owned (except the one chosen item)
- In-flight brews (ferment / condition all dropped)
- Customer relationships in the destination being left
- Recipe collection details (knowledge persists; specific saved variations don't)
- Skill-gated unlock state (re-unlocked through play)
- Open commitments
- World state (trends, calendar, phone state for the abandoned destination)

The home-destination NPCs are a special case (per 2.3): they may surface as long-distance contacts in the new destination — that's a small persistence carrying NPC IDs + summary relationship state, not the full per-NPC record.

### 8.3 Save cadence

- **Auto-save on every "Get some rest" tap** (the day-clock advance per 4.1 is a natural commit point).
- **Auto-save on scene-pause boundaries** when the player closes the app or backgrounds it during an active scene (the scene-clock pauses cleanly per 4.1).
- **No mid-scene saves required** — the scene clock is paused while the player is on a non-active screen anyway.
- **No manual save slot management** per 2.1 (one save per device).
- **Hard reset** (settings, double-confirmed per 2.1) wipes the per_career state and possibly the persists_across_prestige state too — TBD whether hard-reset preserves the prestige-count history or fully wipes; called out for Section 8's full pass to decide.

### 8.4 Schema characteristics that constrain the tech pick

The persistence technology decision (Godot Resources, JSON, SQLite, or a hybrid) is **not** made in this stub. It will be made in Section 8's full pass once these characteristics are weighed:

- **Large + structured.** Twelve entity groups, several with relations (brews ↔ equipment-used snapshots; commitments ↔ NPCs; journal entries ↔ recipes).
- **Journal grows monotonically.** Every completed brew adds an entry, never deleted. Over hundreds of brews, this could grow into the multi-megabyte range — relevant for whatever store we pick.
- **Read-on-load, write-incrementally.** Most data is loaded once at game-start and updated by event. Not heavily transactional.
- **Mix of small flat fields and structured records.** Settings, cash, skill levels are simple; brew archives and equipment property bags are nested.
- **Deterministic replay friendly.** RNG state is part of the save, so "load this save and play forward" produces the same anomalies. This rules out tech choices that can't preserve seed state cleanly.
- **Migration story matters.** Save format version is tracked from day one so future schema changes can migrate forward (a player who started on v0.2.10 should still be able to play on v0.5.x).

The tech decision in Section 8's full pass weighs these characteristics against Godot 4.3's idiomatic options (Resource serialization, FileAccess + JSON, SQLite via GDExtension) and picks one. This stub commits to the schema shape; the next pass commits to the encoding.

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

# What's next

What's landed so far:

- Sections 0–3 (Vision, World, Player Journey, Brewing Mechanics)
- Section 4.1–4.7 (Two clocks; concurrency + brewing-day-start rule + bottle inventory + checklist fan-out; conditioning model; triple-good keg unlock; first-brew onboarding window; per-brew real-time totals; commitments and Calendar)
- Section 8 (Save Schema Outline — entity groups, prestige boundary, save cadence, tech-pick constraints)
- Appendices A and B

Still queued, in roughly the order they need to land:

- **Rest of Section 4 — Equipment scheduling rules, cleanliness state machine, anomaly generation.** Full equipment-as-scheduling-constraint specification (when slots clear, what shares with what, how cleaning state gates re-use). The cleanliness state machine for every piece of equipment. Anomaly generation rules (how the world decides "today, the radiator is off") and how those anomalies attach to in-flight brews.
- **Section 5 — Economy & Progression.** Ingredient pricing, equipment cost curves, customer payouts, competition prizes, bankruptcy thresholds, trends-system mechanics. Builds on the "economy load-bearing from day one" decision in 2.6.
- **Section 6 — UX/UI.** Dashboard layout, brewery view, phone overlay, time control, handbook, recipe view, mini-game scene templates.
- **Section 7 — Technical Architecture.** Autoload inventory, scene graph, time service, content-pool generator, calendar service, save service.
- **Rest of Section 8 — Save Schema (full pass).** Persistence-tech pick, field-level schema, migration story, prestige reset implementation. Builds on the outline in 8.1–8.4.
- **Section 9 — Mini-Game Build Plan.** All 12 v1 mini-games specified at Section-3.9 level of detail (sub-actions, drift formulas, downstream effects). Build order. v2+ mini-games queued.
