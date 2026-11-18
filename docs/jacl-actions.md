# JACL actions

An active Agent at the JACL hex opens ACTIONS, then JACL ACTIONS. Elsewhere the
same tab offers BATTLEFIELD. Each action offers two talent tests and uses normal
card commitments, Fate, Doom, and Clash processing. AP and committed cards are
consumed on confirmation, including failed tests. Cancelling before confirmation
costs nothing. Fate Clash points belong to the acting Agent's JACL location.

| Action | AP | Tests | Successful effect | Provokes |
| --- | --- | --- | --- | --- |
| Bombard | 3 | Fire 2 / Purpose 2 | Remove one random enemy Force, then mill | No |
| Security | 1 | Steel 2 / Passion 2 | Gain 2 Security, capped at 4 | No |
| Triangulate | 2 | Reason 2 / Rhyme 2 | Scan all non-JACL location decks | Yes |

Bombard highlights every non-JACL location containing an enemy army, without a
range restriction. Select a target before choosing/confirming the test. Every
individual Force has the same casualty probability; an elite is removed outright.
There is no army retaliation. The existing casualty cut-in and milling feedback
play afterward. Milling uses the Battlefield cards-per-elimination setting and
normal hunt-card entry rules. In-play enemies and allied Forces are unaffected.

Triangulate checks each deck once. A Champion, Bodyguard, or Company remains
face-up on top, outside play. Other nonempty draw piles shuffle independently;
empty decks are skipped. JACL's deck, discards, and in-play cards are untouched.
The REVEALED TOP badge previews a scanned card on hover and never opens a test.
Drawing/milling that card clears its badge. Hunt redistribution clears top-card
knowledge; ordinary location intelligence remains separate. Scanning itself does
not engage enemies, invoke entry effects, or trigger Champion escape.

Security starts at zero each mission and persists across Agent turns and phases.
At three, Security grants the remaining one point for the full AP cost. At four,
the action is disabled. The native-size security icon and current/cap count appear
beside JACL, left of its portrait. Security currently has no mechanical effect.

## Ownership

- `data/jacl_actions.lua`: costs, test options/difficulties, Security gain/cap.
- `src/sys/jacl_actions.lua`: availability and staged action resolution, reached
  through the shared Battlefield action dispatcher.
- `src/sys/location_decks.lua`: scan transactions and revealed-top identity.
- `src/sys/battlefield_state.lua`: explicit Force removal and army revisions.
- `src/sys/mission_hunt.lua`: discovered locations and redistribution cleanup.
- `data/jacl_action_view.lua`, `src/ui/jacl_panel.lua`: Security, revealed-card
  badges/previews, and scan feedback. Mission footer owns their resources.
- Existing action/test panels and talent feedback own selection, Fate, casualty
  playback and milling. Playback never repeats gameplay effects.

Run `love . --test --jacl-only` for focused rules/UI checks, or `love . --test`
for regression coverage. The focused run writes `tests/jacl_*` screenshots and
rules/UI result files.
