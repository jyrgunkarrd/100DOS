local Value = require("src.sys.army_value")
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
function State.damage(armies, cellId, side, damage)
    assert(type(damage) == "number" and damage >= 0 and damage < math.huge and damage % 1 == 0, "Invalid battlefield damage")
    local pair, removed = armies.byCell[cellId], {}
    local absorbed = side == "allied" and math.min(pair.protection, damage) or 0
    if side == "allied" then pair.protection = pair.protection - absorbed end
    local remaining = damage - absorbed
    for _, strength in ipairs({ "regular", "elite" }) do
        local survivors = {}
        for _, unit in ipairs(pair[side].forces) do
            if remaining > 0 and armies.catalogue.byId[unit.forceId].strength == strength then
                removed[#removed + 1], remaining = unit, remaining - 1
            else survivors[#survivors + 1] = unit end
        end
        pair[side].forces = survivors
    end
    State.touch(armies, cellId)
    return removed, absorbed
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
    local rules, pair = require("data.battlefield_rules"), armies.byCell[cellId]
    pair.protection = math.min(rules.shieldCap, pair.protection + rules.entrenchGain)
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
