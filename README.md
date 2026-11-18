# 100 Days of Sin

Run the project with LÖVE: `love .`

See [Doom clock](docs/doom-clock.md) for mission pressure, JACL exhaustion,
configuration, and module ownership.

Launch the standalone palette utility with `love . --palette "colors.txt"`.
See [Palette Builder](tools/palette/README.md) for preview controls and PNG export.

## Mission preparation

Entering preparation refreshes the biome, JACL, captain, and agent indexes, reads
`data/prep_pool.lua`, and generates a package with `biomeId`, `jaclId`, `captainId`,
and an ordered `agentIds` array. Selections are uniform and can repeat between
visits; agents are distinct within a package. The package stays fixed during a
visit. All four pools are validated before any random draw.

The biome pool uses `source = "biomes"`. Set `ids = "all"` to use the index's
entire catalog, or an explicit array such as `ids = { "the_cut" }`. Empty pools,
unknown IDs, duplicate IDs, and unknown sources produce descriptive errors.
The required `jacl_pool` uses `source = "jacl"` and the same `ids` options,
resolved through `data/jacls/index.lua`.
The required `captain_pool` uses `source = "captains"` and the same `ids` options,
resolved through `data/captains/index.lua`.
The required `agent_pool` uses `source = "agents"`, the same `ids` options, and
`count = 6`. It resolves through `data/agents/index.lua` and samples without
replacement. Count must be a positive integer no greater than the number of
eligible IDs. Selection never modifies catalog or configured ID ordering.

## Biome artwork and animation

Place PNGs in `assets/images/biomes/<biomeId>/`. The renderer draws `bg.png`
first, then numbered files from highest to lowest numeric value. Numbering gaps
are allowed. All images repeat horizontally; the background never moves.
Each layer wraps at its own width. Images scale proportionally to the preview's
height, so the current 360-pixel-tall assets render at their original size.

The preview fills `(0, 360, 1280, 360)` on the game canvas. The existing viewport
scaling and letterboxing apply normally. Text remains in the upper half.

Each biome definition may contain a `parallax` table:

```lua
parallax = {
    direction = "left", -- "left" or "right"
    baseSpeed = 12,      -- Farthest numbered layer, game pixels/second
    speedStep = 8,       -- Increase for each closer numbered layer
    backgroundColor = { 0.08, 0.10, 0.14, 1 },
    speeds = {
        ["1"] = 48,     -- Optional override by numeric filename, without .png
    },
}
```

Omitted settings use `data/parallax_defaults.lua`. Speeds must be finite and
nonnegative; zero freezes a numbered layer. Default speeds follow layer order,
not the distance between filename numbers.

Missing directories, backgrounds, or unreadable images keep the selected biome
and use the remaining artwork over the solid background. Diagnostics appear in
the console and a brief notice appears above the preview.

## JACL sprite and entrance

Place each sprite at `assets/images/jacls/<jaclId>.png`. The sprite starts fully
offscreen to the left, drives in over all parallax layers, and parks at the
canvas's bottom center. At the default scale, current sprites occupy
`(448, 632, 384, 88)` when parked. Parallax continues moving after arrival.
Re-entering preparation creates a new package and restarts the entrance.

Each JACL definition may override these shared defaults from
`data/jacl_preview_defaults.lua`:

```lua
preparation = {
    scale = 1,                       -- Positive multiplier of image dimensions
    entranceDuration = 2,            -- Seconds; zero parks immediately
    entranceEasing = "easeOutQuad",  -- Deceleration; "linear" for constant speed
    bottomOffset = 0,                -- Game pixels above the canvas bottom
}
```

Duration and bottom offset must be finite and nonnegative. Sprites use nearest
filtering to preserve pixel edges. Missing or unreadable sprites use a named
placeholder with the same entrance and retain the chosen ID. Detailed diagnostics
go to the console, with a brief notice in the upper half of the screen.

## Captain panel

