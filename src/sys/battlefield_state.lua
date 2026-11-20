local Value = require("src.sys.army_value")
local Defeat = require("src.sys.force_defeat")
local Passives = require("src.sys.force_passives")
local Rules = require("data.battlefield_rules")
local State = {}
function State.initialize(armies, assignments, jaclCellId)
    armies.jaclCellId, armies.revision = jaclCellId, armies.revision or 0
    for cellId in pairs(assignments) do
        local pair = armies.byCell[cellId] or {}
        armies.byCell[cellId] = pair
        pair.protection, pair.revision = pair.protection or 0, pair.revision or 0
        for _, side in ipairs({ "allied", "enemy" }) do
            pair[side] = pair[side] or { id = side .. ":" .. cellId, side = side, forces = {}, value = 0, counts = { regular = 0, elite = 0 } }
        end
    end
end
function State.touch(armies, cellId)
    local pair = armies.byCell[cellId]
    for _, side in ipairs({ "allied", "enemy" }) do
        pair[side].value, pair[side].counts = Value.calculate(pair[side], armies.catalogue, armies.rules)
    end
    pair.revision = (pair.revision or 0) + 1
    armies.revision = (armies.revision or 0) + 1
end
function State.protection(armies, cellId)
    local stored = armies.byCell[cellId].protection or 0
    local bonus, sources = Passives.locationProtection(armies, cellId)
    return { stored = stored, cap = Rules.shieldCap, bonus = bonus, total = stored + bonus, sources = sources }
end
function State.prepareDamage(armies, cellId, side, damage, targetId)
    assert(type(damage) == "number" and damage >= 0 and damage < math.huge and damage % 1 == 0, "Invalid battlefield damage")
    local pair = armies.byCell[cellId]
    local bonusAbsorbed, storedAbsorbed = 0, 0
    if side == "allied" then
        local protection = State.protection(armies, cellId)
        -- The current force lineup provides fresh protection for this exchange.
        bonusAbsorbed = math.min(protection.bonus, damage)
        storedAbsorbed = math.min(protection.stored, damage - bonusAbsorbed)
    end
    local absorbed = bonusAbsorbed + storedAbsorbed
    local survivors, removed, replacements = Defeat.resolve(pair[side].forces, armies.catalogue, side, damage - absorbed, targetId)
    return { cell = cellId, side = side, survivors = survivors, removed = removed, replacements = replacements,
        absorbed = absorbed, bonusAbsorbed = bonusAbsorbed, storedAbsorbed = storedAbsorbed }
end
function State.commitDamage(armies, damage)
    local pair = armies.byCell[damage.cell]
    if damage.side == "allied" then pair.protection = pair.protection - damage.storedAbsorbed end
    pair[damage.side].forces = damage.survivors
    State.touch(armies, damage.cell)
    return damage.removed, damage.absorbed, damage.replacements, damage.bonusAbsorbed
end
function State.damage(armies, cellId, side, damage)
    return State.commitDamage(armies, State.prepareDamage(armies, cellId, side, damage))
end
function State.removeForce(armies, cellId, side, unitId)
    local forces = armies.byCell[cellId][side].forces
    for i, unit in ipairs(forces) do
        if unit.id == unitId then
            table.remove(forces, i); State.touch(armies, cellId); return unit
        end
    end
    error("Force no longer at target")
end
function State.entrench(armies, cellId)
    local pair = armies.byCell[cellId]
    pair.protection = math.min(Rules.shieldCap, pair.protection + Rules.entrenchGain)
    State.touch(armies, cellId)
end
function State.transfer(armies, from, to, unitId)
    assert(from ~= to and armies.byCell[to], "Invalid force destination")
    local source = armies.byCell[from].allied.forces
    for i, unit in ipairs(source) do
        if unit.id == unitId then
            table.remove(source, i)
            table.insert(armies.byCell[to].allied.forces, unit)
            State.touch(armies, from); State.touch(armies, to)
            return unit
        end
    end
    error("Force no longer at source")
end
return State
