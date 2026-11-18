return {
    actionPointCost = 1,
    kinds = {
        interact = { label = "Interact", effect = "discard", provokes = true },
        strike = { label = "Strike", talent = "steel", effect = "damage", damage = 1, provokes = false },
        evade = { label = "Evade", talent = "fire", effect = "exhaust", provokes = false },
    },
    talents = { steel = true, fire = true, purpose = true, passion = true, rhyme = true, reason = true },
}
