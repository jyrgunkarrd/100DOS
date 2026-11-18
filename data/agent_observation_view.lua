local Theme = require("data.preparation_theme")
return {
    titleY = 400, hintGap = 26, buttonGap = 24, buttonWidth = 240, buttonHeight = 28,
    heading = "INSPECTING", hint = "READ ONLY / RIGHT-CLICK OR ESC TO CLOSE",
    details = "DECK / DISCARD / FATE", emptyHand = "HAND EMPTY",
    ready = "READY", exhausted = "EXHAUSTED", defeated = "DEFEATED", active = "ACTIVE",
    accent = Theme.accent, text = Theme.text, muted = Theme.muted,
    background = { 0.025, 0.043, 0.047, 1 },
}
