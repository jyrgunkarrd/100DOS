local Theme = require("data.preparation_theme")
return {
    width = 646, height = 508, padding = 18, listWidth = 336, rowHeight = 32, gap = 14,
    tabs = {
        { id = "deck", label = "DECK" },
        { id = "discard", label = "DISCARD" },
        { id = "fate", label = "FATE" },
    },
    empty = { deck = "NO CARDS IN DECK", discard = "DISCARD PILE EMPTY", fate = "NO FATE CONTRIBUTIONS" },
    hint = "RIGHT-CLICK FOR DETAILS.",
    liveHint = "RIGHT-CLICK TO INSPECT AGENT AND LOCATION.",
    rulesHint = "WHEEL TO SCROLL CARD",
    background = { 0.025, 0.043, 0.047, 1 },
    shade = { 0, 0, 0, 0.68 },
    row = { 0.053, 0.082, 0.087, 1 },
    highlight = { 0.085, 0.21, 0.21, 1 },
    accent = Theme.accent, text = Theme.text,
    muted = { 0.63, 0.73, 0.72, 1 },
}
