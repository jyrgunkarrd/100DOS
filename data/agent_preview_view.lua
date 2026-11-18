local c = {}
for key, value in pairs(require("data.card_preview_view")) do c[key] = value end
c.artDirectory = "assets/images/agents"
c.centerArtwork = false
c.width, c.artSize, c.iconSize, c.gap = 280, 176, 32, 6
c.rulesFont = require("data.preparation_theme").headingFont
c.rulesFontSize = 12
c.testHeading = "TALENTS"
c.testColumns, c.testColumnGap, c.testValueFont = 2, 16, "small"
c.talentOrder = { "steel", "fire", "reason", "rhyme", "purpose", "passion" }
c.talentLabels = { steel = "STEEL", fire = "FIRE", reason = "REASON", rhyme = "RHYME", purpose = "PURPOSE", passion = "PASSION" }
c.engagedColor = { 1, 68 / 255, 68 / 255, 1 }
c.edgeMargin, c.portraitGap = 16, 12
c.inspectionSoundResetDelay = 0.3 -- Silence Agent switches and brief gaps within one inspection session.
c.assetSlots = { size = 32, gap = 4, portraitGap = 12, label = "ASSETS", labelGap = 4,
    directory = "assets/images/cards", suffix = "_mini.png",
    frameColor = c.frameColor, backgroundColor = c.backgroundColor, textColor = c.textColor }
c.labels = { startingResources = "STARTING RESOURCES", resources = "RESOURCES",
    defeated = "DEFEATED", exhausted = "EXHAUSTED", ready = "READY", engaged = "ENGAGED ENEMIES" }
return c
