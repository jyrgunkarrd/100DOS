local settings = {}
for key, value in pairs(require("data.card_preview_view")) do settings[key] = value end
settings.engagementLabel = "ENGAGED WITH "
settings.engagementColor = { 1, 0.35, 0.3, 1 }
settings.artDirectory = "assets/images/loc_cards"
settings.centerArtwork = true
settings.artSize = 192 -- Full-resolution encounter images; 176px images remain native-sized.
settings.width = 256
settings.testHeading = "TALENT TESTS"
settings.testValueFont = "small"
settings.talentLabels = { steel = "STEEL", fire = "FIRE", reason = "REASON",
    rhyme = "RHYME", purpose = "PURPOSE", passion = "PASSION" }
settings.statLabels = { health = "HEALTH", defiance = "DEFIANCE", damage = "DAMAGE", trauma = "TRAUMA" }
settings.damageColor = settings.healthColor
settings.traumaColor = settings.defianceColor
settings.statGroupGap = 8
settings.statPair = { left = "damage", right = "trauma" }
return settings
