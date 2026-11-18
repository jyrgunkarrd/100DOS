local Theme = require("data.preparation_theme")

return {
    label = "ASSET SLOTS",
    labelGap = 4,
    revealDuration = 0.08,
    revealStagger = 0.02,
    size = 50,
    borderWidth = 1,
    padding = 4, -- Clear space inside the border, before the color block.
    gap = 4,
    rightMargin = 24,
    parallaxGap = 6, -- Leave room above the row for two-line agent names.
    frameColor = Theme.accent,
    backgroundColor = { 0, 0, 0, 1 },
}