Captain portraits load from `assets/images/captains/<captainId>.png`. The panel
uses `assets/images/ui_elements/cpt_panel.png`, drawn at native size at `(16, 376)`
on the 1280 x 720 canvas. The portrait's center matches the panel's center exactly.
The panel renders above the parallax and JACL, building into view on entry.

The name is centered above the portrait using `Not Jam UI 12.ttf` at 12 pixels.
The title is centered below it using `Undead Pixel 8.ttf` at 8 pixels, preserving
explicit line breaks. Text and colors come from `name.text`, `name.color`,
`title.text`, and `title.color` in each captain definition. Colors accept six-digit
RGB hex strings with an optional leading `#`.

Shared paths, font sizes, inset, and text spacing live in
`data/captain_panel_defaults.lua`. Text that exceeds the available panel space
produces a diagnostic without changing the requested font size. Missing artwork
uses a placeholder, missing fonts use the default font at the requested size,
and invalid colors use white. These fallbacks retain the selected captain ID.

## Agent roster

The upper half of the game canvas is black and contains a centered row of six
portraits, replacing the temporary preparation labels. Portraits load from
`assets/images/agents/<agentId>.png` and fit proportionally within 176-pixel
squares. The default 24-pixel gaps produce a 1176-pixel row with 52-pixel side
margins. Five one-pixel subdued grey dividers separate the portrait areas.

Names use `Not Jam UI 12.ttf` at 12 pixels in soft white, eight pixels below the
portraits. Explicit line breaks are preserved. A consistent two-line name area
keeps vertical placement stable between selections. The row follows package ID
order. Shared settings live in `data/agent_roster_defaults.lua`.

Missing images use same-size placeholders with the agent name below; a missing
font uses the default font at the requested size. Overflow produces diagnostics
without silently shrinking the font. Preview warnings sit at the bottom of the
upper partition. Images and the shared roster font are released on state exit.

## Preparation entrance animation

`data/preparation_entrance.lua` controls the coordinated entrance. A shared elapsed
timer in the preparation state starts at zero on every entry. The captain panel
slides from offscreen left over 0.22 seconds, then the portrait opens vertically
from a white horizontal line over 0.28 seconds. Its artwork stays at its normal
size behind an expanding reveal area. The white line fades over 0.08 seconds.
Name and title then wipe left to right together over 0.25 seconds.

Agent portraits drop from above the upper partition in 0.24 seconds each, staggered
by 0.10 seconds from left to right. Each name appears only after that agent lands.
Dividers and buttons stay stationary. Portraits and placeholders follow the same
timing, and clipping is restored after each draw. Final positions use the existing
layout. The sequence does not alter the package or the JACL's independent drive-in.

`src/ui/animation.lua` supplies shared progress, easing, and interpolation helpers.
The panel and roster accept an optional elapsed time in `draw(time)`; omitting it
renders the completed layout for previews.

## Preparation buttons

Deploy and Reroll appear side by side below the agent names, centered as a group.
Deploy displays at 178 x 42 (2x scale), while Reroll stays at 89 x 21,
with 16 pixels between buttons and 16 pixels
below the roster's reserved name area. Order, paths, fallback sizes, and spacing
are configured in `data/preparation_buttons.lua`.
Buttons align by their vertical centers, with placement snapped to whole canvas
pixels to preserve thin borders. Odd/even heights introduce at most a half-pixel
center difference.

The buttons swap to their `_hover.png` images while the pointer is inside their
rectangles. Pointer positions are converted to game coordinates each update,
including after resizing. Leaving the window or entering the letterbox area
clears rollover. Neither button has a separate pressed image. Deploy opens the deployment board.

Left-click Reroll (press and release over the button) to refresh all definition
indexes, reload `data/prep_pool.lua`, and generate an entirely new package.
Successful replacement plays `assets/audio/sfx/roll.wav` once and restarts the
JACL, captain, agent, and parallax previews. Repeats between packages remain
possible; the six agents within a package stay unique. Releasing outside the
button or losing window/mouse focus cancels the pending click.

