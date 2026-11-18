# Agent decks and hands

Committing Ready after deployment begins the mission and deals every participating
agent up to five cards once. Each activation draws one additional card, including
the first activation (normally giving that agent six cards). Existing cards and
their order are preserved. Five is an opening target, not an ongoing minimum or
hand limit. Next Phase does not draw cards. Short decks supply only what remains;
empty decks draw nothing and do not automatically reshuffle.

## Definitions and settings

- Agent definitions use `card_deck = { { card_id = "catburglar", card_qty = 20 } }`.
  Quantities must be positive integers. Empty recipes are supported.
- `data/cards/index.lua` discovers card definitions recursively. Referenced cards
  require a nonempty `name` and a nonnegative integer `cost`.
- `data/card_system_defaults.lua` supplies `startingHandSize = 5` and `activationDrawCount = 1`.
- An agent may override either setting with `card_rules = { startingHandSize = 3,
  activationDrawCount = 2 }`. Omitted fields inherit shared defaults; zero is valid.
- `src/sys/agent_card_rules.lua` validates finite nonnegative whole counts and rejects
  unknown override keys. Rules are resolved at mission start and retained for that mission.
- `data/agent_hand_view.lua` supplies tile size, spacing, overlap, colors, and art
  paths. Mini-portraits use `assets/images/cards/<cardId>_mini.png` by default.
  Missing images display a question mark and report a diagnostic.

## Ownership and transitions

`src/sys/agent_cards.lua` expands recipes into distinct `{ instanceId, cardId }`
instances, shuffles each draw pile once, and owns independent per-agent piles and
hands. It accepts a random generator for reproducible checks. Card definitions
and agent recipes are not modified.

`src/sys/mission_lifecycle.lua` prepares detached card and status models during
Ready preparation. Opening hands are published only on successful mission entry;
failed preparation leaves deployment intact. All agents receive their hands before
any activation. Returning to Mission Action reuses the existing models. A new
mission gets fresh models.

`prepareDrawTo(id, size)` stages an opening target; `prepareDraw(id, count)` stages
a fixed draw. Both copy pile/hand arrays and preserve card instance identities.
`commitHand` publishes the staged arrays. Definitions and recipes remain unchanged.

`src/sys/agent_turn.lua` coordinates activation, finishing, and phase refresh.
Activation cards commit only after the interface has been prepared successfully.
`session.activeAgentId` prevents repeated commits or rebuilding the active interface
from drawing again. Finishing clears that marker and exhausts the agent. The
mission session carries the marker and models across screen transitions.

Agent Action owns the temporary hand view and its image cache. It releases those
images on exit. Future transitions that continue a mission must transfer the
session before exiting, following the existing session ownership pattern; the
Done transition follows this pattern when returning to Mission Action.

## Presentation and input

`src/ui/card_tile.lua` renders a mini-portrait, name, and cost in one strip.
`src/ui/agent_hand.lua` lays out and draws the hand and handles pointer hover and
wheel input. All copies of a card share one cached image within the view.

Tiles default to 182 x 32 virtual pixels, constrained by the portrait's final
left bracket. The column aligns with the asset slots' left edge and ends eight
pixels above their label. It grows upward toward a 24-pixel top margin, leaving
the map and portrait clear. Text uses the existing small game font; long names
are truncated. After the portrait slide finishes, tiles reveal bottom to top,
each fading in and rising six pixels over 100ms with ease-out motion. The normal
25ms stagger is reduced for crowded hands to cap the reveal at 200ms. Hover and
scrolling unlock after the reveal; scrolling does not replay it. Configure these
values with the `reveal*` fields in `data/agent_hand_view.lua`.

Asset slots fade in left to right immediately on state entry, over 80ms per slot
with a 20ms stagger. Their stationary label fades with the first slot. Configure
these timings in `data/agent_equipment_view.lua`.

Cards normally have four-pixel gaps. Crowded hands overlap, preserving at least
ten pixels of exposed height per card. Beyond that capacity, wheel input over
the hand moves through the cards one at a time. Hit testing uses the original
exposed strips; hovering draws that unique card instance last, without moving
it or reordering the hand. Leaving the hand or losing focus clears hover.

