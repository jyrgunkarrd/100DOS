# Battlefield inspection and actions

Right-click an exposed part of a hex or its army label for a read-only force
breakdown, printed battlefield talents, and allied protection. Inspection works
in deployment, mission action, and Agent action and never spends AP. Enemy
portraits are on the left, allied portraits on the right; identical types are
grouped with quantities. The JACL is inspectable but has no army label.
Map protection appears as `P <value>` in the allied color, centered on the allied
army value. It sits below below-hex labels and above above-hex labels, keeping
army values closest to their hex. Zero protection is hidden. Right-clicking
the protection row also opens inspection.
Inspection keeps exactly two portrait columns, enemies left and allies right.
While it is open, the mouse wheel scrolls both columns together; headings stay
visible and the wheel does not scroll the hand or other panels underneath.
Portraits retain their native size, and the location heading uses Not Jam UI 12
at 12 px. The panel stays open as the pointer moves. Left-click or right-click
anywhere in the game to close it. That click is used only for dismissal.

With an active Agent, open ACTIONS (or press A), then BATTLEFIELD. Each confirmed
attempt costs 1 AP and discards committed cards, whether it succeeds or fails.
Cancel with Escape, right-click, or the dialog cancel button before confirming
to spend nothing. Card commitments and Fate draws reuse the existing test system.

- ENGAGE requires allied and enemy forces. Pick a printed battlefield test.
  Each army deals its starting strength divided by 2, rounded down. Allies only
  deal damage on a successful test (including ties); enemies always deal damage.
  Both amounts are fixed before casualties, so a destroyed army still retaliates.
  Test margin does not increase damage. Automatic success/failure only controls
  whether allies deal damage; there is no special damage bonus. Strength 1 deals
  zero damage. Both armies can be destroyed in the same exchange.
  Each unabsorbed damage removes one force, regulars before elites, in stable
  instance order. Elite removal costs one damage and reduces army strength by 2.
- ENTRENCH requires allied forces and less than 4 protection. Test difficulty is
  printed value minus 2, floored at zero. Success adds 2 protection, capped at 4 per location; failure
  leaves it unchanged. Protection absorbs allied army damage one-for-one,
  persists across turns, and stays at the location when forces move.
- MANEUVER rolls the Agent location's unmodified battlefield test first. Success
  grants one pending Force transfer: move a local allied Force to an adjacent
  location (including JACL), or reinforce the Agent's location from JACL regardless
  of adjacency. Failure opens no selection panel and moves nothing. Transfers
  preserve the Force instance, have no destination capacity limit, and never move
  the Agent or location protection.

ENGAGE and ENTRENCH do not provoke opportunity attacks. MANEUVER does, using the
existing engaged location-card enemies. The test and opportunity-attack feedback
finish before selection opens. Agent defeat discards the pending maneuver. Battlefield
damage affects armies, not Agent health. Agents standing at JACL instead use the tested Bombard, Security, and Triangulate
actions described in [JACL actions](jacl-actions.md).

## Clashes

Every committed reveal of a Fate tile with `clash` adds that tile's batch to
the Agent's current location. The red `C <count>` label uses the Protection
row on the enemy side and opens inspection on right-click. JACL
displays the count inside its hex because it has no army label.

Done starts a required ENGAGE test at the Agent's current location while both
armies have Forces and a printed battlefield test is available. Choose a test
and optionally commit cards. Each confirmation consumes one point from the
oldest batch and costs zero AP. `en_bonus` increases the test difficulty.
`en_dmg` increases enemy damage before Protection absorbs it. Each test
uses the modifiers of its own batch and resolves the regular army exchange
and milling effects.

After feedback, the next test uses the remaining armies. A new clash reveal
joins the back of the same sequence. An empty queue or unavailable engagement
ends the sequence. Untriggered points stay at the location, including on JACL.
The usual Done-triggered location-enemy attacks occur once, after the sequence.

`battlefield_clashes` owns the per-location queues. `agent_turn` tracks the
pending end of the turn. The shared battlefield action stages the exchange,
milling, and Fate reveal before committing the test and consuming its point.

## Data and ownership

`data/battlefield_rules.lua` controls AP cost, action difficulty adjustments,
protection gain/cap and Engagement damage settings. `data/attack_rules.lua` owns the explicit
opportunity-attack policy. `data/battlefield_view.lua` controls inspection
layout, colors and portrait directory.

Location `battlefield_talent` arrays contain `{ type = "steel", qty = 3 }`
entries. These are validated during deployment; JACL may omit the field.
The resolved location catalogue travels with the mission session.

