# Agent turns and phase refresh

Done appears centered above the Agent Action portrait's status row, with six
pixels of clearance. It follows the portrait slide and accepts clicks after the
entrance finishes. Its false/true images represent normal/hover states. Card
dragging suppresses Done interaction; dropping a card on Done never ends a turn.

A completed Done click prepares the returning Mission Action interface first.
It then resolves any [required clashes](battlefield.md#clashes) at the Agent's
location, followed by attacks from engaged location enemies. When the turn
ends, the Agent becomes exhausted, remaining actions go to zero, and the
existing mission session transfers back after feedback. Done works with
unused actions and with none left.

Mission Action returns with a 120ms selection-UI fade and no selected agent. It
does not replay deployment effects or the Ready cue. Exhausted mini-portraits
are drawn at 50% brightness, fully opaque, with the deployment-style red 5px
badge inset two pixels. Map drawing places exhausted agents behind all eligible
agents without moving their portrait positions. Hit tests skip exhausted agents
in both the roster and map, and Agent Action independently rejects their entry.

Next Phase is centered eight pixels above the mini-portrait grid. The selection
prompt sits above it. Its false image means unavailable; the true image means
all agents are exhausted and the button is clickable, independent of hover.
When all are exhausted, the prompt reads ALL AGENTS EXHAUSTED and Act is disabled.

Clicking Next Phase refreshes every agent together:

- Clear exhaustion and restore actions to capacity.
- Preserve every hand and draw pile without drawing cards.
- Add one resource to the current pool.

Each agent receives an opening hand at mission start and draws one card on each
activation, including its first. Short draw piles supply what remains, with no
reshuffle. Health, defiance, assets, and placements do not change during refresh.
Selection clears and Next Phase becomes unavailable immediately; repeated releases
or clicks cannot refresh twice. Resource totals and capacities are validated before
any live refresh mutations, so preparation failure changes nothing. Focus loss or
release outside either button cancels its click.

`src/sys/agent_status.lua` owns status records and exhaustion checks.
`src/sys/agent_turn.lua` coordinates activation draws, finishing, and phase refresh.
Its active-agent marker prevents duplicate activation draws and is cleared on Done.
`phaseResourceGain` in `data/agent_status_defaults.lua` sets the resource gain.
`data/agent_turn_view.lua` configures both buttons, spacing, return fade, exhausted
brightness, and the all-exhausted prompt. Existing image buttons are reused.
The two action states own their buttons and release them when leaving.

Run `love . --test`. `tests/agent_turn.lua` covers the full six-agent cycle,
early Done, zero-action Done, canceled clicks and drags, failed return/refresh
preparation, preservation of cards and assets, short/excess hands, resource
gain, disabled/double refresh, and new-phase selection. Screenshots include
`agent_exhausted.png`, `next_phase_ready.png`, and `next_phase_refreshed.png`.


When the active agent has zero action points, Done displays its true-state image
without requiring pointer hover. A centered ALL ACTIONS SPENT label appears four
pixels above it in #ff4444 using the existing small UI font. Text, colour, and gap
are configured by `actionsSpent` in `data/agent_turn_view.lua`. The appearance derives
from current action points, including card play, Explore, and zero-action re-entry;
restoring actions hides the label and restores normal/hover imagery. It follows the
button during the portrait slide. The shared image button accepts a draw-only
`forceTrue` argument, so this does not change hover sounds, pointer state, click
eligibility, drag protections, or automatically end the activation.


Opportunity attacks resolve after successful actions, including the final action.
Done provokes once at turn completion. During attack feedback, Done and other
gameplay inputs are blocked. Defeat ends the activation automatically after feedback,
clears engagements, and returns to Mission Action. Defeated Agents are excluded from
refresh and remain unavailable; all-defeated teams cannot advance phases. See
`docs/attacks.md` for the shared resolver, transaction rules, and configuration.
