# Agent inspection previews

Hover an Agent in preparation, deployment, Mission Action, or Agent Action to inspect
its full artwork, tags, Methods (one icon per point), all six labeled Talent ratings
in two columns of three (labels and values use Undead Pixel 8),
Health, Defiance and resources. During preparation and deployment, resources are
explicitly starting values. During missions, engaged Enemy count appears on the left
and current resources on the right of a single Undead Pixel 8 line. Health/Defiance
show only current values (definition values before the mission), using the Asset
preview's shared colored Health / Defiance line, including zero values. The engaged
Enemy label and count turn #ff4444 when the count is greater than zero. Active status,
action counts and hand/draw rules are omitted. Ready, exhausted and defeated status
remain visible where applicable. Missing Talent entries display zero.
Both right-click instructions use uppercase Undead Pixel 8 at 8px, separate
from the rules font. Hover previews draw above the decorative screen seam.

Preparation uses fixed opposite-side positions. The preview avoids the actual hovered
portrait and Deploy/Reroll buttons. Pointer input passes through previews, so moving
to a covered Agent immediately inspects it and moves the panel to the opposite side.
Mission previews try the map center first, then positions that clear the hovered
portrait. Placement is bounded by the virtual screen; physical window scaling uses
the existing input transform. Unsupported layouts with no valid placement suppress
the panel rather than cover the inspected portrait. Shift + wheel scrolls overflow.

Inspection never changes selection or action eligibility. Exhausted/defeated Agents
remain inspectable. Roster gaps are split between neighboring portraits to avoid
flicker; map clusters follow visible portrait stacking. Previews are cleared during
dragging, focus loss, rerolls and state exits, and are suppressed during transitions
and attack feedback. Only one Agent, hand-card or location-card preview is visible.

## Deck, discard and Fate

Right-click an Agent portrait in Preparation, Deployment, Mission Action or
Agent Action to open the detailed inspection panel. Exhausted and defeated
Agents are inspectable. On the map, visible portraits take priority over their
hex. Right-click an exposed part of a hex or an army label for battlefield
inspection.

- **Deck** shows the starting recipe before Ready and the remaining draw pile
  during the mission. Rows show the count of each card definition, alphabetized
  by name. The order of the draw pile stays hidden.
- **Discard** shows current discards in the same grouped format. Click a card
  row on either tab for its full preview. Use the mouse wheel over the preview
  to scroll its rules.
- **Fate** shows planned contributions in Preparation and recorded contributions
  from Deployment onward. Copies of a tile share one row. Select a row to see
  its value, artwork, automatic outcome or Clash details where applicable.

Click the close button, click outside the panel, right-click or press Escape
to dismiss it. The panel captures input while open.

## Ownership and configuration

- `data/agent_preview_view.lua`: layout, artwork/icons, stat labels, Talent order,
  edge margins and resource/status labels.
- `src/sys/agent_display.lua`: read-only normalization from Agent definitions,
  shared status defaults, and optional live session status.
- `src/ui/preview_placement.lua`: bounded placement avoiding portrait/control bounds.
- `src/ui/agent_inspection.lua`: inspection hit detection and state integration.
  Lazily creates the preview on first inspection. Owns its view and releases it
  on exit/reroll. The existing preview renderer supplies fonts, art loading,
  layout, clipping and scrolling. Live content refresh preserves scroll and sound.
- `src/sys/agent_inspection_data.lua` builds grouped summaries from deck recipes,
  live card piles and the Agent's contribution records.
- `src/ui/agent_inspection_panel.lua` and `data/agent_inspection_view.lua`
  manage the tabs, list, item details and layout.
- `card_preview_controller` distinguishes `player_card`, `location`, and `character`.
  Agent Action shares its existing controller; other states own a controller.

No new gameplay state or selection restrictions are introduced. The preview is a
read-only presentation of existing data; future effective-stat modifiers can feed
this adapter when the rules exist.

## Verification

`love . --test` includes preparation previews on both sides, all six roster targets,
button/portrait avoidance, gap inspection, reroll/focus cleanup, deployment dragging,
live stat refresh, exhausted/defeated inspection, controller switching, hand-rule
omissions, zero stats and smaller placement bounds. Screenshots are written to
`tests/agent_preview_*.png`.

## Asset slots beside the portrait

The Agent preview is 280 pixels wide. Its 176-pixel portrait is right aligned;
the left sidebar shows Asset slots as two columns of 32-pixel squares with 4-pixel
gaps and a 12-pixel gap to the portrait. Each occupied slot's first position uses
the native 30-pixel Asset mini portrait. Empty slots retain teal outlines. The grid
snakes through successive rows so consecutive slots remain adjacent. An odd final
slot sits beside the portrait, leaving the bottom-left outer-border position blank.

Before equipment state exists, capacity comes from `agent_equipment_slots` and all
slots are shown empty. Live previews read `agentAssets.slots` and `Assets:at` without
changing equipment. A multi-slot Asset shows its portrait only in its first slot,
with all its occupied cells filled teal and the gaps between adjacent cells bridged
to form one contiguous shape, including across rows. There are no numbered markers. Assets remain
visible for defeated Agents. The display is informational and has no equip/drag input.

`assetSlots` in `agent_preview_view` configures the grid, label, and mini artwork paths.
`preview_asset_slots` handles its layout and drawing. The existing preview image cache
loads each encountered mini image once and releases it with the preview; missing
artwork uses the standard placeholder. Tests cover empty slots, a multi-slot Asset,
the seventh occupied slot, live clearing, and an even-capacity grid.

## Inspection-session audio

Agent previews appear and switch immediately. The first preview in an inspection
session plays the existing cardView cue; switching Agents or moving between their
roster/map portraits stays silent. Brief gaps also stay silent. Leaving Agent
portraits for 0.3 seconds rearms the sound for the next inspection. Configure this
with inspectionSoundResetDelay in data/agent_preview_view.lua. Dragging still
suppresses previews. Card and location preview sounds retain their existing rules.