Force portraits resolve to `assets/images/forces/<id>.png` by default. Optional
`portrait = "filename_stem"` selects another subject image. Existing `card_bg`
and `card_fg` fields select artwork overrides; missing fields inherit the mission
biome layers and `"none"` disables a layer. The shared artwork cache owns images.
Missing subject images render a placeholder. Force descriptive abilities are not
executed by this foundation.

`battlefield_state` owns damage, protection, transfers and revisions. Army
containers persist when empty; original army templates describe their origin,
not their current contents. Mutations preserve global force instance identities,
recompute strength/counts and increment location and army revisions. Labels use
these revisions to refresh without rerolling anything.

`battlefield_action` validates and stages work through `agent_action_resolution`.
It rejects changed positions, AP, hands or battlefield revisions before drawing
Fate or publishing changes. `talent_commitments` shares card validation between
battlefield and existing location-card tests. The talent-test dialog and result
presentation accept battlefield context without treating the location as a card.

Run `love . --test` for rules and interface integration checks. Battlefield
screenshots in `tests/battlefield_*.png` show inspection, JACL reserves, maneuver
selection, talent selection and outcomes.

## ENGAGE army cut-in

ENGAGE presents the enemy army on the left and allied army on the right. Each
Force instance occupies one native-resolution portrait in a mirrored diagonal
stack. Spacing compresses as armies grow; portraits are never reduced to fit the
cut-in. This uses native pixels on the game's 1280-by-720 virtual canvas, which
still scales with the rest of the game when the window is resized. Elites draw
above regulars, with stable ordering inside each rank. Headers show exact Force
counts and army strength even when individual stack edges overlap.

Each panel receiving positive damage shudders and flashes at impact, with a
directional attack streak from the opposing army. Zero-damage exchanges show
0 DAMAGE without an impact or casualty animation. Both sides report incoming
damage and actual losses; allies also report absorbed damage. Allied protection pulses before casualties begin.
Removed Forces lift toward the center, above their own stack, pause briefly for
recognition, then flash, collapse and fade. The configured `assets/audio/sfx/def/expl.wav` explosion plays once at the first
casualty destruction when either army loses a Force, including in reduced motion.
Fully absorbed damage and zero-casualty exchanges do not play it.
Both casualty sequences run concurrently, with
protection delaying only allied casualties. Feedback waits for the longer sequence.
Removal follows the existing rules
(regulars before elites), independently of stack draw order. Survivors keep their
slots until all casualties finish, then settle together. Large casualty sequences
use a bounded stagger. A defeated army's empty panel receives the existing defeat
scan and fade; the shared result retains its defeat label. Reduced motion uses
tint and opacity changes without slide, shake, collapse or moving scan lines.

`src/sys/battlefield_engagement.lua` calculates both incoming damage amounts from
starting strengths, then applies them through `battlefield_state`. The divisor,
rounding and allied success requirement live in `data/battlefield_rules.lua`.
`battlefield_engagement_record` copies both armies around the committed exchange
and stores damage, absorption, copied casualties and defeat flags per receiving
side. Playback reads these snapshots and never applies damage. Either or both
panels can play their defeat scan; test success remains distinct from army survival. The existing
talent feedback controller retains Fate reveal/audio and selects the army view
only for ENGAGE; ENTRENCH, MANEUVER and character combat keep their existing views.
`src/ui/army_stack_layout.lua` owns stable stack placement, and
`src/ui/battlefield_engagement_cutin.lua` owns presentation and casualty timing.
`data/battlefield_engagement_view.lua` controls stack bounds, offsets, casualty
timings and labels; entrance, impact and defeat styles inherit combat settings.
Force artwork uses the existing shared cache, including layered opacity and
missing-art placeholders, and is released with the feedback view.

`tests/battlefield_stack_*.png` cover normal and large stacks, casualties,
protection, both army defeats, missing artwork and reduced motion. `tests/battlefield_exchange_*.png` additionally cover two-sided
casualties, mutual destruction and zero damage.

## Deployment and Move comparison

Starting a deployment drag or selecting MOVE displays battlefield comparisons
inside the hexes. Location art is dimmed and map Agent portraits are hidden;
the roster, active Agent's large portrait, and dragged portrait remain visible.
Army/protection labels remain outside the hexes. Hold either Ctrl key to restore
Agent positions and normal artwork brightness without ending the drag or Move
selection. Release Ctrl to resume comparison. Battlefield inspection is unavailable
while dragging or choosing a Move destination. Escape, focus loss, or completing
the action removes the overlay.

