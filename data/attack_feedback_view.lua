local Theme = require("data.preparation_theme")
return { stepDuration = 0.8, hitTime = 0.30, defeatHold = 0.65,
    turnEndTitle = "END OF TURN ATTACK",
    title = "OPPORTUNITY ATTACK", defeated = "DEFEATED", health = "HEALTH", defiance = "DEFIANCE",
    color = { 1, 68 / 255, 68 / 255, 1 }, healthColor = Theme.healthColor, defianceColor = Theme.defianceColor,
    backgroundColor = { 0.025, 0.035, 0.035, 1 }, textColor = Theme.text }
