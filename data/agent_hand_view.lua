local Theme = require("data.preparation_theme")
return {
    width = 182, height = 32, gap = 4, minimumStep = 10,
    top = 24, bottomGap = 8, portraitGap = 8,
    revealDuration = 0.1, revealStagger = 0.025, revealMaximum = 0.2, revealOffset = 6,
    directory = "assets/images/cards", suffix = "_mini.png",
    frameColor = Theme.accent, textColor = Theme.text,
    hoverColor = { 1, 0.82, 0.35, 1 }, backgroundColor = { 0.025, 0.045, 0.045, 1 },
}