Replacement previews are built before the current package is released. Invalid
pool data keeps the current package and animation progress, reports a diagnostic,
and does not play the roll cue. Buttons and the audio controller survive rerolls
so playback is not cut off by rebuilding previews. `rollSound` in
`data/preparation_buttons.lua` controls the sound path.

A missing hover image keeps the base image; a missing base image uses a labeled
placeholder. Images are released when preparation exits.

Entering either button plays `assets/audio/sfx/hover.wav` once. Remaining over a
button is silent; leaving and returning plays the cue again. The path is set by
`hoverSound` in `data/preparation_buttons.lua`.

`src/sys/audio_controller.lua` loads named short effects once and provides
`play(id)`, `stop(id)` (or `stop()` for all), `setVolume(0..1)`, and `release()`.
Replaying a cue restarts its cached source, avoiding overlapping copies of the
same effect. Missing sounds report a diagnostic and remain silent. Preparation
releases its controller on exit, except when handing it to deployment.

## Preparation accents

`data/preparation_theme.lua` defines the restrained teal/grey palette and font
paths. New headings use Not Jam UI at 12 px, while slot numbers and the
DEPLOYMENT ZONE label use Undead Pixel at 8 px. These render at native scale.

`data/preparation_accents.lua` enables and tunes five accents: a one-pixel
partition seam with short ticks, 01–06 slot numbers, short portrait landing
highlights that fade to grey over 0.3 seconds, a lower-right biome label over a
translucent black backing, and a 0.4-second seam pulse on successful rerolls.
Failed rerolls do not trigger the pulse. Decorations settle after their events;
they do not loop. The roster owns landing accents, while
`src/ui/preparation_accents.lua` owns the seam, biome label, and reroll pulse.

## Checks

Run `love . --test` from a writable project checkout. The LÖVE integration checks
exit automatically and write `tests/results.txt` plus biome, JACL, captain, and roster renders to
`tests/`. Magenta above the preview in those test images is an intentional
clipping check. The checks cover pool validation, deterministic selection,
numeric layer sorting, real image loading/rendering, clipping, scrolling,
fallbacks, JACL entrance timing/position/scale, captain layout/fonts/colors,
unique agent selection, restricted pools, roster layout/clipping/fallbacks,
preparation state entry/exit, button positioning and rollover, scaled/letterboxed
pointer input, missing button images, reroll success/failure and animation restart,
canceled clicks, rapid rerolls, deployment layout validation, committed selection,
scene ownership transfer, and uninterrupted animation during deployment.


## Deployment board

Left-click Deploy (press and release over the button) to commit the selected
package and enter `mission_deployment`. The roster, names, dividers, slot numbers,
and both buttons are replaced by nine flat-top hex frames in the upper
half. One center, six neighbors, and two side tips form a diamond with columns
of 1, 2, 3, 2, and 1 cells. The board supports starting agent assignments; mission movement and encounter
rules are not implemented yet.

`data/deployment_board.lua` defines stable cell IDs in `cells` and flat-top axial
coordinates (`q`, `r`), plus radius, edge gap, panel padding, line width, and
colors. Defaults use a 56-pixel radius, 6-pixel gap, and the existing teal accent.
`src/ui/hex_grid.lua` validates the nine unique IDs and coordinates, centers the
cluster, checks that it fits, and draws it without loading new image assets.
Invalid board settings leave preparation and its selection intact.

`src/states/mission_deployment.lua` copies the committed selection, including
its agent ID array. `src/ui/mission_backdrop.lua` transfers ownership of the
existing biome, JACL, captain, and accents before preparation exits. Their
animation clocks and assets continue unchanged; deployment releases them on
exit. The committed biome, JACL, captain, and agents are not rerolled when deploying.

