# Opportunity attacks and defeat

A successful card play or Explore completes first, including costs and effects.
Every in-play Enemy engaged with that Agent when the action began then attacks once,
in location reveal order. Queries use stable cell-ID order if engagements span cells.
A newly revealed Enemy engages immediately but is excluded from that action's attack
snapshot. One action provokes one sequence regardless of its action-point cost.
Invalid/canceled actions, previews, selection, activation, and Next Phase do not
provoke attacks. The final action point still provokes the full sequence.
Done provokes once after any required Clash tests finish.

Each attack applies damage to Health and trauma to Defiance together, clamped to zero.
Missing ratings mean zero; negative, fractional, nonnumeric, and infinite ratings are
rejected before any costs, card changes, or damage are published. There are no hit
rolls or mitigation. Even an attack with both ratings zero has a feedback event.

After each attack, zero Health or zero Defiance defeats the Agent. Subsequent attackers
are skipped. The status records `defeated`, `defeatCause` (health, defiance, or both),
and `defeatedBy` (Enemy instance ID). Actions become zero, the active turn ends, and
all engagements targeting that Agent clear, including any Enemy just revealed by
the completed action. Enemies remain in play. Cards, resources, assets, and the last
map placement remain. The action's costs/effects are never refunded on defeat.

Defeated Agents cannot be selected, activated, or take actions. They remain defeated
across phases and receive no phase resources/actions. Next Phase requires all surviving
Agents to be exhausted and at least one survivor. When none remain, Mission Action
shows ALL AGENTS DEFEATED and disables activation and phase advancement. A distinct
cross marks defeated map portraits, with a DEFEATED label on roster portraits. There
is no revival, loot loss, Enemy retargeting, or broader results screen yet.

## Ownership and transactions

- `agent_action_resolution` coordinates explicit action kinds (`play_card`, `explore`).
  It snapshots attackers, prepares the action's effects/costs, resolves attacks against
  temporary status, and returns a one-use plan. Commit checks action revision, active
  Agent, status, placement, and deck revisions. No live changes occur on preparation
  failure or stale/repeated commits. Existing card-play/Explore `commit` entry points
  delegate to this coordinator; their `prepare` methods build action-specific changes.
- `opportunity_attacks` collects ordered engaged Enemy instances and validates their
  ratings, independently of drawing or card-play UI.
- `attack_resolution` applies attack requests to copied status and returns a sequential
  event record containing before/after Health/Defiance and defeat. Other attack types
  can use it without depending on opportunity-attack triggers.
- `agent_status` owns defeat state and availability queries. `agent_turn` excludes
  defeated Agents from activation/refresh and blocks turn changes during attack feedback.
- `location_engagement` exposes ordered queries and clears targets on defeat.

The model publishes the complete transaction before feedback begins. The temporary
`session.attackFeedback` record locks further actions; `actionRevision` rejects replayed
plans. Agent Action prepares its return interface before committing a lethal action,
so a failed return preparation also leaves the proposed action and damage unchanged.

## Feedback and configuration

`data/attack_rules.lua` lists the provoking actions.
Future action kinds must be wired into action preparation and explicitly configured.
`data/attack_feedback_view.lua` configures durations, hit time, defeat hold,
labels, and colours. `data/agent_turn_view.lua` supplies defeat labels.

`src/ui/attack_feedback.lua` plays recorded results only; timers never apply damage.
Each 0.8-second step scrolls its Enemy into view and highlights its tile. The new
`src/ui/attack_cutin.lua` renders full enemy art on the left and Agent art on the right,
with an attack counter, impact streak, local jolt, and actual Health/Defiance reductions
and before/after values. The Agent panel stays in place between attackers. Defeat dims
the art and holds a DEFEATED label before the final exit and return to Mission Action.

`data/attack_cutin_view.lua` controls panel dimensions, animation distances, entrance,
exit and impact durations, colours, and typography. Set `reducedMotion = true` to use
fades without slides, jolts, flashes, or number pulses. The layout scales to fit the
available screen. Artwork preserves its complete aspect ratio without cropping.
The renderer borrows existing location-preview and selected-Agent image caches; it
allocates no images or fonts and does not release borrowed resources. Attack records
carry the source `cardId`; missing art falls back to a named ART UNAVAILABLE panel.
Presentation timers never mutate combat state. Stats are presentation snapshots while
the model already contains final results.

Gameplay input, including Done and additional drags/clicks, is blocked during playback.
Escape/focus loss cancel pointer gestures but cannot cancel or repeat committed hits.
Long frames may advance through feedback, but never omit or duplicate model damage.
Returning after defeat retains the session and clears the pending feedback record.

## Verification

Run `love . --test`. `tests/attacks.lua` covers ordered multi-Enemy attacks, exclusion
of newly revealed Enemies, both action types and multi-point action costs, zero/missing
ratings, invalid data, atomic failure, stale/replayed plans, final-action attacks,
Health/Defiance/both defeat, overkill, early termination, retained action effects,
engagement cleanup, surviving-Agent phase refresh, and all-defeated behaviour.
UI checks exercise real card dragging and Explore, focus loss, repeated releases,
large time steps, failed return preparation, automatic return, and unselectable defeated
Agents. Screenshots include `opportunity_attack_first.png`, `opportunity_attack_second.png`,
`agent_defeated.png`, `mission_agent_defeated.png`, and `mission_all_defeated.png`.

Cut-in checks also cover retained Agent placement between attackers, reduced motion,
missing artwork at a smaller viewport, and unchanged combat state after rendering.
