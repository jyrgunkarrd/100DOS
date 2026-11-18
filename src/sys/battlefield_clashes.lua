local Tests = require("src.sys.battlefield_tests")
local Clashes = {}

function Clashes.count(pair)
    if pair.routedBy then return 0 end
    local count = 0
    for _, batch in ipairs(pair.clashes or {}) do count = count + batch.remaining end
    return count
end

function Clashes.ready(session, agentId)
    local armies = session.armies
    local cell = session.agentDeployment and session.agentDeployment.placements[agentId]
    local pair = armies and armies.byCell[cell]
    local batch = pair and pair.clashes and pair.clashes[1]
    if (pair and pair.routedBy) or not batch or cell == armies.jaclCellId or #pair.allied.forces == 0 or #pair.enemy.forces == 0 then return end
    local location = session.locations and session.assignments and session.locations.byId[session.assignments[cell]]
    if location and #Tests.resolve(location, "engage") > 0 then return batch, cell end
end

function Clashes.prepareBatch(tileId, clash)
    return { tileId = tileId, remaining = clash.amt, damage = clash.en_dmg or 0, difficulty = clash.en_bonus or 0 }
end

function Clashes.enqueue(pair, batch)
    if pair.routedBy then return false end
    pair.clashes = pair.clashes or {}
    table.insert(pair.clashes, batch)
end

-- A replacement head gives each point its own identity, including within a batch.
function Clashes.consume(pair, batch)
    assert(pair.clashes[1] == batch, "Clash changed")
    if batch.remaining == 1 then
        table.remove(pair.clashes, 1)
    else
        pair.clashes[1] = { tileId = batch.tileId, remaining = batch.remaining - 1,
            damage = batch.damage, difficulty = batch.difficulty }
    end
end

return Clashes