The integration checks also write `tests/deployment_board.png` for visual review.


### Location assignment and artwork

Each biome's `loc_pool` is an explicit array of IDs from `data/locations/index.lua`.
On Deploy, the location index refreshes and `src/sys/deployment_generator.lua`
validates the selected biome's pool before any random draws. Copies of the pool
and cell IDs are independently shuffled, then paired until nine cells are filled
or the pool runs out. Locations never repeat; unused cells stay empty. Assignments
are stored by cell ID for the lifetime of the deployment. Source data is unchanged.

An empty pool is allowed. Missing pools, unknown IDs, duplicate IDs, and sparse
arrays reject deployment and keep preparation intact. Location subfolders only
organize definitions; eligibility comes from the biome's explicit pool.

Place PNGs at `assets/images/locations/<locationId>.png`. Recommended artwork is
112 x 97 pixels (or 224 x 194 for higher resolution) for the current radius.
Keep focal details centered because the rectangular corners are clipped.
`artwork.directory` and `artwork.filter` in the board settings configure loading;
nearest-neighbor filtering is the default.

Each biome can set `loc_col = "ffe6a8"` to color all nine hex outlines.
Colors accept six-digit RGB hex strings, with an optional leading `#`.
Omitting `loc_col` uses the board's default `frameColor`; invalid values also
use that default and report a console diagnostic. Artwork and fills are unchanged.

`src/ui/location_art.lua` loads assigned images once, scales them proportionally
to cover the hex, and uses textured hex meshes to clip the image precisely.
Frames draw over the artwork. Missing/unreadable images retain their assignment,
show a muted cross, and report a console diagnostic. Images and meshes are released
on deployment exit, including cleanup if artwork preparation fails.

Location checks cover seeded reproducibility, pool exhaustion, excess locations,
unique assignments, randomized cell selection, validation before random draws,
missing images, clipping with a wide contrasting image, and resource cleanup.


### Deployment agent roster

The six committed agents appear to the left of the hex board in preparation
order, left to right across three columns, then the second row. Images load from
`assets/images/agents/<agentId>_mini.png` and display in 50-pixel squares with
8-pixel gaps. The 166 x 108 group is centered vertically beside the board, with
32 pixels of clearance from the board's outline bounds. The hex board keeps its
original position and size.

`data/deployment_roster_defaults.lua` controls columns, portrait size, gaps,
directory, and suffix. `src/ui/deployment_roster.lua` owns loading, layout,
drawing, and cleanup. Portraits use nearest filtering and proportional fitting;
missing images keep their slot and show a muted placeholder with a console
diagnostic naming the agent. This roster stays available for selecting and dragging assigned or unassigned agents.

Deployment builds the roster before committing the transition, cleans up on
construction failure, and releases images on exit. Integration checks cover
committed ordering, layout, missing images, proportional fitting, and cleanup.
The combined view is rendered to `tests/deployment_board.png`.

Successful Deploy clicks play `assets/audio/sfx/button.wav` once, configured by
`deploySound` in `data/preparation_buttons.lua`. The audio controller transfers
to deployment so the cue finishes across the state transition, and is released
when deployment exits. Canceled clicks and failed deployments do not play it.


### Deployment transition

A successful Deploy enters deployment immediately and disables preparation input.
The upper panel animates for approximately 1.2 seconds while the biome, captain,
JACL, and deployment sound continue normally. Buttons and roster decorations fade
out in 0.12 seconds. All six portraits move and shrink together into the left mini
grid over 0.35 seconds, crossfading to their mini artwork between 0.08 and 0.30
seconds. An early click starts from the current preparation entrance positions.

After agents settle, hexes drop vertically from fully above the upper panel in
three groups, ordered left to right:

1. West, Southwest, South, Southeast, East (the lower bowl).
2. Northwest, Center, Northeast.
3. North.

