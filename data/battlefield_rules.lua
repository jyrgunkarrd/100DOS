return {
    clashReinforcementCost = 1,
    actionPointCost = 1, shieldCap = 4, entrenchGain = 2,
    cardsMilledPerEnemyEliminated = 1,
    controlledLocationStartMill = 1,
    engagement = { strengthPerDamage = 2, rounding = "down", alliedRequiresSuccess = true },
    actions = {
        engage = { label = "ENGAGE", adjustment = 0 },
        entrench = { label = "ENTRENCH", adjustment = -2 },
        maneuver = { label = "MANEUVER", adjustment = 0 },
    },
}
