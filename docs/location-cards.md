# Location card pools and decks

## JACL center location

Deployment reserves the configured center cell for `loc_<jaclId>`. The remaining
eight cells use the biome's existing random location pool without duplicates.
The center is a mission-specific location named after the selected JACL. Its
`deck_build` adds the selected JACL and Captain quantities by card type, and its
`deck_size` is derived from that total. Source definitions are not modified.

The center contributes an empty `card_pool` and draws from the shared pool supplied
by the placed biome locations. Positive quantities without eligible cards fail
preparation. There is no separate JACL pool. Exploration, deployment, movement,
engagement, depletion, and phase persistence use the ordinary location systems.
The JACL itself stays at the center for this mission.

Artwork uses `assets/images/locations/loc_<jaclId>.png` through the existing loader
and missing-art fallback. `data/jacl_location_rules.lua` configures the center cell
and ID prefix. `location_deck_recipe` shares validation and combines recipes;
`jacl_location` builds the definition; `mission_locations` assembles assignments
and a mission catalogue before the existing pool and deck builders run.

`tests/mission_locations.lua` covers all current JACL/Captain/biome combinations,
shared eligibility, repeatable placement, recipe composition, source isolation,
and invalid configuration. The exploration integration test uses the JACL center
through the normal Agent and phase transitions.

## Shared pool and deck construction

During deployment preparation, the locations actually assigned to map cells contribute
their `card_pool` arrays to one shared mission pool. IDs resolve through
`data.loc_cards.index`; duplicate contributions do not increase selection probability.
The pool exposes sorted `ids`, `byId` definitions, and `byType` ID arrays, using each
card's `card_type` exactly as written.

Each location's `deck_build` contains entries such as `{ type = "ENEMY", qty = 10 }`
and `{ type = "BARRIER", qty = 10 }`.
Quantities must be nonnegative integers and total its nonnegative integer `deck_size`.
Every requested type with a positive quantity must have eligible cards in the shared
pool. Selection is uniform with replacement, followed by a shuffle of the whole deck.
A location can therefore receive cards contributed by any other placed location.

`src.sys.location_card_pool.build(assignments, locations, cards)` constructs the pool.
`src.sys.location_decks.new(assignments, locations, pool, random)` builds decks;
the optional random generator supports reproducible generation. Recipes are validated
before any deck-building randomness is consumed. Construction completes before the
mission transition is committed; definition tables are never modified.

The mission session retains `locationCardPool` and `locationDecks`. Deck state lives
in `locationDecks.byCell[cellId]`, with `locationId`, `locationName`, `drawPile`,
`inPlay`, `inPlayOrder`, and `discardPile`. Each copy has a mission-unique `instanceId` and a `cardId` referencing
the pool. Runtime changes belong on copies, not shared definitions.

`locationDecks:draw(cellId)` removes the top (last array entry), tracks it in `inPlay`,
and returns it, or nil when empty. `locationDecks:discard(cellId, instanceId)` moves
an in-play card to that cell's discard pile, returning false for a card not in play
there. It cannot discard the same instance twice. `inPlayOrder` stores instance IDs
in reveal order; discard removes the ID from that order without reordering the rest.

State transitions and Next Phase preserve these piles. There are no automatic draws or reshuffles. Enemy reveals create engagement as described
below; opportunity attacks resolve after actions (see `docs/attacks.md`). Leaving the mission releases the session's
references. Tests cover shared eligibility, recipes, independent copies, draw/discard
behavior, deterministic generation, current data, and persistence through a full phase.


## Exploration

During Agent Action the left-side exploration panel shows the active agent's location,
remaining deck total, and remaining counts by type. Counts come from the actual draw
pile, not the recipe or shared pool. Recipe types remain visible at zero. Locations
are shared by all agents at the same cell; selecting or activating an agent does not
automatically draw a location card.

Explore costs one action point and reveals one card. It does not spend resources or
change the agent's hand. The button requires a complete press/release inside its
bounds. Focus loss, Escape, right-click, releasing outside, and card dragging cancel
or suppress the interaction. Empty decks and insufficient actions disable Explore
with a reason. The brief reveal highlight also locks exploration against extra clicks.
An empty deck is not a cleared location: its revealed cards remain in play.

