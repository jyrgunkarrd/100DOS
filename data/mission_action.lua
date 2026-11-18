local Theme = require("data.preparation_theme")

return {
    prompt = "CHOOSE AN AGENT\nTO ACT",
    promptGap = 16,
    buttonGap = 16,
    falsePath = "assets/images/ui_elements/act_btn_false.png",
    truePath = "assets/images/ui_elements/act_btn_true.png",
    width = 89,
    height = 21,
    scale = 1,
    textColor = Theme.text,
    selectionColor = { 1, 0.82, 0.35, 1 },
    clickThreshold = 4,
    transition = { duration = 0.2, outgoingDuration = 0.12, incomingDelay = 0.04, incomingDuration = 0.16 },
    portrait = { directory = "assets/images/agents", size = 176, boardGap = 32, rightMargin = 24,
        nameGap = 8, nameColor = Theme.text,
        revealDuration = 0.12, nameFadeDuration = 0.06,
        accents = { label = "AGENT SELECTED", gap = 3, bracketLength = 10,
            bracketColor = Theme.accent, bracketAlpha = 0.65, labelGap = 6, labelColor = Theme.muted } },
}
