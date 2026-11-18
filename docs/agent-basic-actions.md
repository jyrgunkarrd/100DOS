# Agent basic actions

During Agent Action, click Actions beneath the equipment row, press A, or click
the active Agent's map portrait to open the panel. It shows the Agent's name,
remaining AP, and three repeatable actions. It remains open after success.
Disabled rows explain their requirements. Done still ends the activation.

| Action | Cost | Requirements and effect |
| --- | --- | --- |
| Move | 1 AP | No engaged enemies. Select a neighbouring location sharing a hex edge. |
| Draw a card | 1 AP | Nonempty Agent deck. Draw its next card without reshuffling. |
| Gain 1 resource | 1 AP | Add one to the Agent's resource pool, with no gameplay cap. |

Empty frames are outside the play area. Other Agents do not block a location.
Move highlights legal destinations; clicking one commits one step. Moving back
is legal. Opening targeting, invalid targets, and cancellation spend nothing.
The map cluster and location panel immediately reflect the new location.
Map portraits slide to their committed positions with a quick 0.16-second ease-out.
Other Agents smoothly rearrange within the source and destination clusters.
Rapid moves continue from the current visible position without snapping; closing
the panel does not cancel movement. Shadows, outlines, and hit testing follow
the visible portraits. `movementDuration` in `data/agent_action.lua` tunes the
duration; zero disables the animation. Animation never changes AP or placement.
Movement does not introduce new arrival effects; the existing reveal/activation
engagement rules remain in effect.

Escape or right-click closes the panel and cancels targeting. A toggles it.
An outside click closes it when not targeting; while targeting, invalid clicks
leave targeting active. Focus loss or leaving the canvas cancels pending input.
Opening with A clears pending gestures, including Done. Panel clicks do not
also activate underlying controls.

Commands are unavailable during entrance, card dragging, location reveal,
talent-test interaction, and combat feedback. Closing UI cannot undo committed
actions or stop queued attacks. All three actions provoke opportunity attacks,
including the last AP. Effects complete first and remain committed on defeat.
Move normally has no attackers because existing engagement prevents movement.

## Modules and ownership

- `data/agent_basic_actions.lua`: ordered action IDs, labels, AP costs, movement
  target type, and draw/resource quantities.
- `src/sys/agent_basic_actions.lua`: definition validation, availability, and
  staged changes. Publication rechecks eligibility; paid draws also check the
  source hand, draw pile, and discard pile for stale changes.
- `src/sys/board_topology.lua`: axial adjacency independent of rendering,
  filtered to cells containing assigned locations.
- `src/sys/agent_action_resolution.lua`: shared cost/effect/attack transaction,
  stale-plan rejection, and one-use commits. The existing defeat path is reused.
- `data/attack_rules.lua`: enables attacks for `move`, `draw_card`, and
  `gain_resource` explicitly.
- `src/ui/agent_action_panel.lua`: panel input, drawing, and movement targeting.
  It requests actions without changing gameplay state, borrowing existing fonts.
- `data/agent_action_panel_view.lua`: dimensions, palette, and shared labels.
- `src/states/agent_action.lua`: resolution and view updates. Hand artwork and
  previews are prepared for the remaining draw pile before activation, so newly
  drawn card types are immediately inspectable.
- `location_exploration_panel:setCell`: resets location-specific hover, scrolling,
  and summary layout after movement, reusing the existing image cache.

There is no usage counter or cooldown. Availability derives from current state,
including cleared engagements. Placement stays owned by `agent_deployment`.

## Verification

Run `love . --test`. `tests/agent_basic_actions.lua` covers repeated/mixed actions,
zero AP, occupied destinations, invalid/empty cells, engagement locks and clearing,
stale draws/moves, duplicate commits, invalid attack data, final-AP attacks,
defeat with retained effects, inactive Agents, and configuration validation.
State checks cover buttons, A, map opening, cancellation, invalid targeting,
map/location/hand updates, new card previews, input locks, and defeat return.

Screenshots: `tests/agent_basic_actions.png`, `tests/agent_move_targets.png`,
`tests/agent_basic_actions_spent.png`, and `tests/agent_basic_actions_engaged.png`.
