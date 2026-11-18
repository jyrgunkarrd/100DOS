# Read-only Agent and location inspection

After a mission begins, right-click an Agent portrait on the map, roster, or
selected portrait to open a read-only composition of the Agent Action view.
Ready, exhausted and defeated Agents are inspectable. Portrait hits take priority
over force inspection beneath them; right-clicking a hex outside portraits keeps
the existing force inspector.

The view shows the inspected Agent's actual current hand, equipment, health,
defiance, resources and action points, plus their current location's revealed
encounters. Encounter tiles retain runtime health, exhaustion and engagement
targets. Hover hand cards, equipment and revealed encounters for ordinary card
previews. Wheel scrolls lists; Shift-wheel scrolls the visible card preview.
The location's last milling receipt remains available when present.

Explore, Strike/Evade, card dragging, movement, Done and phase controls are absent.
The **Deck / Discard / Fate** button opens the existing details panel. Using its
close button or clicking outside that panel returns to observation; a fresh right-click
or Escape closes the entire observation view and restores the previous screen
and selection. The right-click release that opened observation never closes it.
Losing focus clears pending interface presses.

Inspection does not activate an Agent, draw cards, initialize empty equipment
boards, alter engagements or exhaustion, spend resources/actions, resolve an
encounter, refresh a phase, consume mission randomness, or trigger champion escape.
It can also inspect another Agent while preserving the active Agent's turn.
Existing action-resolution, modal and distribution locks still apply.

Only revealed encounters and known milling receipts can supply location preview
targets. Hidden hunt cards stay hidden; ordinary deck counts keep the existing
`+ ?` concealment. Before the mission starts, right-clicking continues to open the
original planned-deck/Fate details panel.

`src/ui/agent_observation.lua` owns only its temporary display objects. It shares
the mission session for reading and never transfers/releases session ownership or
calls activation/action systems. `data/agent_observation_view.lua` supplies its
labels and footer layout. `agent_inspection` routes right-clicks and handles
closing; the existing encounter panel has an explicit read-only mode which omits
the Explore control. The original details panel remains reusable inside the view.

Run `love . --test`. `tests/agent_observation.lua` checks complete gameplay-state
and RNG snapshots around observation, portrait priority, fresh-click closure,
ready/exhausted/defeated states, current hand/equipment and encounter previews,
hidden-card protection, scrolling, empty/crowded hands, cancelled focus presses,
phase/action blocking, failure cleanup, retained details access, force inspection,
and observation during another Agent's active turn. Visual checks are written to
`tests/agent_observation_*.png`.
