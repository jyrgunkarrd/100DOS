# Talent tests

During Agent Action, click a revealed location card at the active Agent's
location, choose a test, and optionally click highlighted hand cards to commit
them. Click a selected hand card again to undo the commitment. Confirm with
the **>** button to perform the test for 1 AP. The red **X**, Escape, or right-click closes the selection
without spending AP, discarding cards, or drawing fate. Tests remain inspectable
at zero AP; confirmation explains why the action is unavailable.

The test panel scrolls when a card has more than three choices. The hand retains
its existing scrolling. While selecting commitments, normal hand-card dragging
and other actions are suspended. After confirmation, other actions and ending
the turn remain blocked until the test and any opportunity attacks finish.

Test rows show the resolved talent icon outside the button, with `(STRIKE)` or
`(EVADE)` beside it for enemy tests. Click the icon/name area or the button to
select a row. Location and Agent mini-portraits head two fixed value columns:
the test difficulty on the left and the Agent's base talent on the right.
Values and interaction labels use uppercase Undead Pixel 8. Portraits remain
fixed as rows scroll; selected rows have a cyan border and subtle fill.
Committed bonuses are shown separately in the summary below the rows.

## Definitions

Location cards use `talent_tests`:

```lua
talent_tests = {
    { id = "strike", kind = "strike", val = 3 },
    { id = "evade", kind = "evade", val = 2 },
}
```

`id` identifies a choice on this card. `kind` determines its default talent and
outcome; `val` is its nonnegative integer difficulty. Strike defaults to Steel,
Evade to Fire. An explicit `talent = "reason"` overrides the talent without
changing the interaction's identity or effect. Non-enemy interactions use
`kind = "interact"` and an explicit talent. Existing `type` talent fields and
omitted IDs on ordinary interactions are accepted; new definitions should use
explicit IDs and `talent`.

`data/talent_test_rules.lua` owns the action cost, known talents, and test-kind
defaults. Strike and Evade are restricted to enemy cards. Enemy definitions
require positive integer health. Duplicate test IDs, unknown talents/kinds,
malformed arrays, and invalid difficulties are rejected. Preview labels and
the selection panel use the same resolved tests.

## Resolution

`Agent talent + matching committed talents + committed bonus tiles + signed fate value >= difficulty`
is success. Equality succeeds. `auto_success` and `auto_failure` override the
numeric comparison. A missing talent on an otherwise valid Agent is zero.

Each selected hand instance must contribute a positive matching talent. All
matching entries on every selected card are summed. Duplicate instances cannot
be committed twice; distinct copies of the same card can be committed. Committed
cards go to the Agent's discard pile on either outcome, with no printed resource
cost or card ability activation. Discards survive hand draws and activations;
there is no discard reshuffle rule in this increment.

Fate samples the pool's physical entries uniformly with replacement. Repeated
IDs retain their weighting. The pool never shrinks. Randomness is injectable
for tests and is consumed only during a valid action commit, after stale-plan
checks. Selection, previews, cancelled actions, and rejected commits draw no tile.

The existing action resolver prepares the action and validates mission, location,
Agent, and hand state. Publication spends AP, moves committed cards, applies the
outcome, and records feedback once. The animation reads that record and cannot
reroll or apply the action again.

## Outcomes and enemies

- Ordinary interaction success discards that location-card instance.
- Strike success deals 1 damage. Zero health discards the enemy and clears its
  engagement. Surviving enemies keep their remaining health independently of
  other copies and the shared definition.
- Evade success exhausts the enemy and breaks its engagement, including an
  engagement with a different Agent. Exhausted enemies cannot make opportunity
  attacks or engage Agents.
- Failure has no default target effect. AP and committed cards are still spent.

Any enemy at the active Agent's location can be targeted. Strike and Evade do
not provoke opportunity attacks. Ordinary interactions do, on success or
failure. Attackers are collected before the action, and attacks resolve after
it. Presentation shows the talent result before queued attacks, including when
those attacks defeat the Agent.

Exhausted enemies ready at phase refresh. Ready, unengaged enemies engage the
next Agent activated at their location. Location rows and hover previews show
current health and exhaustion; shared card definitions remain unchanged.

## Modules and presentation

- `talent_values`: validates and sums talent entries.
- `talent_tests`: resolves definitions and calculates outcomes.
- `fate_draw`: validates the pool and samples an entry without removal.
- `fate_reveal`: snapshots the committed tile's display data and stages its
  location effect.
