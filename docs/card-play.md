# Asset card play

After the Agent Action entrance finishes, left-drag a card tile onto the asset
row. Moving four virtual pixels begins the drag. Only its 32px mini-portrait
follows the cursor; the original tile stays dimmed in place. Full previews and
hand scrolling pause during the drag. Hand gaps preserve hover but do not start
a drag. Hovering an equipped asset shows its full card preview.

The ghost resource box above the real box shows the projected balance; `-cost`
appears to its left. Actual resources do not change until a successful drop.
Negative projected balances appear red. Available slots are gold if the card
is affordable and a consecutive run exists, otherwise red. Hovering a valid
span shows the asset footprint; blocked spans show a red outline. Rejection
messages explain insufficient resources, insufficient adjacent space, or
unsupported card types.

The hovered slot is the preferred footprint start. At the right edge the start
clamps left just enough to keep the full span inside the seven slots. Placement
never jumps over occupied slots. One-slot assets occupy 50px; two-slot assets
occupy 104px, spanning the gap. A placed asset displays a centered mini-portrait
and its current health/defiance values using the shared colored-number renderer.

Releasing on a valid span revalidates the card, affordability, and occupancy.
`src/sys/card_play.lua` stages the next hand and board before committing payment,
hand removal, and placement together. Each card retains its unique instance ID.
Repeated release events cannot replay an instance that is no longer in hand.
Each successful play also spends one action point, including zero-resource-cost
cards. This cost lives in `data/card_play_rules.lua`. Action availability is
rechecked on drop and spending commits with resource payment and placement.
At zero actions, dragging remains available for feedback but slots turn red,
the message reads NO ACTION POINTS, and the drop changes nothing. The action
indicators only change after a successful play, never during dragging.
Playing does not refill the hand. Each new activation draws one card; rebuilding
the current activation interface does not draw again.

Escape, right-click, focus loss, leaving the virtual canvas, state exit, or
releasing outside the slot row cancels without payment. Blocked and unaffordable
drops likewise preserve the hand, resources, and action points. Inspection and
hover previews remain available with no actions left. Actions do not refresh on
Agent Action re-entry; a new mission initializes them again.

## Data and ownership

- `src/sys/agent_assets.lua` owns each agent's placements and occupancy by stable
  slot ID. `session.agentAssets` persists through mission-session transfers.
- `src/sys/card_play.lua` handles eligibility and commits. Only `card_type =
  "ASSET"` is playable. `cost` must be a nonnegative integer; `asset_slots` a
  positive integer. Optional health/defiance must be nonnegative integers.
- `src/ui/card_drag.lua` handles the drag gesture and validates presentation settings.
- `src/ui/asset_footprint.lua` draws placed and ghost assets using the same layout.
- `data/card_play_view.lua` configures the threshold, portrait size, opacity,
  feedback colors, and spacing. Existing equipment and status views provide
  slot coordinates and projected-resource rendering.

Placed assets retain their card instance and independently initialized health
and defiance. Mini-portraits and previews remain cached after leaving the hand,
and equipped cards are included when preparing a later visit. Hand layout
refreshes after play, preserving its scroll position where possible, without
restarting the entrance animation. View resources release on state exit.

Asset removal, replacement, movement, damage, exhaustion, activation, and non-asset resolution remain future rules.

## Verification

Run `love . --test`. `tests/card_play.lua` covers exact and zero costs, duplicate
instances, repeated releases, insufficient resources, occupied or fragmented
space, stale eligibility, oversized footprints, and session ownership.
Agent Action integration checks exercise drag cancellation, payment, placement,
hover previews, re-entry, and two-slot right-edge placement. Visual snapshots
include `card_drag_valid.png`, `card_drag_unaffordable.png`,
`card_asset_played.png`, `card_drag_two_slots.png`, and `card_assets_two_slots.png`.