Each fall accelerates over 0.18 seconds, starting 0.045 seconds after the previous
cell in its group. The next group waits for the last landing plus 0.02 seconds.
Empty frames animate too; artwork, fill, and outline share the same translation,
so clipping remains attached to the moving hex. Assignments are generated once.

`data/deployment_transition.lua` controls all timings and the explicit groups.
`src/ui/deployment_transition.lua` validates the schedule, snapshots portrait
positions, calculates poses, and owns the temporary preparation roster/buttons.
Each cell must appear exactly once. Invalid transition data keeps preparation
intact. Buttons are released after fading, full portraits after transforming,
and interrupted transitions release all remaining temporary resources.

The integration suite exercises early deployment, canceled/repeated input,
invalid schedules, missing portraits, interrupted cleanup, and long frames.
It writes `tests/deployment_transition_1.png` through `_9.png` for visual review
of the start, portrait transformation, bowl, middle layer, and completed board.

After the final hex lands, the instruction "Drag an Agent to a location to deploy
them there" fades in over 0.15 seconds to the right of the map. It uses the shared
heading font and text color, with placement relative to the board bounds.
`data/deployment_prompt.lua` controls text, fade duration, width, and spacing.
Agent dragging becomes available after the prompt has fully faded in.


Deployment also plays `agent_deploy.wav` once when the portrait transition begins
and `hex_deploy.wav` once for each hex landing, including empty cells. Paths are
configured by `agentDeploySound` and `hexDeploySound` in the preparation button
settings. These cues use independent audio voices, allowing agent, button, and
successive hex sounds to overlap without cutting each other off. Landing events
fire once even when a long frame crosses several landings. Finished voices are
released automatically; leaving deployment stops and releases remaining voices.
The audio controller's `playOverlapping(id)` opts into this behavior; ordinary
`play(id)` retains its existing restart behavior for hover and reroll sounds.


### Dragging agents to starting locations

After the entrance sequence and prompt fade, left-drag an agent from the roster
or its map portrait to a populated hex. All six agents may share a location.
Each agent has one placement; dropping it elsewhere reassigns it without making
a copy. Empty frames reject drops. Release over the left roster to unassign.
Invalid drops preserve the previous placement; Escape, loss of focus, leaving
the window/letterboxed game area, or exiting deployment cancels a drag. Movement
must exceed the configured four-pixel threshold before a press becomes a drag.

The roster keeps its original order and marks assigned agents with a small red (`#ff4444`)
square. Hover links a roster portrait to its location. On-map mini portraits
remain 50 x 50 at native size. Occupancies 1�6 use rows of 1; 2; 2+1; 2+2; 3+2;
and 3+3. Rows are centered independently, overlap horizontally as needed, and
have a one-pixel vertical gap. All portrait draw positions are whole pixels.
Vertical and corner overhang is intentional; portraits are not clipped to hexes.
Hovering an exposed portrait raises it above every cluster and holds that order
while the pointer stays inside it, avoiding hover flicker. The left roster also
provides access to every agent regardless of overlap.

`src/sys/agent_deployment.lua` stores agent-ID-to-cell-ID placements separately
from the cell-to-location assignments, deriving occupants in original agent order.
`src/ui/agent_drag.lua` tracks a pending/active drag without changing assignments
until a valid release. `src/ui/location_agents.lua` owns cluster layout, hover,
and indicators, reusing the roster's textures. `data/agent_deployment_defaults.lua`
controls row arrangements, row gap, horizontal inset, drag threshold, and colors.
Hex picking uses polygon boundaries, and input uses the existing canvas conversion.

Checks cover all six occupancy arrangements, whole-pixel placement, exposed hover
areas, reassignment, unassignment, invalid/empty drops, cancellation, early input,
missing art, cleanup, and dragging through scaled/letterboxed window callbacks.
`tests/agent_cluster_1.png` through `_6.png`, `agent_cluster_hover.png`,
`agent_clusters_adjacent.png`, and `agent_drag.png` show the interaction layouts.

