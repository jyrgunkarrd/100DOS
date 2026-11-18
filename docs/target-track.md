# Mission target track

Ready creates a session-owned `missionFooter` after preparing the selected hunt.
Portrait and font loading plus native-resolution fit validation happen before the
deployment hands over its scene. Invalid fit leaves deployment available with its
existing Ready error handling. The footer transfers with the mission between the
overview and Agent action states and releases its resources on mission exit.

`src/sys/mission_targets.lua` projects the champion instance followed by the ordered
company instance IDs into public objective entries. Bodyguards are excluded. The
projection resolves current instances every time, including hidden and discarded
cards: champion escapes replace instance tables, and damage can change without a
hunt revision. Current health comes from runtime instances; maximum health comes
from definitions. Locations and deck zones never enter the public entries.
Missing instances produce a diagnostic and `--/max`, never a false elimination.

`src/ui/mission_footer.lua` composes the existing scene accents and target track.
`preparation_accents:biomeLayout()` supplies the actual deployment label bounds.
The track sits to their left, bottom aligned, without duplicating label sizing.
Overview and Agent action draw the footer after feedback and outcome overlays so
the objective remains legible through victory. Observation uses the same footer.
Before Ready, preparation and deployment continue to draw the label alone.

`data/target_track_view.lua` configures asset paths, font, padding, gaps, minimum
panel sizes, champion decoration, health colors, dimming, and cross-out treatment.
Current minis are 30 by 30 pixels. They draw at native resolution with nearest
filtering and integer coordinates. Panels expand for larger assets or wider health
text; they never shrink portraits. Oversized rows fail fit validation rather than
clip, wrap, or hide targets. Missing images log once and retain a placeholder panel.

Eliminated entries stay in their original slot with a dim portrait, red X, and
readable zero health. The champion retains a gold border and tab. Champion defeat
still ends the mission immediately; surviving company remains visibly alive.

Defeated Company panels can be dragged onto any unrouted ordinary location during
normal mission or Agent action play. A successful drop spends that Company for
the mission and removes its panel from the row; the remaining panels close the
gap. The defeat and destination remain recorded by instance ID in
`missionHunt.routedCompanies`. Champion and Bodyguard cards cannot fund routing.
Invalid drops, Escape, right click and focus loss cancel without spending it.

`data/army_routing_rules.lua` defines the one-use rule, empty-army eligibility and
per-force milling policy. `src/sys/army_routing.lua` prepares the normal location
mill, including special-card entry, then validates and commits the rout. Every
enemy force counts once, including elites, using the battlefield milling rate.
Allied forces, protection and hunt Secure state remain unchanged. Empty armies
can be routed to prevent future Clashes, with no cards milled.

The army pair stores `routedBy`, clears its enemy forces and Clash queue, and
refreshes its values/revisions. Its enemy label becomes one red X. Routed pairs
reject future Clash creation and resolution, including Clash reinforcements.
`src/ui/army_routing_drag.lua` shares the drag controller and existing milling
feedback between mission views, with settings in the existing target-track and
army-label data files. Dialogs and resolving actions block routing; routing
feedback blocks new input. `tests/army_routing.lua` exercises both mission views,
invalid/cancelled drops, stale plans, spending, milling, labels and Clash guards.

Hovering any part of a target panel opens the existing location-card preview,
including hidden or eliminated targets. The session footer owns this preview so
it does not add hidden cards to location exploration or interfere with combat
feedback previews. Runtime health refreshes while the pointer stays still. Hover
exposes no location, engagement or hidden deck information. Moving away, losing
focus, closing observation, or changing mission views clears it. Mouse wheel
scrolls the hovered target's card text. Full-screen inspection dialogs retain
their existing input priority. Preview assets are loaded on first hover and are
released with the footer at mission exit.
Adjacent panels split their intervening gap at its midpoint, matching Agent
portrait inspection, so panning along the row never briefly clears the preview.
The outer edges and the panel bounds used for preview placement stay unchanged.

Initial population uses the shared procedural `src/ui/hunt_card_back.lua` design
from hunt distribution, fitted to each portrait's native bounds. Black panels and
the champion's gold decoration remain visible while anonymous backs cover the
portraits. At the start of dealing, backs crossfade into stationary portraits and
health, champion first with a short left-to-right stagger and fading gold outline.
`data/target_track_animation.lua` controls durations, stagger and highlight strength;
`src/ui/target_track_animation.lua` derives effects from `huntPresentation.elapsed`.
The existing gather/shuffle timing, accent and reduced-motion option are reused.
There is no extra clock, sound, input delay, or mapping from portraits to destinations.
Custom reveal timings compress to fit the distribution window when necessary.
Skipping settles immediately. Reduced motion uses one simultaneous fade with no
highlight pulse. Escape leaves all portraits and health visible and only pulses
the living champion's outline. Hover remains available throughout population.

Validation: `love . --test` includes `tests/target_track.lua`, plus committed combat,
escape, victory and cleanup assertions in `tests/mission_hunt.lua`. Rendered fixtures
include `tests/target_track.png`, `tests/hunt_zero_strength.png`,
`tests/hunt_victory.png`, and the Agent observation screenshots.