`src/sys/location_exploration.lua` validates eligibility, stages a draw, and commits
card movement and action spending together. `prepareDraw` leaves the live deck alone;
`commitDraw` rejects stale preparations using a deck revision. Drawing and discarding
both advance that revision. Failed preparation spends nothing.

`src/ui/location_exploration_panel.lua` owns only presentation, input, scrolling, and
its artwork cache. Location gameplay state stays in the mission session. Artwork is
prepared before Agent Action commits, with placeholders for missing images. Returning
to the location shows the existing cards. Revealed copies appear individually in
stable order, using the shared `card_tile` renderer with `showCost = false`. New cards
briefly highlight and scroll into view. Scrolling over the revealed list changes only
that list. Visible rows are calculated from actual tile heights; engaged Enemy tiles
include an additional target-name line.

## Configuration

- `data/location_exploration_rules.lua`: `actionPointCost = 1`, a finite nonnegative
  integer. Each exploration always draws one card.
- `data/location_exploration_view.lua`: panel bounds, tile size, spacing, button
  height, reveal duration, labels, colours, artwork directory/suffix, type labels,
  type colours, and preferred type order. Additional types fall back to their ID
  with underscores replaced by spaces, in alphabetical order after configured types.
- Mini-artwork: `assets/images/loc_cards/<cardId>_mini.png`.

Enemy/Barrier counts are public; identities and order of undrawn cards are not shown.
Revealed cards currently have no click action, automatic resolution, combat, discard
button. Revealed cards support full-size hover previews. In-play cards do not block further exploration.

## Verification

Run `love . --test`. `tests/location_exploration.lua` covers mixed-type counts,
zero-count types, independent locations, action spending, staged failure and stale
draws, inactive/exhausted agents, canceled input, duplicate releases, reveal lock,
shared locations across agents, deck depletion, scrolling, artwork fallback, long
names, phase persistence, and cleanup. The suite writes `location_exploration_empty.png`,
`location_exploration_reveal.png`, `location_exploration_no_actions.png`, and
`location_exploration_depleted.png` for visual review.


## Hover previews

Hover a visible revealed tile to inspect it over the map using the same renderer,
fonts, frame, formatted rules, clipping, image cache, and scrolling as Agent cards.
Only one preview is visible at a time. Leaving a tile, Escape, right-click, focus
loss, or dragging an Agent card clears the preview. Inspection remains available
with zero actions or an empty location deck. Undrawn cards have no hover targets.

Wheel scrolls the revealed list and immediately rechecks the card under the pointer.
Shift + wheel scrolls the visible preview instead, without moving the tile list.
Long rules use a rules viewport; oversized artwork/header/test sections scroll the
whole preview with a SHIFT + WHEEL: SCROLL hint. Duplicate copies share artwork and
layout and retain scroll position, while the controller tracks each hovered instance.
Switching source or definition resets scroll and plays the existing card-view cue.

Location previews show name, uppercase type, centered artwork, talent-test rows,
uppercase tags, optional formatted rules, and only explicitly defined stats. Each
`talent_tests = { { type = "steel", val = 8 } }` entry displays one icon, label, and
number, preserving definition order. Values must be finite nonnegative integers.
These are descriptive values, not interactive tests or an AND/OR resolution rule.
A missing health/defiance field is omitted; an explicit zero remains visible. Cost,
Agent talent quantities, methods, and asset slots are not location-preview sections.

`card_display.p1`, `p2`, etc. use the same paragraph ordering and colour markup as
Agent cards. Full artwork lives at `assets/images/loc_cards/<cardId>.png`; talent
icons use the existing talent directory. Missing art/icons show placeholders, and
unknown talent IDs remain readable as text labels.

### Ownership and settings

- `src/sys/card_display.lua` exposes shared name/type/tag/paragraph normalization
  while preserving the existing Agent normalization entry point.
- `src/sys/location_card_display.lua` supplies location normalization and validation.
  It does not mutate definitions or infer missing stats.
- `src/ui/card_preview.lua` accepts an optional normalization function and renders
  either source through its shared layout and optional test/stat sections.
- `src/ui/card_preview_controller.lua` coordinates the two preview instances,
  visibility, sound, scrolling, and cleanup. Agent and location collections are
  separate, so identical card IDs cannot collide across sources.