Successful agent drops onto a new location play `assets/audio/sfx/agent_move.wav`,
configured by `agentMoveSound` in the preparation button settings. Playback allows
overlap. Invalid/canceled drops, drops onto the same location, and returning an
agent to the roster remain silent.


### Ready button

A Ready indicator fades in over 0.15 seconds after the deployment notification
finishes appearing. It sits 16 pixels beneath the rendered text, centered on the
actual wrapped text width. Its 89 x 21 artwork draws at exactly 2x (178 x 42),
with nearest filtering and whole-pixel placement. The notification stays in place.

`data/deployment_ready.lua` configures image paths, native dimensions, scale,
spacing, and fade duration. `src/ui/deployment_ready.lua` owns image loading,
layout, drawing, and cleanup. Missing or incorrectly sized images use a labeled
placeholder and produce a diagnostic.

`agentDeployment:allAssigned()` selects `ready_btn_true.png` only when every
agent has a valid committed location; otherwise it uses `ready_btn_false.png`.
Sharing one hex counts as ready. Returning an agent to the roster restores the
false image. Dragging alone does not change readiness. Once fully visible and
ready, a completed left-click enters Mission Action and plays `ready.wav`.
No Ready hover effect is applied.

Checks cover exact sizing and centering, fade timing, image selection, missing
artwork, five/six assigned agents, shared hexes, unassignment, and cleanup.


Assigned portraits in the left roster fade to 50% brightness over 0.1 seconds;
unassigned agents remain fully bright. Hovering an agent (in either view) or
dragging it restores roster brightness, and unassigning restores it immediately.
Map portraits and dragged copies retain their existing appearance. Assignment
badges use `#ff4444` and remain bright. `assignedBrightness`,
`brightnessFadeDuration`, and `assignedColor` in the agent deployment defaults
control these settings.

Map portraits have a hard-edged black shadow, offset two pixels down and right at 60% opacity. Each shadow follows its portrait's stacking order and drag opacity. Configure it with mapShadow in data/agent_deployment_defaults.lua.


## Mission Action

Ready advances to `mission_action` only after the deployment entrance and Ready
fade finish, all agents have valid assignments, and no drag is pending. Press and
release must occur over Ready; focus loss, Escape, or release outside cancels.
The action panel is prepared before the state changes, so setup failure leaves
current deployment resources and placements intact.

The same board, location artwork, agent placements, roster, backdrop, and audio
are transferred via `src/sys/mission_session.lua`. No selection is rerolled and
no backdrop animation restarts. The new state releases shared resources when it
exits. Deployment-only controls and the dragging controller are discarded.

Roster portraits brighten during the short crossfade, deployment badges fade away,
and the old instruction and Ready button are replaced by a centered
"CHOOSE AN AGENT TO ACT" heading above the roster and Act below it. Act stays at
native 89 x 21 size (1x), with nearest filtering and whole-pixel placement.
`data/mission_action.lua` configures the text, spacing, image paths, and colors;
`src/ui/mission_action_panel.lua` owns its presentation and image cleanup.

Left-click an agent in either view to select it. A warm yellow outline marks both
portraits and Act switches from `act_btn_false.png` to `act_btn_true.png`. The
selected map portrait stays raised; hovering another temporarily raises it above
the selection. Right-click anywhere in the game view to deselect. Empty clicks
preserve selection. Completed portrait clicks are required; focus loss or pointer
movement beyond four pixels cancels a pending selection. Dragging cannot move or
unassign agents in this state. Clicking the enabled Act button commits the selected agent and enters Agent Action.

Checks cover Ready eligibility and cancellation, failed handoff recovery, resource
ownership and backdrop continuity, both portrait selection paths, right-click
clearing, drag prevention, native button layout, and cleanup. Screenshots are
written to `tests/mission_action.png` and `tests/mission_action_selected.png`.

