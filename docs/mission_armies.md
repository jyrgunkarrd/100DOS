# Mission armies

Deployment builds one allied and one enemy army for each occupied non-JACL cell.
The configured JACL cell in `data/jacl_location_rules.lua` receives empty containers instead of generated armies. Armies and
their label view transfer with the mission session and are not rerolled on state changes.

Biome and captain `allied_forces` / `enemy_forces` arrays contribute force IDs.
Contributions are combined and deduplicated, then grouped by each force's
`strength`. Force `faction` must match the receiving pool. Missing contribution
arrays are allowed; missing IDs, invalid strengths, or empty required groups fail
deployment with a diagnostic.

`data/army_lists/allied_army.lua` and `enemy_army.lua` define named templates with
`{ str = "regular" | "elite", qty = positive_integer }` slots. Template IDs are
unique within each side's selection. Templates with identical compositions are
still separate choices. Force types are sampled uniformly with replacement.

`data/army_deployment_rules.lua` controls strength values (regular 1, elite 2)
and selection weights. Allied IDs beginning with `sup_` have weight 0.75;
other allied templates and all enemy templates have weight 1. Templates are
selected without replacement and shuffled independently before cell assignment.

`mission_armies.build` returns `byCell[cellId].allied` and `.enemy`, plus pools,
the force catalogue, and rules. Each army contains an instance ID, template ID,
side, individual force instances, counts, and total value. Definition tables are
not modified. An optional random generator supports repeatable generation.

`data/army_deployment_view.lua` controls font, colors, prefixes, and spacing.
Labels show `E <strength>` on the left and `A <strength>` on the right in Undead Pixel 8, below each hex
when space permits, otherwise above. Layout checks hex bounds, prior labels,
and panel edges and rejects layouts without room. Labels appear after the
deployment animation and remain visible in mission and agent action. They have
no action handlers. Labels refresh after battlefield revisions; JACL labels are
always omitted, including when forces move there. Hover inspection is handled
separately by `battlefield_inspection.lua`.

See `docs/battlefield.md` for inspection and Agent battlefield actions.

Run `love . --test` for generation, bias, composition, session transfer, and
label-layout checks. The suite writes `tests/army_deployment.png` for visual
inspection in addition to the existing integration artifacts.