- `location_card_state`: initializes enemy instances, readies them, and engages
  eligible enemies on Agent activation.
- `talent_test_action`: validates commitments and publishes the action through
  `agent_action_resolution`.
- `talent_test_panel`: selection and commitment UI.
- `talent_test_feedback`: fate reveal timing and result presentation, using the
  shared `attack_cutin` renderer.
- `fate_tile`: lays out the optional name, image, and signed value.

View settings live in `data/talent_test_view.lua`. The location card slides in
on the left and the Agent on the right. Once settled, a triangular wipe reveals
the fate tile from its bottom-left corner toward the right above
the cut-in; the tile stays fixed while a sharp-cornered halo expands and fades
in the result color (cyan for success, red for failure) before exiting. Successful Strike uses
the shared impact treatment directed at the enemy and the Agent's attack sound;
enemy defeat can play its defeat sound. At the fate reveal, successful Evade
uses simultaneous 0.3-second sweeps: cyan travels left-to-right across the Agent
card, and red travels right-to-left across the enemy card. Both cards remain
stationary and fully visible, without dimming or dissolving. The engagement line
splits and fades. Reduced motion substitutes brief cyan/red colour washes.
Ordinary success
sweeps a cyan highlight upward, fades the location card, and then fades its
frame over 0.35 seconds. Failure flashes the location frame red and gives the
fate tile two small horizontal jolts over 0.2 seconds; both portraits stay put.
Outcome durations and distances are in `data/talent_test_view.lua`.
Reduced motion follows `data/attack_cutin_view.lua`: displacement, the moving
sweep, the triangular wipe, and afterimages are suppressed. Colour changes and
fades remain, with a static fate glow. Gameplay resolution and audio timing are
independent of these visual treatments.

Lethal HP damage uses the ordinary upward sweep-and-fade treatment in red on
the defeated card: the enemy after a successful Strike, or the Agent after
retaliation. The damage impact completes first, then the 0.35-second sweep,
card fade, and frame fade play. The surviving card stays visible and the outcome
readout remains. Nonlethal hits and defeat through Defiance alone do not use
this HP-zero treatment. Reduced motion retains the red wash and fades without
the moving sweep. Timing is set by `defeatSweepDuration` in
`data/attack_cutin_view.lua`.

All tests play `success.wav` or `fail.wav` once, 0.1 seconds after the fate
result is revealed, including automatic outcomes. Paths and the reveal delay
are configurable in `data/talent_test_view.lua`; cues respect mission volume.

Retaliation uses each enemy definition's `atk_sfx` from `assets/audio/sfx/atk/`
at that attack's impact. If the impact defeats the Agent, their `defeat_sfx`
from `assets/audio/sfx/def/` plays at the same moment. Sounds are preloaded,
respect the mission volume, and play once per impact, including consecutive
attacks and frames spanning several impacts. Retaliation audio waits until the
talent-test presentation finishes. Missing sound metadata stays silent.

Later custom consequences and talent-changing abilities should extend named
test effects and talent resolution. Printed card ability text is not executed
by the commitment system.

## Verification

Ending an Agent's turn triggers one attack from each ready enemy still engaged
with that Agent, in engagement order. This costs no AP and works at zero AP.
Remaining AP are forfeited, and the Agent is exhausted. The existing attack
cut-ins, sounds, and defeat treatment finish before returning to mission actions.
Attacks stop if the Agent is defeated; exhausted or unengaged enemies do not attack.

Run `love . --test`. `tests/talent_tests.lua` covers math, automatic outcomes,
commitment costs, pool weighting, stale plans, repeated commit rejection, enemy
damage/defeat, Evade, opportunity attacks, phase readiness, and re-engagement.
`tests/talent_test_ui.lua` exercises actual selection/commitment clicks,
cancellation, zero-AP feedback, animation locks, current-health previews, queued
attacks/defeat, and renders the commitment, Strike, Evade, and reduced-motion
screens into `tests/talent_test_*.png`.

Bonus tiles can be selected with the BONUS RESERVE tile row before confirming
any encounter, Battlefield, Clash, JACL, CHARM, or INGENUITY test. Each physical tile toggles independently, with its value above its image. Scroll
over the row to reach additional tiles; selections persist while scrolling. There is no commitment limit. Selection is read-only
until confirmation; all selected tiles are consumed even on an automatic outcome.
The ordinary fate pool remains separate and unchanged by bonus consumption.
