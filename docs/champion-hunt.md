# Champion hunts

Ready selects one champion uniformly from the biome's `champ_pool`, includes every
ID in its `company` array once, and fills the remaining occupied non-JACL cells
with bodyguards sampled uniformly **with replacement** from its `bodyguards`
array. Cardinal Hand starts with five company members and two independent Talons
on the eight-location board.

The group is shuffled, one instance is assigned to each eligible location, and
each assigned card is added to and shuffled into that location's ordinary deck.
This adds one card per location; it does not replace ordinary recipe cards.
Special roles must not appear in ordinary `card_pool` or positive-quantity
`deck_build` entries.

The complete biome champion pool and its referenced entourage are validated
before hunt randomness. Invalid IDs, duplicate or sparse arrays, incorrect roles,
invalid combat data, empty champion/bodyguard pools, and company sizes exceeding
board capacity reject Ready. Empty companies are supported. Ready builds detached
decks and publishes them only after successful interface preparation. Returning
between mission and Agent screens reuses the same hunt.

## Combat and elimination

`CHAMPION`, `COMPANY` and `BODYGUARD` retain their displayed roles and share ordinary
enemy behavior: runtime health, Strike/Evade tests, engagement, opportunity attacks,
exhaustion and phase readiness. Health belongs to instances, never definitions.

- Eliminating a bodyguard marks one randomly selected surviving, hidden, unlocated
  company member or champion. This does not draw the target. No eligible targets
  produces `NO NEW INTELLIGENCE`.
- Eliminating a company member or bodyguard permanently secures its cell, excluding it from
  later hunt distributions. Existing armies and ordinary encounters remain.
  Empty decks and zero army strength do not themselves secure locations.
- Eliminating the champion immediately commits victory and prevents further
  actions or phase refreshes. Enter begins a fresh mission preparation. Discard
  and withdrawal never trigger elimination effects.
- Milling any special role puts that instance into play instead of discard.
  Local entries engage the acting Agent; remote entries can remain unengaged.
  Newly revealed enemies do not join the action's snapshotted retaliation.

Cardinal's initial health is **2**, allowing early discovery in a three-action
turn to produce a lucky kill, while late discovery can lead to a wounded escape.
Further pacing adjustments belong in champion data.

## Escape and replacement screen

Completing any Agent turn, including defeat during another action, queues one
escape if the living champion is in play. Required Done clashes and combat
feedback finish before escape resolves. Changing views, activation and phase
refresh never queue extra escapes.

Escape withdraws all surviving bodyguards from the old screen, wherever they are.
Eliminated guards remain in discard. Surviving company members stay in place.
The champion keeps her instance ID and health; engagement and exhaustion clear.
She is shuffled with fresh bodyguards numbering `unsecured locations - 1`.
One screen card is shuffled into each unsecured location deck. A location can
therefore contain a company member plus one screen card. Ordinary in-play and
discard cards remain untouched.

The previous location is a valid random destination. One eligible location needs
only the champion. With none, she stays visible in play, cornered. If company
elimination secures a location containing a hidden champion, that champion enters
play rather than becoming stranded invisibly in a secured deck.

**Escaping to enemy army strength zero only marks the champion's location.** She
stays inside the shuffled deck and must still be found. Her old intelligence
marker clears on escape; the new marker requires this rule or another
intelligence effect. Escape never heals the champion.

## Hidden information and presentation

The map receives only secured cells and discovered target locations. Hidden cards
create no hover or inspection targets. Public deck summaries omit special-role
counts. Non-JACL summaries show ordinary remaining cards plus `?` for an
undisclosed hunt-card amount, for example `20 + ?`. This flag comes from board
eligibility, never actual card positions. Milling receipts use the same convention
so subtracting counts cannot expose company members beside a replacement screen.

`data/hunt_distribution_view.lua` controls gather/shuffle/deal/pulse timing, labels,
colors, the cached sound cue and reduced motion. The eight-location default lasts
about 0.93 seconds. Identical card-back tokens are unrelated to hidden assignments.
Escape gathers at the publicly known source before distributing anonymous tokens.
Markers appear after distribution. Space or Escape skips presentation without
changing gameplay or randomness. Focus changes and resizing cannot reroll it.

## Module ownership

- `mission_hunt`: validation, roster identities, intelligence, security, detached
  setup/escape, and public map markers. Related hunt state stays together.
- `location_card_traits`: shared enemy behavior independent of displayed role.
- `location_card_entry`: shared entry preparation and discovery hooks.
- `location_card_elimination`: defeat effects kept separate from discard.
- `mission_outcome`: terminal victory and cancellation.
- Existing `location_decks`: deck ownership, milling entry and safe summaries.
- Existing `agent_action_resolution`: escape queuing when a turn actually ends.
  Mission entry resolves the pending escape after feedback.
- `hunt_distribution` UI: anonymous animation, markers, victory and skip/restart.

`mission_session` transfers/releases hunt, outcome and pending state with the
mission. Escape rejects stale hunt, deck, army and champion snapshots before
consuming randomness or publishing a whole-board change.

Run `love . --test`. `tests/mission_hunt.lua` covers generation, validation, hidden
information, combat, defeat effects, milling, security, cornered cases, turn/clash/
defeat timing, stale escapes, wounds, ownership and an actual
discover/wound/flee/rediscover/kill UI sequence. It writes `tests/hunt_*.png` for
initial distribution, escape, reduced motion, zero-strength tracking and victory.
