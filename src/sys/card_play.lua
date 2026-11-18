local Rules = require("data.card_play_rules")
local Play = {}
local function integer(n, minimum)
    return type(n) == "number" and n >= minimum and n < math.huge and n % 1 == 0
end
function Play.evaluate(session, agentId, instanceId, start)
    local cards = session.agentCards
    local state = cards and cards.byAgent[agentId]
    local status = session.agentStatus and session.agentStatus.byAgent[agentId]
    local assets = session.agentAssets
    local result = { valid = false }
    if not state or not status or not assets or not assets.byAgent[agentId] then
        result.reason = "AGENT UNAVAILABLE"; return result
    end
    for index, card in ipairs(state.hand) do
        if card.instanceId == instanceId then result.card, result.handIndex = card, index; break end
    end
    if not result.card then result.reason = "CARD NOT IN HAND"; return result end
    local d = cards.definitions.byId[result.card.cardId]
    if not d or not integer(d.cost, 0) then result.reason = "INVALID CARD COST"; return result end
    result.cost, result.projected = d.cost, status.resources - d.cost
    if d.card_type ~= "ASSET" then result.reason = "CARD TYPE NOT PLAYABLE YET"; return result end
    if not integer(d.asset_slots, 1) or not integer(d.health or 0, 0) or not integer(d.defiance or 0, 0) then
        result.reason = "INVALID ASSET DEFINITION"; return result
    end
    result.size = d.asset_slots
    if require("src.sys.agent_status").isDefeatedState(status) then result.reason = "AGENT DEFEATED"; return result end
    if session.attackFeedback or session.talentFeedback then result.reason = "ACTION RESOLVING"; return result end
    if status.exhausted then result.reason = "AGENT EXHAUSTED"; return result end
    if not integer(Rules.actionPointCost, 1) then result.reason = "INVALID ACTION COST"; return result end
    if not integer(status.actionPoints, 0) or not integer(status.actionPointCapacity, 0)
        or status.actionPoints > status.actionPointCapacity then
        result.reason = "INVALID ACTION POOL"; return result
    end
    result.actionCost = Rules.actionPointCost
    result.projectedActions = status.actionPoints - result.actionCost
    if result.projectedActions < 0 then
        result.reason = status.actionPoints == 0 and "NO ACTION POINTS" or "NOT ENOUGH ACTION POINTS"
        return result
    end
    if result.projected < 0 then result.reason = "NOT ENOUGH RESOURCES"; return result end
    if not assets:findSpace(agentId, result.size) then
        result.reason = "NEEDS " .. result.size .. " ADJACENT SLOTS"; return result
    end
    if start ~= nil and not assets:fits(agentId, start, result.size) then
        result.reason = "SLOTS BLOCKED"; return result
    end
    result.valid = true
    return result
end

function Play.prepare(session, agentId, args)
    local instanceId, start = args.instanceId, args.start
    local result = Play.evaluate(session, agentId, instanceId, start)
    if not result.valid then return nil, result.reason end
    local assets = session.agentAssets
    if not assets:fits(agentId, start, result.size) then return nil, "DROP ON ASSET SLOTS" end
    local board = assets.byAgent[agentId]
    local definition = session.agentCards.definitions.byId[result.card.cardId]
    -- Prepare the entire new board and hand before publishing any changes.
    local placement = { instanceId = instanceId, cardId = result.card.cardId, card = result.card,
        start = start, size = result.size, health = definition.health or 0, defiance = definition.defiance or 0 }
    local nextBoard = { placements = {}, occupied = {} }
    for i, existing in ipairs(board.placements) do nextBoard.placements[i] = existing end
    for key, existing in pairs(board.occupied) do nextBoard.occupied[key] = existing end
    nextBoard.placements[#nextBoard.placements + 1] = placement
    for i = start, start + result.size - 1 do nextBoard.occupied[assets.slots[i]] = placement end
    local nextHand = {}
    for i, card in ipairs(session.agentCards.byAgent[agentId].hand) do
        if i ~= result.handIndex then nextHand[#nextHand + 1] = card end
    end
    local originalHand = session.agentCards.byAgent[agentId].hand
    return { result = placement, status = { resources = result.projected, actionPoints = result.projectedActions },
        publish = function()
            if session.agentCards.byAgent[agentId].hand ~= originalHand or assets.byAgent[agentId] ~= board then return false end
            session.agentCards.byAgent[agentId].hand = nextHand
            assets.byAgent[agentId] = nextBoard
            return true
        end }
end
function Play.commit(session, agentId, instanceId, start)
    return require("src.sys.agent_action_resolution").execute(session, agentId, "play_card", { instanceId = instanceId, start = start })
end
return Play
