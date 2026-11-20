local Explore = {}
function Explore.validate(rules)
    local cost = rules and rules.actionPointCost
    assert(type(cost) == "number" and cost >= 0 and cost < math.huge and cost % 1 == 0,
        "Invalid exploration actionPointCost")
    return cost
end

function Explore.evaluate(session, agentId, rules)
    if require("src.sys.mission_outcome").finished(session) then return { valid = false, reason = "Mission complete" } end
    local cost = Explore.validate(rules)
    local status = session.agentStatus and session.agentStatus.byAgent[agentId]
    if session.attackFeedback or session.talentFeedback then return { valid = false, reason = "Action resolving" } end
    if require("src.sys.agent_status").isDefeatedState(status) then return { valid = false, reason = "Agent defeated" } end
    if session.activeAgentId ~= agentId or not status or status.exhausted then
        return { valid = false, reason = "Agent is not active" }
    end
    local cell = session.agentDeployment.placements[agentId]
    local deck = session.locationDecks and session.locationDecks.byCell[cell]
    if not deck then return { valid = false, reason = "No location deck" } end
    if #deck.drawPile == 0 then return { valid = false, reason = "Location deck empty" } end
    local definitions = session.locationDecks.pool and session.locationDecks.pool.byId or {}
    for _, card in pairs(deck.inPlay or {}) do
        local definition = definitions[card.cardId]
        if definition and definition.blocks_explore then
            return { valid = false, reason = "Blocked by " .. definition.name }
        end
    end
    if status.actionPoints < cost then return { valid = false, reason = "No actions remaining" } end
    return { valid = true, cell = cell, cost = cost, status = status }
end

function Explore.prepare(session, agentId, args)
    local rules = args.rules
    local result = Explore.evaluate(session, agentId, rules)
    if not result.valid then return nil, result.reason end
    local staged = session.locationDecks:prepareDraw(result.cell)
    require("src.sys.location_card_entry").prepare(session, result.cell, staged, agentId)
    local remaining = result.status.actionPoints - result.cost
    return { result = staged.card, status = { actionPoints = remaining },
        publish = function()
            if not session.locationDecks:commitDraw(result.cell, staged) then return false end
            require("src.sys.location_card_entry").committed(session, result.cell, staged.card)
            return true
        end }
end
function Explore.commit(session, agentId, rules)
    return require("src.sys.agent_action_resolution").execute(session, agentId, "explore", { rules = rules })
end
return Explore
