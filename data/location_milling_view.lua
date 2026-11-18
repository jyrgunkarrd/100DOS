return {
    sound = "assets/audio/sfx/mill.wav",
    directory = "assets/images/loc_cards", artSize = 192,
    width = 900, height = 370, travel = 270,
    cardDuration = 0.72, enterFraction = 0.22, exitFraction = 0.67,
    stagger = 0.14, maxCascade = 0.48, hold = 0.26, emptyDuration = 0.65,
    receiptRow = 30,
    background = { 0.025, 0.045, 0.045, 1 }, accent = { 0.2, 0.85, 0.9, 1 },
    text = { 0.95, 0.96, 1, 1 },
    labels = { title = "ENCOUNTER MILLING", deck = "DECK", discard = "DISCARD", milled = "MILLED",
        eliminated = "ENEMIES ELIMINATED", empty = "DECK EMPTY", unavailable = "ART UNAVAILABLE",
        receipt = "LAST MILL", revealed = "REVEALED", review = "Hover names to inspect / scroll for more" },
}
