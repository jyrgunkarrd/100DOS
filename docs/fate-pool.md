# Fate pool

Deployment constructs one mission-owned fate pool from the selected preparation
package. Each entry in an asset's `fate` array contributes one tile. Repeated IDs
are separate tiles, including repeats within the same asset.

## Inspection

Click **FATE POOL** below the Captain panel or press **F** in Deployment,
Mission Action, or Agent Action. The inspection shows the total number of
tiles in the built pool. Select a tile type to see its count, details, and contributing
Agents, Captain, or JACL. Reveals sample the main pool with replacement. Bonus tiles are held separately
in the unlimited shared BONUS RESERVE; use the modal switch to inspect them.
Before any test, commit any number with the clickable reserve tile row. Committed
modifiers stack with cards and are consumed on either outcome. Cancelling spends
nothing. Bonus tiles never dilute normal Fate probabilities or override automatic
outcomes. INGENUITY costs 2 AP, tests Reason 3, and grants one Genius on success.

Inspection is available while choosing a talent or Clash test. Dismiss it
with **F**, **Escape**, the close button, a right-click, or a left-click
outside the panel. The selected test and card commitments are preserved.
Transitions, drags, and result playback suspend access.

## Data

Tile definitions live in `data/fate_tiles/<id>.lua`. Each file returns a table
with a unique nonempty `id`. Optional fields follow this order.

- `name` displays a title above the tile contents.
- `value` is a finite nonnegative number. `negative = true` gives it a minus
  sign. An omitted value contributes zero to the test and hides the numeric
  line. An explicit zero displays as `+0`.
- `img = true` displays `assets/images/fate/<id>.png` above the value. Image
  IDs use letters, digits, underscores, or hyphens. Missing art keeps the
  available text readable.
- `special` accepts `auto_success` or `auto_failure`, both of which override
  the numeric comparison independently of the image.
- `bonus = true` routes a numeric tile to the reserve instead of the main pool.
  Bonus tiles cannot define automatic outcomes or Clash effects.
- `clash = { amt = 1, en_dmg = 1, en_bonus = 1 }` adds a batch to the
  revealing Agent's location. `amt` is a positive whole number. The other
  fields are nonnegative whole numbers, with zero used when omitted.

The tile index and runtime draw checks share the same validation. See
[Battlefield clashes](battlefield.md#clashes) for the turn sequence.

`data/fate_pool_defaults.lua` declares construction counts: Agents collectively
contribute 18 tiles, the Captain contributes 1, and the JACL contributes 1, for
20 total. Individual Agents may contribute different quantities as long as
their collective total is correct. Preparation currently selects six Agents.

## Runtime contract

`src.sys.fate_pool.build(selection, catalogues, tiles, settings)` is a pure
builder. `selection` contains `agentIds`, `captainId`, and `jaclId`;
`catalogues` contains `agents`, `captains`, and `jacls` catalogue snapshots;
`tiles` is a validated fate tile index snapshot. It returns:

```lua
{
    entries = {
        { tileId = "neutral", sourceType = "agent", sourceId = "apex", sourceIndex = 1, sourceName = "APEX" },
        -- One entry per contributed tile, including duplicates.
    },
    definitions = {
        neutral = { id = "neutral", value = 0 },
        -- Independent copies of every referenced tile definition.
    },
}
```

Entries follow selected Agent order and each Agent's listed fate order, followed
by Captain and JACL entries. This deterministic order does not define drawing
rules. Source types are `agent`, `captain`, and `jacl`.
Contributor names are captured from the selected definitions at build time.

Unknown assets or tiles, duplicate selected Agents, malformed arrays, invalid
settings, or incorrect contribution counts fail construction with diagnostics.
Inputs are never modified; missing tiles are never filled or skipped.

## Lifecycle

`Deployment.prepare` uses preparation's existing asset catalogue snapshots and
freshly loads tile definitions and construction settings. It builds the pool
before board generation and visual allocation. Failure leaves preparation
intact through the existing deployment error handler.

Deployment stores `fatePool`, then `mission_session` transfers ownership to
action phases. Agent turns and phase refreshes preserve the same pool. Leaving
the mission clears the owner's reference; a new deployment builds a fresh pool.

Pool construction does not define drawing or test rules. The talent-test system
now samples this pool with replacement; see [talent-tests.md](talent-tests.md).

Run `love . --test` for catalogue and pool validation, independent snapshots,
duplicate contributions, deployment failure recovery, and phase persistence.

## Bonus reserve ownership

`fatePool.reserve` contains physical bonus entries and shares the pool's definition
snapshot. It persists across Agent turns and phases, and resets for a new mission.
`src.sys.fate_reserve` validates selections, sums signed modifiers, adds copies,
and consumes committed copies. Initial asset contributions route by `bonus` after
construction counts are validated. Ongoing location sources grant a bonus once per
source instance and contribution index; subsequent synchronization cannot regenerate
a spent bonus. Ordinary ongoing fate contributions retain their existing lifetime.

The test UI submits `bonusCounts` keyed by tile ID. The shared action resolver
snapshots the reserve before preparation and rejects stale selections before Fate
randomness. Consumption accompanies successful action publication, including failed
tests and mission-ending tests. Result playback cannot spend tiles again.
# Transport contributions

Silencer transport definitions may declare `ongoing_fate = { "silence" }`.
Each listed ID contributes one drawable tile for each present transport instance;
duplicates and multiple transports stack. Bonus-reserve tiles are rejected during
catalogue validation because they do not have ongoing draw-pool semantics.

`src/sys/transport_fate_effects.lua` owns entries marked `transportEffect`, with
transport instance ID, source index, and display name. Synchronization retains
unrelated entries and reuses unchanged contributions. Drawing these tiles does
not consume them. The fate-pool inspection includes TRANSPORT contributors.

The phase coordinator synchronizes the visible transport group: the previous
group during activity feedback, the arriving/departing group during transport
presentation, and the remaining group at presentation completion. Departing
transports continue contributing through their departure presentation even though
the deployment rules have already cleared the active transport list. Normal and
reduced-motion modes produce the same pool when gameplay resumes.

`src/ui/silencer_activity.lua` supplies shared animated poses for drawing and
hover selection. `src/ui/transport_hover.lua` tests those poses in reverse drawing
order, ignores transparent pixels, and displays the transport name and grouped
fate tiles. Names also appear for transports without an ongoing effect. The
tooltip uses `data/silencer_view.lua` settings and yields to dialogs, cut-ins,
dragging, and the action panel under the cursor. Its images and pixel masks are
released with the mission backdrop.

`tests/transport_fate.lua`, run by the Silencer integration tests, checks source
ownership, stacking, repeated synchronization, drawing, departure timing, reduced
motion, validation, contributor display, transparency and overlapping hover hits.

