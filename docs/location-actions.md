# Location actions

The Action panel has three stacked tabs: LOCATION, AGENT, and BATTLEFIELD.
BATTLEFIELD becomes JACL at the JACL location. AGENT retains the former Basic
actions. LOCATION stacks EXPLORE, CHARM, and INGENUITY using the same row styling.
Switching tabs cancels pending movement or bombardment targeting.
The upper location display is reserved for location information and cards. Both new tests allow normal hand and bonus commitments, and
provoke the usual one opportunity attack per already-engaged ready enemy after
resolution. Costs are spent on either success or failure; cancellation is free.
Actions are available at ordinary locations and the JACL.

- CHARM: 1 AP, Passion 3. Snapshot the original top two cards. Each hidden card
  becomes face-up in the deck; each already face-up card enters play. Enemy traits
  (including hunt enemies and Silencers) enter exhausted and unengaged. Exhaustion
  ends under ordinary phase refresh rules. A one-card deck processes one card;
  an empty deck disables CHARM. Newly revealed cards are not immediately put into
  play, and removed cards are not replaced within the same action.
- INGENUITY: 2 AP, Reason 3. Add one Genius bonus tile on success, after the draw.
  Works even with an empty location deck. An existing Genius may help the test;
  the newly awarded tile cannot help the test which creates it.

Cards in play and face-up deck cards appear in separate side-by-side columns,
IN PLAY on the left and REVEALED on the right. Each column scrolls
independently beneath the pointer, after spacing compresses to its minimum. Card
images retain their size; health, exhaustion, and engagement strips appear above
the card, with no duplicate strip below. Minimum spacing keeps the strip and name
visible. Hovered cards draw above their neighbors while hit regions stay fixed.
Face-up deck cards support hover previews only.
They remain in deck counts and cannot be targeted as encounters. Drawing or milling
removes their face-up state; shuffling clears it. Revealing alone does not trigger
entry or engagement. Triangulate retains its existing hunt-top reveal rules.

`data/agent_action_tabs.lua` owns tab order, labels, and the initial Agent tab.
`src.ui.card_column_layout` calculates compression and scroll bounds for both
columns; view settings control minimum name exposure and spacing.
`data/location_actions.lua` owns order, labels, costs, tests, and effect quantities.
`src.sys.location_actions` stages tests through the shared action resolver.
`location_decks` owns card visibility and CHARM movement. `fate_reserve` owns bonus
additions and commitment consumption. Existing panels and result feedback are reused.

Run `love . --test`. New rules are covered by `tests/location_actions.lua`; actual
button clicks, bonus selection/cancellation, reserve inspection, face-up hover-only
cards, and screenshots are covered by `tests/talent_test_ui.lua`.
