local Status = require("src.sys.agent_status")
local Engagement = require("src.sys.location_engagement")
local Topology = require("src.sys.board_topology")
local Basic = {}
local supported = { move = true, draw_card = true, gain_resource = true }
function Basic.definitions()
    local definitions = require("data.agent_basic_actions")
    local seen = {}
    for _, d in ipairs(definitions) do
        assert(supported[d.id] and not seen[d.id], "Unknown or duplicate basic action")
        seen[d.id] = true
        assert(type(d.label) == "string" and d.label:match("%S"), "Missing basic action label")
        assert(type(d.actionPointCost) == "number" and d.actionPointCost > 0
            and d.actionPointCost < math.huge and d.actionPointCost % 1 == 0, "Invalid basic action cost")
        if d.id == "move" then assert(d.target == "adjacent_location", "Invalid movement target")
        else assert(type(d.amount) == "number" and d.amount > 0 and d.amount < math.huge
            and d.amount % 1 == 0, "Invalid basic action amount") end
    end
    for id in pairs(supported) do assert(seen[id], "Missing basic action: " .. id) end
    return definitions
end
function Basic.evaluate(session, id, kind, args)
    local definition
    for _, d in ipairs(Basic.definitions()) do if d.id == kind then definition = d end end
    assert(definition, "Unknown basic action")
    local status = session.agentStatus and session.agentStatus.byAgent[id]
    local function invalid(reason) return { valid = false, reason = reason } end
    if require("src.sys.mission_outcome").finished(session) then return invalid("Mission complete") end
    if session.attackFeedback or session.talentFeedback then return invalid("Action resolving") end
    if not status or session.activeAgentId ~= id or Status.isExhausted(session.agentStatus, id) then
        return invalid("Agent unavailable")
    end
    if status.actionPoints < definition.actionPointCost then return invalid("No action points remaining") end
    local targets
    if kind == "move" then
        if #Engagement.ordered(session, id) > 0 then return invalid("Engaged with an enemy") end
        targets = Topology.locations(session, session.agentDeployment.placements[id])
        if #targets == 0 then return invalid("No adjacent locations") end
        if args and args.cellId then
            local found = false
            for _, target in ipairs(targets) do if target == args.cellId then found = true end end
            if not found then return invalid("Choose an adjacent location") end
        end
    elseif kind == "draw_card" then
        if #session.agentCards.byAgent[id].drawPile == 0 then return invalid("Deck empty") end
    end
    return { valid = true, definition = definition, targets = targets, status = status }
end
local function copy(list)
    local result = {}; for i, v in ipairs(list) do result[i] = v end; return result
end
local function same(a, b)
    if #a ~= #b then return false end
    for i, v in ipairs(a) do if b[i] ~= v then return false end end
    return true
end
function Basic.prepare(session, id, args, kind)
    args = args or {}
    local result = Basic.evaluate(session, id, kind, args)
    if not result.valid then return nil, result.reason end
    local d, cell = result.definition, args.cellId
    if kind == "move" and not cell then return nil, "Choose an adjacent location" end
    local stagedStatus = { actionPoints = result.status.actionPoints - d.actionPointCost }
    local staged, previous, snapshots
    if kind == "draw_card" then
        previous = session.agentCards.byAgent[id]
        snapshots = { hand = copy(previous.hand), drawPile = copy(previous.drawPile), discardPile = copy(previous.discardPile or {}) }
        staged = session.agentCards:prepareDraw(id, d.amount)
    elseif kind == "gain_resource" then
        local resources = result.status.resources
        assert(type(resources) == "number" and resources >= 0 and resources < math.huge
            and resources % 1 == 0, "Invalid resource pool")
        stagedStatus.resources = resources + d.amount
        assert(stagedStatus.resources < math.huge and stagedStatus.resources > resources, "Resource pool overflow")
    end
    return { status = stagedStatus, result = { kind = kind, cellId = cell }, publish = function()
        if not Basic.evaluate(session, id, kind, { cellId = cell }).valid then return false end
        if kind == "draw_card" then
            if session.agentCards.byAgent[id] ~= previous then return false end
            for key, snapshot in pairs(snapshots) do
                if not same(previous[key] or {}, snapshot) then return false end
            end
            session.agentCards:commitHand(id, staged)
        elseif kind == "move" then
            if not session.agentDeployment:assign(id, cell) then return false end
        end
        return true
    end }
end
return Basic