Each native 32-by-32 talent icon has `Agent score / printed difficulty` beneath
it. Three tests form two icons above and one centered below, in definition order.
One or two tests use a centered row. The current hex layout supports up to three
tests per location; additional tests require a layout change rather than being
silently omitted. Green values exceed the test, amber equals the test,
and muted red is below the test. Scores reuse the talent-test base calculation
and exclude committed cards, Fate, and ENTRENCH's difficulty adjustment.

The best match is the highest individual talent margin available at a location.
Gold inner outlines and BEST mark all tied best legal destinations, even if
every margin is negative. During MOVE only destinations allowed by the existing
Move rules can win; other locations still show muted comparisons. The current
location is not a destination. Cyan outer outlines retain the legal Move targets,
including while Ctrl is held. JACL displays NO BATTLEFIELD TESTS and cannot win
the talent comparison, but remains a legal destination when appropriate.

`src/sys/battlefield_comparison.lua` builds read-only comparisons from explicit
eligibility. `src/ui/battlefield_comparison.lua` renders them using the shared
artwork cache. `data/battlefield_comparison_view.lua` owns spacing, icon paths,
colors, dimming and the legend. These views are state-owned and released when
leaving deployment or Agent action; they never change placements or spend AP.


## Test-first MANEUVER selection

After a successful test and opportunity attacks, the native-resolution Force tray
opens below the map. Click a local Force, then a highlighted adjacent hex to move
it. Wheel scrolling over the tray and its arrow buttons reveal more Forces;
scrolling elsewhere does not move the tray or the hand beneath it. The map uses
Agent movement highlight styling with Force-specific eligibility, without the
pre-test talent comparison overlay.

A steady gold JACL outline and a small square count badge indicate available reserves. With no Force
selected, click JACL to show its Forces; clicking a reserve Force immediately
reinforces the Agent's current location. Clicking the Agent's current hex returns
to local Forces. If no local Forces exist, the tray opens directly on reserves.
With a local Force selected, clicking a legal JACL destination transfers that
Force to JACL instead. Hover instructions distinguish these actions.

Escape or right-click clears selection without discarding the paid success.
DECLINE MANEUVER explicitly abandons it, without refunding AP or committed cards.
Other actions and ending the turn are blocked during the pending choice. A success
on the last AP remains usable. Focus loss clears pressed inputs and preserves the
choice. The pending transfer revalidates Agent position, ownership, army revision,
Force identity and destination, and can be consumed only once.

The transfer commits before visual playback. A portrait flies from its tray slot
to the destination, with a brief arrival pulse; army-label changes appear on
arrival. The tray stays open and ignores additional input until playback finishes.
Reduced motion fades the departure portrait and pulses the destination instead.
Interrupting playback cannot repeat or undo the committed transfer.

`src/sys/battlefield_maneuver.lua` owns the pending choice and transfer validation.
The reworked `src/ui/battlefield_action_panel.lua` owns the scrolling tray and
selection input. `src/ui/battlefield_maneuver_overlay.lua` draws map guidance, and
`src/ui/force_transfer_feedback.lua` owns the departure/arrival animation and
presentation-only army-value overrides. `data/battlefield_maneuver_view.lua`
controls geometry, colors, copy and timings. Artwork, map hit-testing and transfer
rules reuse the existing modules. Screenshots in `tests/battlefield_maneuver_*.png`
and `tests/battlefield_reinforcement_flight.png` cover selection, reserves,
scrolling, movement and reduced motion.

## Maneuver and Entrench success treatment

Successful MANEUVER and ENTRENCH tests apply the shared teal encounter scan to
the location result panel. During the first 0.35 seconds, location art crossfades
into `assets/images/cards/card_vfx/maneuver.png` or `entrench.png`. Content fades
from 0.35 to 0.56 seconds, then the frame fades through 0.7 seconds. The location
name remains during the crossfade and the result summary remains until feedback
exits. Automatic successes use the same treatment; failures retain their feedback.
Reduced motion replaces the moving scan with a stationary teal wash and retains
the opacity transition. Missing VFX art retains location art through the scan/fade.

