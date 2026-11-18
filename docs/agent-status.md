# Agent Action portrait status

Agent Action replaces AGENT SELECTED with a 20px status row, six pixels above
the portrait's top bracket. The row follows the portrait during its slide.
Mission Action retains the original selection label.

- Left: fixed positions in Not Jam Novel 16 at 16px. Available actions are white
  `>` glyphs; spent actions are dim gray `-` glyphs. Spending proceeds right to
  left: `>>>`, `>>-`, `>--`, `---`.
- Center: Health / Defiance in Not Jam UI 12 at 12px. Health is #4bb1ff,
  defiance is #ffae29, and the slash is #5a5a5a.
- Right: current resources in Undead Pixel 8 at 8px, inside a 20px teal box.
  The box widens for longer numbers while keeping its right edge aligned.

`data/agent_status_defaults.lua` sets starting resources (5) and action points
(3). Health and defiance come from each agent's definition. `src/sys/agent_status.lua`
creates independent mutable records under `session.agentStatus.byAgent` once on
the successful Ready transition at mission start. Re-entry reuses those records instead
of resetting them. Session transfer preserves them; ending the mission clears them.
The status tracks remaining `actionPoints` and a separate `actionPointCapacity`,
both initialized from the default of three. Successful card plays spend one
remaining action; capacity stays unchanged. Remaining actions persist through
re-entry, including zero. Done exhausts an agent and wastes remaining actions.
Next Phase restores actions and adds one resource once all agents are exhausted.
Hands and draw piles are preserved without a draw. See `docs/agent-turns.md`. Opportunity attacks can reduce Health/Defiance and defeat an Agent, automatically
ending their activation. Recovery is not implemented; see `docs/attacks.md`.

`data/agent_status_view.lua` controls row spacing, resource-box dimensions, action
glyph/font, and colors. `src/ui/agent_status.lua` draws the row and owns only its
action-point font. Heading and small fonts are borrowed from the scene.
`src/ui/health_defiance.lua` provides shared measurement and drawing for agents
and card previews. Their default stat colors live in `data/preparation_theme.lua`.

Preparation validates and builds the view before committing the transition;
failure leaves the current session and card piles untouched. Integration checks
cover defaults, independent values, invalid configuration, session transfer,
re-entry persistence, portrait-relative positioning, and resource cleanup.