- `data/location_card_preview_view.lua` inherits the common preview settings and
  overrides artwork directory, artwork centering, test heading, talent labels,
  and stat labels. Common styling remains in `data/card_preview_view.lua`.

The location pool is prepared before Agent Action commits, avoiding new image loads
when exploring. Preparation does not expose hidden cards: only currently visible
in-play instances are eligible hover targets. Previews are released on state exit;
failed preview preparation leaves Agent activation and the location deck unchanged.

`tests/location_card_preview.lua` verifies actual Enemy/Barrier definitions, absent
and zero stats, invalid tests, formatted rules, overflow, missing art/icons, duplicate
copies, source ID collisions, and cleanup. The exploration integration checks cover
hover routing, stationary-pointer list scrolling, Shift-wheel priority, cancellation,
drag suppression, and unchanged deck/action state. Visual outputs include
`location_preview_barrier.png`, `location_preview_enemy.png`,
`location_preview_in_game.png`, and `location_preview_overflow.png`.


Location preview footers also support optional `damage` and `trauma` ratings. Both
must be finite nonnegative integers: omitted fields are hidden, while explicit zero
values remain visible. Ratings appear after Health/Defiance, with extra spacing only
when both groups exist. DAMAGE uses Health blue; TRAUMA uses Defiance orange. Labels,
colours, and `statGroupGap` live in `data/location_card_preview_view.lua`. Footer height
and overflow include all visible rows. Opportunity attacks use these ratings to reduce Agent Health and Defiance after actions.
Hover inspection remains read-only; newly revealed Enemies do not attack immediately.

Damage and Trauma share a footer row, with DAMAGE aligned left and TRAUMA aligned
right. Health/Defiance remain above this row. `statPair` in the location preview
settings selects the paired fields. Missing ratings leave their side blank; long
values wrap within separate columns without overlapping.


## Enemy engagement

Explore revealing an ENEMY immediately engages that individual card with the Agent
who revealed it. The runtime card stores `engagedAgentId`; shared card definitions
remain unchanged. One Agent may have multiple engaged Enemies, and identical Enemy
copies can target different Agents. Barriers do not engage by default. Done, switching
Agents, and Next Phase preserve the target. Discard clears it. Engagement now causes opportunity attacks after successful actions. It adds no action
cost or exploration restriction. See `docs/attacks.md` for timing and defeat.
Movement and disengagement gameplay are not defined by this change.

`data/location_engagement_rules.lua` maps card types to booleans through
`engageRevealerTypes`, initially `{ ENEMY = true }`. `src/sys/location_engagement.lua`
validates this map, prepares engagement, exposes target/count queries, and clears
engagement. Explore stages an independent copy of the revealed instance before
assigning its target, so even failed/stale commits cannot mutate a card in the live
draw pile. Draw, engagement, and the normal Explore action cost commit together.
The low-level deck `draw` operation remains neutral: gameplay reveal callers must
supply the revealing Agent through the engagement preparation step.

Engaged tiles remain in reveal order with a warm-red edge and an ENGAGED: <name>
line. The active Agent's derived ENGAGED WITH YOU count remains visible above the
list even if their Enemies are scrolled out of view. Tile heights, last-page position,
scrolling, and gap hover use the same variable-height geometry. Long target names
truncate with an ellipsis on the tile; the preview wraps the full name beneath type.
The gold hover frame remains independent of the red engagement marker.

Tile engagement height, labels, and colour live in `data/location_exploration_view.lua`.
Preview engagement label and colour live in `data/location_card_preview_view.lua`.
Agent names are resolved from the Agent catalogue for the current interface, with an
ID fallback. The preview controller supplies engagement text from the hovered card
instance. Only the active contextual layout is rebuilt when that text changes;
artwork and base definition layouts remain shared. Switching between identical Enemy
cards with different targets therefore updates the name without loading new art.

`tests/location_engagement.lua` covers atomic failure, staging without live mutation,
invalid rules, duplicate instances targeting different Agents, multiple engagements,
non-Enemy reveals, phase persistence, discard cleanup, and unchanged Health/Defiance.
Exploration integration tests exercise the full reveal/Done/next-Agent flow, mixed
heights, gap hover, counts, and long names. Preview tests verify target switching and
shared artwork. Visual outputs: `location_engagement_reveal.png`,
`location_engagement_shared.png`, and `location_engagement_long_name.png`.
