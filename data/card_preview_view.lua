local Theme = require("data.preparation_theme")
return {
    rulesFont = "assets/fonts/Not Jam Novel 16.ttf", rulesFontSize = 16,
    footerSlotSize = 12, footerSlotGap = 4,
    healthColor = Theme.healthColor,
    defianceColor = Theme.defianceColor,
    width = 240, top = 24, bottomMargin = 24, padding = 12, gap = 8,
    artSize = 176, iconSize = 32, iconGap = 4, costPipWidth = 5, costPipGap = 3, scrollStep = 24,
    artDirectory = "assets/images/cards", methodDirectory = "assets/images/method",
    talentDirectory = "assets/images/talents",
    backgroundColor = { 0.025, 0.035, 0.035, 1 }, frameColor = Theme.accent,
    textColor = Theme.text, mutedColor = Theme.accent,
}
