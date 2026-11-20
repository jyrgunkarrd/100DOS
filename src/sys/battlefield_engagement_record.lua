-- Value snapshots: feedback must not consult armies already mutated by damage.
local State = require("src.sys.battlefield_state")
local Record = {}
function Record.capture(armies, cell)
    local pair, catalogue = armies.byCell[cell], armies.catalogue
    local protection = State.protection(armies, cell)
    local snapshot = { protection = protection.total, protectionBreakdown = protection }
    for _, side in ipairs({ "enemy", "allied" }) do
        local army = pair[side]
        local copy = { value = army.value, forces = {} }
        for _, unit in ipairs(army.forces) do
            local definition = catalogue.byId[unit.forceId]
            copy.forces[#copy.forces + 1] = { id = unit.id, forceId = unit.forceId,
                name = definition.name or unit.forceId, shortName = definition.short_name, elite = definition.strength == "elite" }
        end
        snapshot[side] = copy
    end
    return snapshot
end
function Record.complete(before, after, exchanges, beforeEngage)
    local results = {}
    for _, side in ipairs({ "enemy", "allied" }) do
        local exchange, removed, byId = exchanges[side], {}, {}
        for _, unit in ipairs(before[side].forces) do byId[unit.id] = unit end
        for _, unit in ipairs(exchange.removed) do
            local source = assert(byId[unit.id], "Missing engagement casualty snapshot")
            local copy = {}; for key, value in pairs(source) do copy[key] = value end
            copy.replacementId = exchange.replacements and exchange.replacements[unit.id]
            removed[#removed + 1] = copy
        end
        local bonusAbsorbed = exchange.bonusAbsorbed or 0
        results[side] = { damage = exchange.damage, absorbed = exchange.absorbed, removed = removed,
            bonusAbsorbed = bonusAbsorbed, storedAbsorbed = exchange.absorbed - bonusAbsorbed,
            defeated = #before[side].forces > 0 and #after[side].forces == 0 }
    end
    return { armiesBefore = before, armiesAfter = after, sides = results, beforeEngage = beforeEngage,
        summary = "ENEMY: " .. #results.enemy.removed .. " LOST / ALLIED: " .. #results.allied.removed .. " LOST" }
end
return Record