`data/card_outcome_vfx.lua` defines profiles and Battlefield artwork mappings.
`src/sys/card_outcome_vfx.lua` validates and resolves them from committed results.
`src/ui/card_outcome_vfx.lua` shares scan/fade and crossfade rendering with encounter
feedback. Images use the shared artwork cache. These modules never change game
state; Maneuver selection still waits for test feedback and opportunity attacks.
`tests/card_outcome_vfx.lua` covers both actions, phases, reduced motion, missing
art, automatic success, failure, and cleanup; screenshots use `_vfx_` filenames.

## Encounter milling after Engagement

Each enemy Force eliminated by ENGAGE mills one card from the top of that
location's encounter draw pile into its discard pile, up to the cards remaining.
Regulars and elites each count once. Excess damage grants no extra milling;
mutual destruction still grants milling for the actual enemy casualties.
Milled cards never enter play, trigger encounter effects, engage an Agent, or
change cards already in play. Empty decks never reshuffle.

The configured `assets/audio/sfx/mill.wav` cue plays once when the milling
presentation starts, including its empty-deck result.
After the army result, a brief deck-to-discard procession shows the milled artwork,
card names, total milled and remaining deck count. Artwork is drawn at its native
176x176 or 192x192 resolution with nearest filtering and integer coordinates.
No card is shrunk to fit. The procession uses a bounded stagger (at most 0.48s),
0.72s per-card overlapping motion and a 0.26s final hold, followed by the usual
feedback exit. Reduced motion uses opacity changes in place. Missing artwork
retains the card name and a placeholder. No eliminations add no extra beat;
eliminations against an empty deck show a short DECK EMPTY result.

The location exploration panel's LAST MILL button opens a read-only receipt.
It lists names and duplicate quantities, supports wheel scrolling, and previews
full-resolution artwork on hover. Click REVEALED to return to the active encounters.
Receipts belong to each location and persist across Agent changes and movement;
the next Engagement at that location replaces its receipt, including a zero-card
result. Exploring returns to the revealed-card list. Receipt clicks never open
a talent test or activate a discarded card.

`data/battlefield_rules.lua` owns `cardsMilledPerEnemyEliminated`.
`location_decks.prepareMill` stages top-card removal and discard insertion;
`commitMill` validates source/revision and rejects repeat commits.
`battlefield_engagement.prepare` resolves damage on detached army containers.
`battlefield_action` prepares both possible test outcomes and their milling before
Fate, validates both sources, then publishes only the selected army/deck outcome
along with normal action costs. Results contain detached ordered milling receipts.
Playback reads those results and cannot mill again, even if interrupted.

`data/location_milling_view.lua` controls presentation geometry and timing.
`src/ui/location_milling_feedback.lua` owns native-size animation and cached art.
The existing talent feedback controller sequences it after the army result; the
existing exploration panel owns receipt input and uses the existing card preview.
The location preview reserves 192px of artwork space to avoid shrinking the larger
encounter images. `tests/location_milling.lua` and the Battlefield rules tests
cover deck order, empty/partial decks, stale and repeated commits, mutual losses,
read-only receipts, scrolling, interrupted playback, and native-pixel rendering.
Screenshots are saved as `tests/location_milling_*.png`.

## Maneuver destination and reserve markers

Hovering a legal destination with a local Force selected shows a fixed 12x12
teal square. A concentric square outline expands to 44x44 and fades over a
0.9-second cycle; the solid square never grows or shrinks. Coordinates and sizes
are snapped to the virtual pixel grid.

JACL reserves appear as a gold number inside a dark 22x22 square, centered five
pixels above the hex's bottom edge. The number counts available Force instances,
not army strength. Larger numbers expand the square equally in both dimensions
without shrinking text. Zero reserves hide both badge and availability outline.
A gold hexagonal ring expands eight pixels beyond JACL over 1.15 seconds, then
rests until the next 1.5-second cycle. The steady gold outline remains visible.
When JACL is also a legal destination, its teal target outline remains and the
steady gold outline is inset three pixels. Badge and availability pulse remain
visible; selecting a local Force still makes a JACL click move that Force there.

Reduced motion retains the small teal square, reserve badge and steady outlines
without expanding rings. All markers disappear during transfer playback and
when the Maneuver tray closes. No transfer rules or hit targets change.
`data/battlefield_maneuver_view.lua` owns marker and pulse settings;
`src/ui/outline_pulse.lua` shares outward square/hex pulse geometry and opacity.
The existing overlay composes these indicators and the panel validates settings.
`tests/maneuver_markers.lua` checks pulse phases, fixed marker dimensions, badge
placement and overflow, combined destination/reserve visibility, and reduced motion.
Screenshots are saved as `tests/maneuver_markers_*.png`.
