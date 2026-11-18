return {
    gatherDuration = 0.16, shuffleDuration = 0.20, dealDuration = 0.23,
    stagger = 0.025, pulseDuration = 0.16,
    reducedMotion = false,
    cardWidth = 30, cardHeight = 42,
    markerTextOffsetY = 2, legendPaddingY = 8,
    background = { 0.025, 0.045, 0.055, 1 }, accent = { 0.95, 0.68, 0.26, 1 },
    failure = { 1, 0.28, 0.22, 1 },
    secured = { 0.25, 0.9, 0.64, 1 }, text = { 0.96, 0.96, 0.9, 1 },
    -- Use the mission's cached cue; no additional audio assets are required.
    soundId = "roll",
    labels = { initial = "CHAMPION AND ENTOURAGE", escape = "CHAMPION FLEEING",
        hidden = "SEARCH THE LOCATION DECKS", secured = "SECURED", located = "LOCATED",
        failure = "MISSION FAILED", jaclExhausted = "JACL DECK EXHAUSTED",
        victory = "MISSION COMPLETE", defeated = "CHAMPION ELIMINATED",
        continue = "ENTER / NEW MISSION", skip = "SPACE / SKIP" },
}
