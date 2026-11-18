local Clashes = require("src.sys.battlefield_clashes")
local Value = require("src.sys.army_value")
local Spawn = {}
function Spawn.ready(session, agentId)
    if session.pendingEndTurn or session.reinforcementFeedback then return end
    local armies = session.armies
    local cell = session.agentDeployment and session.agentDeployment.placements[agentId]
    local pair = armies and armies.byCell[cell]
    if not pair or pair.routedBy or cell == armies.jaclCellId then return end
    local cost = require("data.battlefield_rules").clashReinforcementCost
    assert(cost == 1, "Clash reinforcement must cost one point")
    if Clashes.count(pair) < cost or Value.calculate(pair.enemy, armies.catalogue, armies.rules) ~= 0 then return end
    return pair, cell
end
function Spawn.prepare(session, agentId, random)
    local pair, cell = Spawn.ready(session, agentId)
    if not pair then return end
    local armies = session.armies
    local serial = (armies.reinforcementSerial or 0) + 1
    local army = require("src.sys.army_generator").one("enemy", assert(armies.templates, "Missing mission army templates").enemy,
        armies.pools.enemy, armies.catalogue, armies.rules, "enemy:reinforcement:" .. serial, random)
    assert(army.value > 0, "Reinforcement army must have positive strength")
    return { owner = armies, revision = armies.revision, pair = pair, batch = pair.clashes[1],
        cell = cell, agentId = agentId, serial = serial, army = army, before = Clashes.count(pair) }
end
function Spawn.commit(session, plan)
    if plan.committed or session.armies ~= plan.owner or plan.owner.revision ~= plan.revision
        or session.activeAgentId ~= plan.agentId or (plan.owner.reinforcementSerial or 0) + 1 ~= plan.serial then return false end
    local pair, cell = Spawn.ready(session, plan.agentId)
    if pair ~= plan.pair or cell ~= plan.cell or pair.clashes[1] ~= plan.batch or Clashes.count(pair) ~= plan.before then return false end
    -- Selection and validation finish before publishing either the army or its cost.
    pair.enemy = plan.army
    Clashes.consume(pair, plan.batch)
    plan.owner.reinforcementSerial = plan.serial
    require("src.sys.battlefield_state").touch(plan.owner, cell)
    session.pendingEndTurn = { agentId = plan.agentId, cell = cell, reinforcementChecked = true }
    local groups, byId = {}, {}
    for _, unit in ipairs(plan.army.forces) do
        if not byId[unit.forceId] then
            byId[unit.forceId] = { forceId = unit.forceId, count = 0 }; groups[#groups + 1] = byId[unit.forceId]
        end
        byId[unit.forceId].count = byId[unit.forceId].count + 1
    end
    session.reinforcementFeedback = { cell = cell, groups = groups, before = plan.before,
        after = Clashes.count(pair), strength = plan.army.value, elapsed = 0 }
    plan.committed = true
    return true
end
return Spawn