Asset cards can be dragged onto consecutive free asset slots and paid for from
the active agent's resources. See `docs/card-play.md`. Other card types,
discarding, and card effects are not yet implemented.

## Hover preview

`card_display` contains only the `p<number>` paragraph entries. The preview reads
`name`, `cost`, `card_type`, `asset_slots`, `tags`, `health`, and `defiance` directly
from the card definition. Top-level `methods` and `talents` use ordered
`{ type = "shadow", qty = 3 }` entries; quantities expand into repeated icons.
Quantities must be nonnegative integers (zero omits the icon). Tags are uppercased
only for rendering. Legacy non-paragraph fields in `card_display` are ignored;
they never override the card's information.

Hovering a revealed hand tile shows a fixed 240-pixel-wide preview centered on
the hex map, 24 pixels from the top. Its opaque panel extends into the parallax
as needed. Leaving the hand or losing focus hides it. Duplicate copies share
the same preview and image cache; switching between those copies preserves the
rules scroll position. Changing card definitions or hiding the preview resets it.

`data/card_preview_view.lua` configures dimensions, colors, spacing, image paths,
and scroll speed. `src/sys/card_display.lua` validates and normalizes display
fields. `src/ui/card_preview.lua` caches images, measures the sections, draws the
panel, and manages overflow. Agent Action prepares and releases this view with
the hand; invalid preview settings cannot consume cards or commit the transition.

The header shows the name beside one teal vertical pip per cost. Pips descend
from the top border to the bottom of the name's text area; zero cost has no pips.
Pip widths and gaps are configurable and compress for large costs to preserve
name space. Type sits on the left of the next row, with methods right-aligned
(wrapping within their column when necessary). Native-size 176px artwork sits
beside a top-aligned column of 32px talent icons, with 12px outer padding and an
8px gap between talents and art. The artwork aligns to the right padding. Images are
never enlarged; missing images display a question mark. Tags precede rules.
The footer is a single row: numeric health/defiance values and their dividing
slash on the left, all in Not Jam UI 12 at 12px,
and miniature 12px asset-slot frames on the right. The contents are
vertically centered between the separator and the card bottom. Health uses green
numbers (#44ffa1), followed by a neutral slash and red defiance numbers (#ff4444).
No text labels are shown. Empty stat groups and absent slot requirements are omitted.

Paragraph keys `p<number>` sort numerically, allow gaps, and contain arrays of
strings: strings within a paragraph use explicit line breaks, and paragraphs
have a blank line between them. Slot requirements appear only when positive.
The health/defiance pair appears when either value is positive, displaying zero
for the other value if necessary. Omitted display fields collapse.

Rules use Not Jam Novel 16 at 16px, configured by `rulesFont` and `rulesFontSize`,
with the small font for type, tags, and scroll hints. Internal hand gaps belong
to the preceding card's hover region, keeping previews open between tiles.

Paragraphs support `[exhaust]...[/exhaust]`, `[retask]...[/retask]`,
`[expend]...[/expend]`, `[tag]...[/tag]`, and `[talent]...[/talent]`.
Their colors live in `data/text_format_colors.lua`. The shared formatter in
`src/ui/formatted_text.lua` produces visible text for measurement and colored
segments for drawing; tags do not consume layout space. Tags may be nested,
and closing one restores the enclosing color. Each paragraph starts with the
default color. Unknown or mismatched tags remain visible literally; an unclosed
recognized tag colors the remainder of that paragraph.
Long rules scroll with Shift + mouse wheel while hovering the hand card, leaving
the header and footer visible. Ordinary wheel input still scrolls the hand.
Unusually large headers or icon lists use whole-content scrolling as a fallback.
The panel is capped at the screen height minus its top and bottom margins.
Checks include `tests/card_preview.lua`, `tests/card_preview.png`, and
`tests/card_preview_overflow.png`.

## Verification

Run `love . --test`. `tests/agent_cards.lua` covers recipe validation, instance
identity, deterministic shuffling, opening targets, fixed draws, exhausted piles, independent hands,
session transfer, overlap, scrolling, and missing artwork. Agent Action checks
cover failed preparation, delayed hover, repeated preparation, and cleanup.
Screenshots include `tests/agent_action.png` and `tests/agent_hand_overflow.png`.