Successful Ready activation plays `assets/audio/sfx/ready.wav` once, configured
by `readySound` in the preparation button settings. It uses overlapping playback
and the transferred audio controller, so it continues through the handoff to
Mission Action. Disabled/canceled clicks and failed transitions remain silent.


### Mission Action crossfade and selected portrait

The Ready handoff crossfades the interface over 0.2 seconds. The old notification,
Ready button, and assignment badges fade out over 0.12 seconds. The action heading
and Act button begin fading in after 0.04 seconds and finish at 0.2 seconds. Roster
portraits brighten smoothly from their current values to full brightness. Dragging
ends immediately; selection remains gated until the crossfade completes. The map,
placements, backdrop, and Ready sound continue uninterrupted.

Selecting an agent in either view shows `assets/images/agents/<agentId>.png` in
a 176 x 176 area centered to the right of the map, matching preparation portrait
size. Artwork fits proportionally with nearest filtering and whole-pixel placement.
Changing selection changes the portrait; right-click deselection hides it. Missing
artwork displays an ID-labeled placeholder. The six images are cached during action
preparation by `src/ui/selected_agent_portrait.lua` and released on action exit.

Timing and portrait placement settings live in `data/mission_action.lua` under
`transition` and `portrait`. Outgoing Ready artwork is retained only until its fade
finishes, including safe cleanup if the state exits early. Checks cover input gating,
portrait placement, missing-image drawing, and interrupted-transition cleanup.
Transition snapshots are `tests/mission_action_transition_start.png` and
`tests/mission_action_transition_mid.png`; the selected portrait appears in
`tests/mission_action_selected.png`.

Selecting or changing the selected agent in Mission Action plays `button.wav`
once via the `selectionSound` setting. Re-clicking the same agent, deselection,
and canceled clicks remain silent. The full portrait displays the agent
definition's name centered eight pixels below it, preserving explicit line breaks
and using the shared 12-pixel heading font. Name spacing and color are configured
under `portrait` in `data/mission_action.lua`. Both portrait and name disappear
on deselection.

Selected full portraits have short, one-pixel muted-teal corner brackets with three pixels of clearance and an AGENT SELECTED label in the shared small pixel font. All positions are snapped to canvas pixels. Configure label, spacing, lengths, and colors under portrait.accents in data/mission_action.lua. The accents disappear along with the portrait on deselection.

Full agent portraits reveal outward from a one-pixel horizontal center strip over
0.12 seconds on a new selection. Artwork retains its normal scale behind a
pixel-snapped expanding clip; the name fades in over the final 0.06 seconds.
Brackets and the AGENT SELECTED label stay stationary and fully visible. Changing
agents restarts the reveal, re-clicking the same agent does not, and deselection
clears everything immediately. Configure revealDuration and nameFadeDuration in
the portrait settings. Render checks include agent_portrait_reveal_start.png and
agent_portrait_reveal_mid.png under tests.


## Agent Action

Clicking and releasing the enabled Act button enters `agent_action`. The roster,
selection prompt, and Act button disappear. Map agents remain in their assigned
locations, with the active agent highlighted, and no longer accept selection,
deselection, or dragging.

The full portrait, name, and accents slide right over 0.15 seconds, ending with
24 pixels between the outer bracket and the canvas edge. Size and vertical
position are preserved; positions remain snapped to whole pixels. Any ongoing
portrait reveal continues through the transition. The board, backdrop, audio,
and portrait resources transfer to the new state without being recreated.

`data/agent_action.lua` configures the margin, slide duration, and active-agent
color. `src/states/agent_action.lua` owns the state and slide; the existing
portrait and map presentation modules are reused. No card or action-resolution
mechanics are introduced. Integrated checks cover entry guards, canceled clicks,
resource transfer, locked interactions, placement preservation, and cleanup.
Snapshots are written to `tests/agent_action_transition.png` and
`tests/agent_action.png`.

