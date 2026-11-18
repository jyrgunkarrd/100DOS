# Full-size artwork layers

Full-size agent portraits and agent/card/location-card previews draw a background,
the existing subject image, then a foreground. Combat cut-ins borrowing these
portraits use the same composition. UI text and accents remain above the artwork.
Mini images retain their baked-in backgrounds: roster/map minis, hand and revealed
tiles, equipment thumbnails, drag minis, and the talent-test mini portraits do not
receive layers. The deployment transition fades the layered full portrait into
the unchanged mini image.

The preparation package's biome (then the committed mission package's biome)
provides `assets/images/biomes/<biomeId>/portrait_bg.png` and `portrait_fg.png`.
Agent, card, and location-card definitions may independently override either:

```lua
card_bg = "thief_bg", -- assets/images/biomes/thief_bg.png
card_fg = "none",     -- explicitly disable the foreground
```

Omission or actual Lua `nil` inherits the biome layer. Only the exact string
`"none"` disables one. The string `"nil"` is an ordinary asset name, not a sentinel.
Override names contain letters, numbers, underscores, or hyphens, without an
extension or directory. Empty strings and other types are invalid. Overrides
apply independently and do not modify source definitions.

Author transparent PNGs on matching 176 x 176 canvases, retaining transparent
margins. Decorative layers are always centered at native size; they never enlarge,
shrink, or stretch. The composition bounds expand to contain the layers rather
than squeezing them into the subject's rectangle. Caller-owned clipping (such as
screen edges and reveal animations) still applies.
Thus 176px layers align with native-size 176px subjects in the 192px location
preview, with an 8px inset on each side. The subject retains its existing fit.
During deployment, the full portrait stays at native size as it moves and fades
into the separate miniature, keeping its decorative layers aligned.
All three layers share clipping, movement, reveals, and cut-in tint/fade effects.
Opaque subject backgrounds will naturally hide the decorative background.

Missing decorations are skipped with diagnostics. A missing explicit override
does not fall back to the biome layer. `"none"` produces no warning. Missing
subjects retain their existing placeholders. Missing biome context (standalone
previews) means no inherited decoration; explicit overrides still work.

`data/artwork_defaults.lua` declares paths and filtering.
`src/sys/artwork_resolver.lua` validates and resolves paths without graphics calls.
`src/sys/artwork_assets.lua` shares decorative images by path with counted owners;
each view releases its borrow on exit, and the last owner releases the image.
This supports existing state transfers and overlapping reroll candidates without
giving any view ownership of another view's image. Failed loads are cached until
their owners release them. Central subject images keep their existing ownership.
`src/ui/layered_artwork.lua` handles drawing and restores caller graphics state.

Run `love . --test` for resolver, cache, pixel-composition, and existing lifecycle
checks. `tests/layered_artwork.png` shows an inherited agent portrait, Catburglar's
custom layers, and Security Door with both layers disabled.
