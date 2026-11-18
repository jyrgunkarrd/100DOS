# Doom clock

The mission starts with five empty 30 x 30 slots, each with a native-resolution
autofail image above it. Each position tracks a `pending`, `cleared`, or `locked`
autofail state plus an independent autosuccess occupant.
Positions never compact or move sideways.

- Ordinary successful fate tests clear the rightmost pending image.
- An `auto_success` converts the rightmost pending image into an autosuccess
  and drops it into the rightmost slot containing neither a locked autofail nor
  an autosuccess. This replaces normal success clearing. Without both a pending
  image and an empty destination, it does nothing.
- The first revealed `auto_failure` in each mission is a warning shot: the test
  still fails, but doom does not change. A #ff5d3d screen flash accompanies a
  permanent switch from the biome bg.png to bg_doom.png. This triggers even if
  there is no waiting icon or open slot, and leaves waiting icons in place.
- Later `auto_failure` results lock the leftmost pending image in its own slot.
  If none are waiting, the draw supplies a fresh autofail above the leftmost slot
  that is not already locked by an autofail, then immediately drops it into that
  slot. This can overwrite an autosuccess. A full autofail track does nothing.
- Ordinary failed tests do nothing.
- Encounter, Battlefield, and required Clash tests all participate.
- With no pending images, ordinary successes and autosuccesses do nothing;
  autofail draws can still supply their own icon as described above.
- Locked slots persist for the mission; successes never clear them.

Next Phase requires all surviving Agents to be exhausted, with no active Agent,
pending choice, hunt presentation, or resolving test/attack. It locks all remaining
pending images, waits for their drop, mills the net doom strength, checks
failure, refreshes Agents/readies location cards, then repopulates every unlocked
slot. Newly locked slots count toward that transition's mill. The initial phase is
phase 1 and has no opening mill.

Autosuccesses persist and each subtracts one card from milling, to a minimum of
zero. They never rebuild the JACL deck. They block other autosuccesses, but not
autofails: each new phase repopulates autofails above autosuccesses too. Ordinary
success can clear those waiting images while retaining the autosuccess below.
Autofails dropped during tests or at phase end overwrite any autosuccess in
their slot. Waiting images and slot contents are stored separately.

A full track of autofails keeps milling five cards per phase.

The JACL draw pile reaching zero immediately sets a failure outcome with reason
`jacl_deck_exhausted`. Draws and mills both count; discard and in-play cards do
not. There is no reshuffle. Overmilling removes only the remaining cards. No Agent
refresh or replenishment occurs after lethal milling. Enter starts a new mission.

Automatic phase-end advancement does not consume the warning or trigger its
visuals. Only a committed autofail reveal spends it. The warning persists across
Agent screen transitions and resets for a new mission. Other autofail effects
(including test failure and any Clash effects) still resolve normally. Both biome
backgrounds are preloaded; switching preserves all numbered parallax layers and
their scrolling offsets. Missing alternate art retains the current background.
The flash draws above result feedback and lasts 0.40 seconds, including a
0.05-second hold before fading; reduced motion lowers its opacity. `warningFlashColor`,
`warningFlashDuration`, and `warningFlashHold` configure the flash.

## Configuration

`data/doom_clock_rules.lua` supplies `slotCount`, `cardsMilledPerLockedSlot`,
`cardsPreventedPerAutosuccess`, and
the `encounter`, `battlefield`, and `clash` switches under `tests`. These rules are
copied into a new mission's clock.

`data/doom_clock_view.lua` supplies slot size/spacing, pending-image separation,
padding and gap below the Fate Pool button, image path, colors, animation durations,
and `reducedMotion`. Artwork is drawn without image scaling and uses nearest
filtering. Normal game-canvas scaling still applies. Reduced motion removes the
phase drop wait without changing gameplay results.

The panel aligns its left edge to the Fate Pool button and sits directly below
it. Its caption shows the JACL draw-pile count and milling per phase.
When every slot is occupied (including autosuccesses), HIS GLORY replaces the
waiting-icon row after drops settle. It uses the mission heading font, Not Jam
UI 12 at 12 px, in #ff5d3d, pulsing smoothly from full opacity to transparency
and back over two seconds. `gloryLabel`, `gloryColor`, and `gloryPulseDuration`
configure this treatment. The pulse persists across mission screen transitions.
The deck count briefly changes color after milling. Missing artwork
falls back to an X. Its image shares the mission artwork cache and is released
when the mission ends or is abandoned.

The panel assembles once at mission start: its background fades in over 0.12
seconds, then slots appear left to right at 0.04-second intervals with a brief
#ff5d3d outline flash. Each waiting icon fades in and drops 6 pixels over 0.12
seconds. The deck caption fades with the final slot, completing the five-slot
opening in 0.40 seconds. Returning from an Agent screen does not replay it.
Subsequent phases only fade/drop newly populated icons; existing slots and the
panel remain steady. `openingPanelDuration`, `openingStagger`,
`openingSlotDuration`, `populateDuration`, and `populateOffset` configure these
effects. Reduced motion shows the assembled panel and populated icons immediately.

## Modules

- `src/sys/doom_clock.lua`: detached change plans with revision checks and
  single-use commits, plus presentation records independent of rendering.
- `src/sys/mission_phase.lua`: prepares refresh/milling before locking doom;
  blocks input during the transition and mills once before refresh.
- `src/sys/mission_deck_effects.lua`: binds successful deck-commit notifications
  to the mission and checks its current JACL draw pile. Hunt deck clones retain
  that observer; session release detaches it.
- `src/sys/fate_reveal.lua`: prepares doom alongside shared fate outcomes;
  encounter/Battlefield publishers commit those consequences once.
- `src/ui/doom_clock.lua`: native-size rendering, fades, drops, and replenishment.
- `src/sys/mission_outcome.lua` and `src/ui/mission_outcome.lua`: terminal state,
  pending-action cleanup, and victory/failure presentation shared with hunt UI.

Lifecycle/session ownership retains doom through Mission Action/Agent Action
transitions. Rendering never mutates the gameplay track. Location-deck
`commitDraw`/`commitMill` notify their owner after successful commits; future
deck-removal APIs should do the same.

## Verification

Run `love . --test`. To run only doom and talent-test integration checks, use
`love . --test --doom-only` (results in `tests/doom_focused_results.txt`). `tests/doom_clock.lua` checks directionality, mixed outcomes,
stale/repeated commits, cleared-slot protection, phase ordering, capped persistent
doom, repeated milling, autosuccess conversion/stack blocking, overwrite, zero-floor milling,
exact/overdraw exhaustion, exploration failure, invalid
phase preparation, reduced motion, screen transitions, and terminal input.
Screenshots are written to `tests/doom_*.png`; results to `tests/results.txt`.
