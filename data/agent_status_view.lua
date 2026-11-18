local Theme = require("data.preparation_theme")
return {
    height = 20, gap = 6, resourceSize = 20,
    actionFont = "assets/fonts/Not Jam Novel 16.ttf", actionFontSize = 16,
    actionGlyph = ">", actionColor = { 1, 1, 1, 1 },
    spentActionGlyph = "-", spentActionColor = { 0.35, 0.35, 0.35, 1 }, actionSpacing = 6,
    frameColor = Theme.accent, backgroundColor = { 0.025, 0.035, 0.035, 1 },
    textColor = Theme.text,
}