Clicking the enabled Act button plays `assets/audio/sfx/agent_act.wav` once on
successful entry into Agent Action. Disabled, canceled, and failed transitions
remain silent. The cue uses the shared audio controller and can overlap other
sounds without being cut off by the state transition.

Agent Action equipment placeholders
----------------------------------
Agent Action displays seven visual equipment slots beneath the portrait, aligned
24 canvas pixels from the right edge and 12 pixels above the parallax. Each
50 x 50 frame has a one-pixel teal border, four pixels of interior padding, and
a 40 x 40 solid color block. Adjacent frames are four pixels apart. The row
appears on entry and remains stationary during the portrait slide.

Configure stable slot IDs, left-to-right order, and placeholder colors in
`data/agent_equipment_slots.lua`. Configure dimensions, spacing, margins, and
frame/background colors in `data/agent_equipment_view.lua`. The renderer is
`src/ui/agent_equipment_row.lua`, owned by Agent Action. It uses the existing
virtual canvas, so the row scales with the rest of the game. Data is validated
before the session transfers; invalid settings leave Mission Action intact.
These placeholders are shared by all agents and have no input or gameplay effects.
The Agent Action integration check verifies rendered frame/padding/block pixels,
stationary placement during the transition, invalid-data recovery, and cleanup.

Card deck and hand configuration, lifecycle, controls, and verification are documented in docs/card-system.md.

## Agent opening hands and activation draws

Ready begins the mission and deals every agent up to five cards. Each activation,
including the first, draws one card. Next Phase restores actions and grants its
resource gain without drawing. Hands have no ongoing minimum or maximum; empty
decks do not reshuffle. Shared counts live in `data/card_system_defaults.lua`, with
optional `card_rules` overrides on agent definitions. See `docs/card-system.md`
and `docs/agent-turns.md` for lifecycle ownership and validation details.

## Exploring locations

During Agent Action, the panel left of the hex map shows the current location's
remaining deck total, remaining card types, and revealed cards. Click Explore to
spend one action point and reveal one card. Revealed tiles have no cost box and
persist for other agents visiting that location. Scroll over the list to inspect
older reveals. Empty decks do not reshuffle, and revealed encounters do not yet
resolve effects or combat. See `docs/location-cards.md` for settings and ownership.

Hover revealed location tiles to inspect full artwork, talent-test values, tags,
and defined stats in the shared card preview. Use Shift + wheel for preview scrolling;
normal wheel input scrolls the revealed list. Hovering never spends actions or draws.

Enemies revealed by Explore now engage the revealing Agent. Their tiles and hover
previews name that Agent, and the location panel shows the active Agent's engagement
count. Engagement persists between turns and phases and clears on discard. Successful actions now provoke attacks from Enemies already engaged when the action
began. See `docs/attacks.md` for the shared attack system and defeat handling.

## Opportunity attacks

Card play and Explore complete first, then previously engaged Enemies attack in reveal
order. Damage reduces Health; trauma reduces Defiance. Either reaching zero defeats
the Agent and stops further attacks. Sequential feedback highlights attackers and
shows stat changes. Defeated Agents retain their cards/assets/location but cannot act
or refresh; if all Agents are defeated, phase advancement stops. Combat rules and
presentation settings are in `data/attack_rules.lua` and `data/attack_feedback_view.lua`.


## Basic Agent actions

Open Actions with the button beneath the equipment row, the A key, or the active
Agent's map portrait. Move, Draw a card, and Gain 1 resource each cost 1 AP and
can be repeated while eligible. Move requires no engagements and an adjacent
populated location. See [Agent basic actions](docs/agent-basic-actions.md) for
controls, data modules, transaction rules, and checks.

## Full-size artwork layers

Full portraits and card previews use biome backgrounds and foregrounds, with
independent `card_bg` / `card_fg` overrides and `"none"` to disable a layer.
Mini artwork is unchanged. See [Layered artwork](docs/layered-artwork.md).
