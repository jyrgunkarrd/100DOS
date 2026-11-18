local Theme = require("data.preparation_theme")
return {
    left = 24, top = 24, width = 356, mapGap = 24, bottomGap = 16,
    height = 32, gap = 4, columnGap = 12, minimumNameHeight = 22, listHeaderGap = 40, revealDuration = 0.25,
    directory = "assets/images/loc_cards", suffix = "_mini.png", showCost = false,
    frameColor = Theme.accent, textColor = Theme.text, mutedColor = Theme.muted,
    hoverColor = { 1, 0.82, 0.35, 1 }, backgroundColor = { 0.025, 0.045, 0.045, 1 },
    engagementHeight = 14, engagementColor = { 1, 0.35, 0.3, 1 },
    engagementLabel = "ENGAGED: ", engagementCountLabel = "ENGAGED WITH YOU: ",
    typeOrder = { "SYSTEM", "ENEMY", "BARRIER" },
    typeLabels = { SYSTEM = "Systems", ENEMY = "Enemies", BARRIER = "Barriers" },
    typeColors = { SYSTEM = { 0.25, 0.9, 0.64, 1 }, ENEMY = { 0.95, 0.52, 0.35, 1 }, BARRIER = { 0.48, 0.72, 0.95, 1 } },
    labels = { location = "CURRENT LOCATION", remaining = "DECK REMAINING", revealed = "LOCATION CARDS",
        concealed = " / ? HIDDEN",
        explore = "EXPLORE", action = "ACTION", actions = "ACTIONS", empty = "Explore to reveal a location card.",
        emptyInspection = "NO LOCATION CARDS IN PLAY",
        scroll = "SCROLL TO VIEW", revealing = "Revealing location card..." },
}
